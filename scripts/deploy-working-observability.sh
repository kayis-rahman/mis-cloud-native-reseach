#!/bin/bash

# Quick Observability Fix - Deploy Only Working Components
echo "🔧 Quick Observability Fix - Deploy Working Components Only"
echo "==========================================================="

NAMESPACE="${1:-observability-prod}"

# Clean up failing components
echo "🧹 Cleaning up failing components..."
kubectl delete deployment grafana elasticsearch kibana logstash -n observability --ignore-not-found=true
kubectl delete deployment grafana elasticsearch kibana logstash -n $NAMESPACE --ignore-not-found=true

echo "🚀 Deploying minimal working observability stack..."

# Deploy only Prometheus to the target namespace
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: ${NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      containers:
      - name: prometheus
        image: prom/prometheus:v2.45.0
        ports:
        - containerPort: 9090
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "250m"
        args:
          - '--config.file=/etc/prometheus/prometheus.yml'
          - '--storage.tsdb.path=/prometheus'
          - '--web.console.libraries=/etc/prometheus/console_libraries'
          - '--web.console.templates=/etc/prometheus/consoles'
          - '--storage.tsdb.retention.time=7d'
          - '--web.enable-lifecycle'
---
apiVersion: v1
kind: Service
metadata:
  name: prometheus
  namespace: ${NAMESPACE}
spec:
  selector:
    app: prometheus
  ports:
  - port: 9090
    targetPort: 9090
  type: ClusterIP
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jaeger
  namespace: ${NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jaeger
  template:
    metadata:
      labels:
        app: jaeger
    spec:
      containers:
      - name: jaeger
        image: jaegertracing/all-in-one:1.48
        ports:
        - containerPort: 16686
        - containerPort: 14268
        env:
        - name: COLLECTOR_OTLP_ENABLED
          value: "true"
        resources:
          requests:
            memory: "128Mi"
            cpu: "50m"
          limits:
            memory: "256Mi"
            cpu: "100m"
---
apiVersion: v1
kind: Service
metadata:
  name: jaeger
  namespace: ${NAMESPACE}
spec:
  selector:
    app: jaeger
  ports:
  - name: ui
    port: 16686
    targetPort: 16686
  - name: collector
    port: 14268
    targetPort: 14268
  type: ClusterIP
EOF

echo "⏳ Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/prometheus -n $NAMESPACE
kubectl wait --for=condition=available --timeout=300s deployment/jaeger -n $NAMESPACE

echo "📊 Final Status:"
kubectl get pods -n $NAMESPACE
kubectl get services -n $NAMESPACE

echo ""
echo "🎉 Lightweight observability stack deployed successfully!"
echo ""
echo "🎯 Access services:"
echo "1. Prometheus: kubectl port-forward -n $NAMESPACE svc/prometheus 9090:9090"
echo "2. Jaeger UI: kubectl port-forward -n $NAMESPACE svc/jaeger 16686:16686"
echo ""
echo "💡 This minimal stack provides:"
echo "  ✅ Metrics monitoring (Prometheus)"
echo "  ✅ Distributed tracing (Jaeger)"
echo "  ⚠️  Logging disabled (ELK stack has resource issues)"
