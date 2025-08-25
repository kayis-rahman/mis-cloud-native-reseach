#!/bin/bash

# Deploy Observability Stack
# This script deploys Prometheus, Grafana, ELK Stack, and Jaeger

set -e

echo "🚀 Deploying Observability Stack..."

# Create observability namespace
echo "Creating observability namespace..."
kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -

# Deploy Prometheus
echo "Deploying Prometheus..."
kubectl apply -f observability/prometheus.yaml

# Deploy Grafana
echo "Deploying Grafana..."
kubectl apply -f observability/grafana.yaml

# Deploy ELK Stack
echo "Deploying ELK Stack (Elasticsearch, Logstash, Kibana)..."
kubectl apply -f observability/elk-stack.yaml

# Deploy Jaeger
echo "Deploying Jaeger..."
kubectl apply -f observability/jaeger.yaml

# Wait for deployments to be ready with increased timeout and better error handling
echo "Waiting for deployments to be ready..."

# Function to wait for deployment with custom timeout
wait_for_deployment() {
    local deployment=$1
    local timeout=${2:-600}

    echo "Waiting for $deployment to be ready (timeout: ${timeout}s)..."
    if kubectl wait --for=condition=available --timeout=${timeout}s deployment/$deployment -n observability; then
        echo "✅ $deployment is ready"
    else
        echo "⚠️  $deployment failed to become ready within ${timeout}s"
        echo "Pod status for $deployment:"
        kubectl get pods -n observability -l app=${deployment} -o wide
        echo "Recent events:"
        kubectl get events -n observability --field-selector involvedObject.name=$deployment --sort-by='.lastTimestamp' | tail -5
        return 1
    fi
}

# Wait for each deployment individually with appropriate timeouts
wait_for_deployment "prometheus" 300
wait_for_deployment "grafana" 300
wait_for_deployment "elasticsearch" 600  # Elasticsearch needs more time
wait_for_deployment "logstash" 600      # Logstash depends on Elasticsearch
wait_for_deployment "kibana" 600        # Kibana depends on Elasticsearch
wait_for_deployment "jaeger-all-in-one" 300

echo "✅ Observability stack deployed successfully!"

# Display access information
echo ""
echo "📊 Access Information:"
echo "Grafana UI: http://$(kubectl get svc grafana-service -n observability -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo '<pending>'):3000"
echo "  Username: admin"
echo "  Password: admin123"
echo ""
echo "Kibana UI: http://$(kubectl get svc kibana-service -n observability -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo '<pending>'):5601"
echo ""
echo "Jaeger UI: http://$(kubectl get svc jaeger-query -n observability -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo '<pending>'):16686"
echo ""
echo "Prometheus UI: http://$(kubectl get svc prometheus-service -n observability -o jsonpath='{.spec.clusterIP}'):9090 (cluster internal)"

echo ""
echo "🔧 To configure Grafana dashboards:"
echo "1. Import the dashboard JSON files from observability/grafana-dashboards/"
echo "2. Dashboards will auto-configure with Prometheus data source"

echo ""
echo "🔍 To check pod status: kubectl get pods -n observability"
echo "🔍 To check logs: kubectl logs <pod-name> -n observability"
