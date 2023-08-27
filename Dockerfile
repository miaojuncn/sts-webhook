FROM registry.devops.rivtower.com/library/golang:1.20 as builder
ARG TARGETOS
ARG TARGETARCH
WORKDIR /workspace
COPY go.mod go.mod
COPY go.sum go.sum
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=${TARGETOS:-linux} GOARCH=${TARGETARCH} go build -a -o webhook main.go

FROM registry.devops.rivtower.com/google_containers/distroless/static:nonroot
WORKDIR /
COPY --from=builder /workspace/webhook .
USER 65532:65532
ENTRYPOINT ["/webhook"]
