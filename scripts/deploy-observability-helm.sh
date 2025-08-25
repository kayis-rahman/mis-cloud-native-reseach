#!/bin/bash

# Deploy Observability Stack Script
# This script deploys the complete observability stack using Helm

set -e

# Configuration
NAMESPACE="observability"
RELEASE_NAME="observability-stack"
CHART_PATH="./helm/observability-stack"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
print_status "Checking prerequisites..."

if ! command_exists helm; then
    print_error "Helm is not installed. Please install Helm first."
    exit 1
fi

if ! command_exists kubectl; then
    print_error "kubectl is not installed. Please install kubectl first."
    exit 1
fi

# Check if kubectl can connect to cluster
if ! kubectl cluster-info >/dev/null 2>&1; then
    print_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
    exit 1
fi

print_success "Prerequisites check passed"

# Clean up any existing release or namespace to avoid conflicts
print_status "Cleaning up any existing deployment..."
helm uninstall $RELEASE_NAME -n $NAMESPACE --ignore-not-found 2>/dev/null || true
kubectl delete namespace $NAMESPACE --ignore-not-found=true

# Deploy the observability stack - let Helm create the namespace
print_status "Deploying observability stack..."
helm install $RELEASE_NAME $CHART_PATH \
    --namespace $NAMESPACE \
    --create-namespace \
    --wait \
    --timeout 10m \
    --values $CHART_PATH/values.yaml

print_success "Observability stack deployed successfully!"

# Wait for all pods to be ready
print_status "Waiting for all pods to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=$RELEASE_NAME -n $NAMESPACE --timeout=300s

# Get service information
print_status "Getting service information..."
echo
echo "=== Observability Services ==="
kubectl get services -n $NAMESPACE

echo
echo "=== Pods Status ==="
kubectl get pods -n $NAMESPACE

# Display access information
echo
echo "=== Access Information ==="
print_success "Observability stack is ready!"
echo
echo "To access the services, you can use port-forwarding:"
echo
echo "Grafana Dashboard:"
echo "  kubectl port-forward -n $NAMESPACE svc/grafana-service 3000:3000"
echo "  Then open: http://localhost:3000 (admin/admin123)"
echo
echo "Prometheus:"
echo "  kubectl port-forward -n $NAMESPACE svc/prometheus-service 9090:9090"
echo "  Then open: http://localhost:9090"
echo
echo "Kibana:"
echo "  kubectl port-forward -n $NAMESPACE svc/kibana-service 5601:5601"
echo "  Then open: http://localhost:5601"
echo
echo "Jaeger UI:"
echo "  kubectl port-forward -n $NAMESPACE svc/jaeger-query-service 16686:16686"
echo "  Then open: http://localhost:16686"
echo

# Create observability config for microservices
print_status "Creating observability configuration for microservices..."
kubectl create configmap observability-endpoints \
    --from-literal=logstash.host="logstash-service.$NAMESPACE.svc.cluster.local" \
    --from-literal=logstash.port="5000" \
    --from-literal=jaeger.agent.host="jaeger-agent-service.$NAMESPACE.svc.cluster.local" \
    --from-literal=jaeger.agent.port="6831" \
    --from-literal=prometheus.host="prometheus-service.$NAMESPACE.svc.cluster.local" \
    --from-literal=prometheus.port="9090" \
    --namespace default \
    --dry-run=client -o yaml | kubectl apply -f -

print_success "Observability configuration created for microservices in default namespace"

echo
print_success "Deployment completed successfully!"
print_warning "Remember to update your microservices to use the observability endpoints."
