IMAGE 		:= registry.devops.rivtower.com/library/sts-webhook:latest
CERT_SECRET	:= webhook-tls
NAMESPACE	:= default
LOCAL_IP	:= "192.168.31.183"

##@ General

.PHONY: help
help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Development

.PHONY: fmt
fmt: ## Run go fmt against code.
	go fmt ./...

.PHONY: vet
vet: ## Run go vet against code.
	go vet ./...

##@ Build

.PHONY: build
build: fmt vet ## Build binary.
	env CGO_ENABLED=0 go build -a -o webhook main.go

.PHONY: run
run: fmt vet cert ## Run a webhook from your host.
	go run ./main.go --cert-dir certs

.PHONY: docker-build
docker-build: ## Build docker image.
	docker build -t $(IMAGE) .

.PHONY: docker-push
docker-push: ## Push docker image.
	docker push $(IMAGE)

##@ Deployment

.PHONY: deploy-inner
deploy-inner: cert ## Deploy webhook.
	@echo "deploy mutating webhook configuration"
	@caBundle=$(shell openssl base64 -A < certs/ca.crt); \
	sed -e "s@{{caBundle}}@$${caBundle}@g; s@{{namespace}}@$(NAMESPACE)@g" < manifests/config-inner.yaml \
		| kubectl apply -f -
	@echo "deploy mutating webhook service"
	@sed -e "s@{{image}}@$(IMAGE)@g; s@{{namespace}}@$(NAMESPACE)@g" < manifests/sts-webhook.yaml \
     	| kubectl apply -f -

.PHONY: undeploy-inner
undeploy-inner: ## Undeploy webhook.
	@echo "undeploy service and related config"
	@sed -e "s@{{namespace}}@$(NAMESPACE)@g; s@{{image}}@$(IMAGE)@g" < manifests/sts-webhook.yaml \
 		| kubectl delete -f -
	kubectl delete -f manifests/config-inner.yaml
	kubectl delete secret $(CERT_SECRET) -n $(NAMESPACE)

.PHONY: deploy-outer
deploy-outer: cert ## Deploy webhook.
	@echo "deploy mutating webhook configuration"
	@caBundle=$(shell openssl base64 -A < certs/ca.crt); \
	sed -e "s@{{caBundle}}@$${caBundle}@g; s@{{namespace}}@$(NAMESPACE)@g; s@{{url}}@https://$(LOCAL_IP):9443/mutate@g" < manifests/config-outer.yaml \
		| kubectl apply -f -
	@echo "deploy mutating webhook service"
	@sed -e "s@{{image}}@$(IMAGE)@g; s@{{namespace}}@$(NAMESPACE)@g" < manifests/sts-webhook.yaml \
     	| kubectl apply -f -

.PHONY: undeploy-outer
undeploy-outer: ## Undeploy webhook.
	@echo "undeploy service and related config"
	@sed -e "s@{{namespace}}@$(NAMESPACE)@g; s@{{image}}@$(IMAGE)@g" < manifests/sts-webhook.yaml \
 		| kubectl delete -f -
	kubectl delete -f manifests/config-outer.yaml
	kubectl delete secret $(CERT_SECRET) -n $(NAMESPACE)

##@ Dependency

.PHONY: cert
cert: ## Generate certificates for webhook.
	@sed -e "s@192.168.1.10@$(LOCAL_IP)@g" ./hack/generate-certs.sh \
		| bash -s -- --service sts-webhook --namespace $(NAMESPACE) --secret $(CERT_SECRET)

.PHONY: save-cert
save-cert: ## Download certificates from k8s secrets.
	kubectl get secret $(CERT_SECRET) -o jsonpath={.data.'tls\.crt'} | base64 -d > certs/server.crt
	kubectl get secret $(CERT_SECRET) -o jsonpath={.data.'tls\.key'} | base64 -d > certs/server.key

