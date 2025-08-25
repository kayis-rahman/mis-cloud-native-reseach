# Grafana Cloud Observability Integration (Free Tier)

This repository includes minimal, production-friendly guidance to integrate your microservices with Grafana Cloud for metrics, traces, and logs with low overhead and no in-cluster heavy dependencies.

What you get:
- Metrics: Prometheus-compatible metrics via Micrometer (/actuator/prometheus) scraped by Grafana Agent or remote write.
- Traces: OpenTelemetry (OTLP/HTTP) exported to Grafana Tempo (through the Grafana Cloud OTLP gateway).
- Logs: JSON logs shipped from Kubernetes with Promtail to Grafana Loki.
- Secure config via Kubernetes Secrets. No secrets are hardcoded.

Important: This guide shows how to enable instrumentation without changing application code. All settings are injected via environment variables and Helm values.

## 1) Prerequisites (Grafana Cloud)
- Create a free Grafana Cloud stack.
- Note your:
  - Stack ID (org id), e.g., 123456
  - Cloud region, e.g., us, eu, ap
  - API Key with Metrics, Logs, and Traces permissions

## 2) Metrics (Spring Boot / Micrometer)
Ensure services expose Prometheus metrics at /actuator/prometheus.
If using Spring Boot with Micrometer (common), inject via env vars (no code changes):

Add these to your Helm values under each service `.Values.services.<service>.env`:

- name: MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE
  value: "health,info,prometheus"
- name: MANAGEMENT_ENDPOINT_PROMETHEUS_ENABLED
  value: "true"
- name: MANAGEMENT_METRICS_EXPORT_PROMETHEUS_ENABLED
  value: "true"

Example (values-development.yaml):

services:
  api-gateway:
    env:
      - name: MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE
        value: "health,info,prometheus"
      - name: MANAGEMENT_ENDPOINT_PROMETHEUS_ENABLED
        value: "true"
      - name: MANAGEMENT_METRICS_EXPORT_PROMETHEUS_ENABLED
        value: "true"

You can enable Prometheus scrape annotations by setting per-service annotations in values:

services:
  api-gateway:
    annotations:
      prometheus.io/scrape: "true"
      prometheus.io/path: "/actuator/prometheus"
      prometheus.io/port: "8080"

This allows Grafana Agent (Prometheus) to discover and scrape your services easily.

## 3) Distributed Tracing (OpenTelemetry to Grafana Tempo)
Configure services to export traces to the Grafana Cloud OTLP gateway. Inject via env only:

Create a Secret with your stack id and API key:

kubectl create secret generic grafana-cloud-credentials \
  -n <your-namespace> \
  --from-literal=api_key=REDACTED \
  --from-literal=stack_id=YOUR_STACK_ID

Add env vars to each service:

- name: GRAFANA_CLOUD_STACK_ID
  valueFrom:
    secretKeyRef:
      name: grafana-cloud-credentials
      key: stack_id
- name: GRAFANA_CLOUD_API_KEY
  valueFrom:
    secretKeyRef:
      name: grafana-cloud-credentials
      key: api_key
- name: OTEL_SERVICE_NAME
  value: "api-gateway"          # use the service name
- name: OTEL_RESOURCE_ATTRIBUTES
  value: "service.name=api-gateway,service.namespace=$(POD_NAMESPACE),deployment.environment=development"
- name: OTEL_TRACES_EXPORTER
  value: "otlp"
- name: OTEL_EXPORTER_OTLP_PROTOCOL
  value: "http/protobuf"
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: "https://otlp-gateway-us.grafana.net"  # change us -> your region
- name: OTEL_EXPORTER_OTLP_HEADERS
  value: "Authorization=Bearer $(GRAFANA_CLOUD_API_KEY),X-Scope-OrgID=$(GRAFANA_CLOUD_STACK_ID)"
- name: OTEL_PROPAGATORS
  value: "tracecontext,baggage"

Also add this downward API env to populate namespace dynamically:

- name: POD_NAMESPACE
  valueFrom:
    fieldRef:
      fieldPath: metadata.namespace

Tip: For Java, you can also consider OpenTelemetry Java agent for automatic instrumentation. Add this to container args or env:
- name: JAVA_TOOL_OPTIONS
  value: "-javaagent:/otel/opentelemetry-javaagent.jar"
Mount the agent via an initContainer or bake into the image (optional).

## 4) Logs (Promtail -> Grafana Loki)
Deploy a lightweight Promtail DaemonSet to tail Kubernetes container logs and push to your Grafana Cloud Loki endpoint.

Create a values file (promtail-values.yaml) and apply the manifest below (update region):

apiVersion: v1
kind: Secret
metadata:
  name: grafana-cloud-credentials
  namespace: default
stringData:
  api_key: REDACTED
  stack_id: YOUR_STACK_ID
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: promtail-config
  namespace: default
data:
  promtail.yml: |
    server:
      http_listen_port: 3101
    clients:
      - url: https://logs-prod-us.grafana.net/loki/api/v1/push
        headers:
          X-Scope-OrgID: ${STACK_ID}
          Authorization: Bearer ${API_KEY}
    positions:
      filename: /run/promtail/positions.yaml
    scrape_configs:
      - job_name: containers
        pipeline_stages:
          - docker: {}
        static_configs:
          - targets:
              - localhost
            labels:
              job: kubernetes-pods
              __path__: /var/log/containers/*.log
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: promtail
  namespace: default
spec:
  selector:
    matchLabels:
      name: promtail
  template:
    metadata:
      labels:
        name: promtail
    spec:
      serviceAccountName: default
      containers:
      - name: promtail
        image: grafana/promtail:2.9.0
        args: ["-config.file=/etc/promtail/promtail.yml"]
        env:
        - name: API_KEY
          valueFrom:
            secretKeyRef:
              name: grafana-cloud-credentials
              key: api_key
        - name: STACK_ID
          valueFrom:
            secretKeyRef:
              name: grafana-cloud-credentials
              key: stack_id
        volumeMounts:
        - name: config
          mountPath: /etc/promtail
        - name: varlog
          mountPath: /var/log
        - name: varlibdocker
          mountPath: /var/lib/docker/containers
          readOnly: true
      volumes:
      - name: config
        configMap:
          name: promtail-config
      - name: varlog
        hostPath:
          path: /var/log
      - name: varlibdocker
        hostPath:
          path: /var/lib/docker/containers

Apply it:

kubectl apply -f promtail-values.yaml

## 5) Helm integration knobs (values.yaml)
We added a grafanaCloud block in helm/mis-cloud-native/values.yaml to centralize config. It is OFF by default and non-invasive.
Use it as a guidance source; for direct env injection, add per-service env under services.<svc>.env as shown above.

## 6) Validation
- Metrics: In Grafana, add Prometheus data source if using Agent remote_write; or use Explore -> Metrics to query e.g., jvm_memory_used_bytes.
- Traces: In Grafana, go to Tempo -> Services and verify spans after generating traffic.
- Logs: In Explore -> Loki, search `{job="kubernetes-pods"}` and filter by namespace/labels.

Quick in-cluster checks:
- kubectl exec <pod> -- curl -s localhost:8080/actuator/prometheus | head
- kubectl logs ds/promtail | tail -n 50

## 7) Security & Secrets
- Never commit API keys. Always use Kubernetes Secrets and envFrom/valueFrom.
- Restrict RBAC for agents appropriately.

## 8) Troubleshooting
- No traces? Confirm OTEL envs, headers include both Authorization and X-Scope-OrgID.
- No metrics scraped? Confirm annotations present on pods or that Grafana Agent is scraping the namespace.
- Logs missing? Check Promtail has access to /var/log/containers and that your Cloud Loki URL/headers are correct.

## 9) Sample alerts & dashboards
- Import Grafana’s community dashboards for JVM/Micrometer and Kubernetes.
- Add simple alert: High 5xx rate.

Sample PromQL (5xx rate):

sum(rate(http_server_requests_seconds_count{outcome="SERVER_ERROR"}[5m]))
/
sum(rate(http_server_requests_seconds_count[5m])) > 0.1

This documentation provides code snippets and manifests you can apply directly with minimal changes to existing services.
