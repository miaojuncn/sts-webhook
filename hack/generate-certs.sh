#!/usr/bin/env bash

set -e

usage() {
    cat <<EOF
Generate certificate suitable for use with an webhook service.
The server key/cert are stored in a k8s secret.

usage: ${0} [OPTIONS]

The following flags are required.

       --service          Service name of webhook.
       --namespace        Namespace where webhook service and secret reside.
       --secret           Secret name for server key/cert pair.
EOF
    exit 1
}

while [[ $# -gt 0 ]]; do
    case ${1} in
        --service)
            service="$2"
            shift
            ;;
        --secret)
            secret="$2"
            shift
            ;;
        --namespace)
            namespace="$2"
            shift
            ;;
        *)
            usage
            ;;
    esac
    shift
done

[ -z "${service}" ] && echo "ERROR: --service flag is required" && exit 1
[ -z "${secret}" ] && echo "ERROR: --secret flag is required" && exit 1
[ -z "${namespace}" ] && namespace=default

if [ ! -x "$(command -v openssl)" ]; then
    echo "openssl not found"
    exit 1
fi

[ -d certs ] || mkdir certs
tmpDir=$(mktemp -d)

echo "create CA certificate"
openssl genrsa -out certs/ca.key 2048
openssl req -new -key certs/ca.key -out "${tmpDir}"/ca.csr -subj "/C=CN/CN=Admission Controller Webhook CA"
openssl x509 -req -days 3650 -in "${tmpDir}"/ca.csr -signkey certs/ca.key -out certs/ca.crt

echo "create server csr conf"
cat <<EOF >> "${tmpDir}"/csr.conf
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name

[req_distinguished_name]
C = CN
CN = ${service}.${namespace}.svc

[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${service}
DNS.2 = ${service}.${namespace}
DNS.3 = ${service}.${namespace}.svc
IP.1 = 192.168.1.10  # change it to your IP address
EOF

echo "create server key/cert"
openssl genrsa -out certs/tls.key 2048
openssl req -new -key certs/tls.key -subj "/CN=${service}.${namespace}.svc" -out "${tmpDir}"/tls.csr -config "${tmpDir}"/csr.conf
openssl x509 -req -days 3650 -in "${tmpDir}"/tls.csr -CA certs/ca.crt -CAkey certs/ca.key -CAcreateserial -out certs/tls.crt -extfile "${tmpDir}"/csr.conf -extensions v3_req

echo "create server TLS secret from keys"
kubectl create secret tls "${secret}" \
        --key="certs/tls.key" \
        --cert="certs/tls.crt" \
        --dry-run=client -o yaml |
    kubectl -n ${namespace} apply -f -
