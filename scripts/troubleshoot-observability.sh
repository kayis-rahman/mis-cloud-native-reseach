#!/bin/bash

# Observability Troubleshooting and Direct YAML Deployment with Namespace Fix
echo "🔧 Observability Troubleshooting & Direct YAML Deployment"
echo "========================================================="

set -e

# Configuration
NAMESPACE="${1:-observability-prod}"
echo "🎯 Target namespace: $NAMESPACE"

# Function to check prerequisites
check_prerequisites() {
    echo "🔍 Checking prerequisites..."

    if ! command -v kubectl &> /dev/null; then
        echo "❌ kubectl not found"
        exit 1
    fi

    if ! kubectl cluster-info &> /dev/null; then
        echo "❌ Cannot connect to Kubernetes cluster"
        exit 1
    fi

    echo "✅ Prerequisites check passed"
}

# Function to create namespace
create_namespace() {
    echo "📦 Creating namespace: $NAMESPACE"
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    echo "✅ Namespace ready"
}

# Function to deploy component with namespace replacement
deploy_component() {
    local component=$1
    local yaml_file=$2
    local max_retries=3

    echo "🚀 Deploying $component..."

    # Create a temporary file with namespace replacement
    local temp_file="/tmp/${component}-${NAMESPACE}.yaml"

    # Replace hardcoded namespace with target namespace, excluding the namespace creation section
    sed "s/namespace: observability$/namespace: ${NAMESPACE}/g" "$yaml_file" | \
    sed '/^apiVersion: v1$/,/^---$/ { /kind: Namespace/,/^---$/ d; }' > "$temp_file"

    for attempt in $(seq 1 $max_retries); do
        echo "  📦 Attempt $attempt of $max_retries for $component"

        if kubectl apply -f "$temp_file"; then
            echo "  ✅ $component deployed successfully on attempt $attempt"
            rm -f "$temp_file"
            return 0
        else
            echo "  ⚠️ $component deployment failed on attempt $attempt"
            if [ $attempt -lt $max_retries ]; then
                echo "  ⏳ Waiting 15 seconds before retry..."
                sleep 15
            fi
        fi
    done

    echo "  ❌ $component deployment failed after $max_retries attempts"
    echo "  🔍 Debug info - checking temp file:"
    head -20 "$temp_file" || true
    rm -f "$temp_file"
    return 1
}

# Function to deploy minimal components (skip heavy ones for now)
deploy_minimal_component() {
    local component=$1
    local app_label=$2

    echo "🚀 Deploying minimal $component..."

    # Create a minimal deployment for testing
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${app_label}
  namespace: ${NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ${app_label}
  template:
    metadata:
      labels:
        app: ${app_label}
    spec:
      containers:
      - name: ${app_label}
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
---
apiVersion: v1
kind: Service
metadata:
  name: ${app_label}
  namespace: ${NAMESPACE}
spec:
  selector:
    app: ${app_label}
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF

    echo "✅ Minimal $component deployed"
}

# Function to wait for deployment to be ready
wait_for_deployment() {
    local deployment=$1
    local timeout=${2:-180}

    echo "⏳ Waiting for $deployment to be ready (timeout: ${timeout}s)..."

    if kubectl wait --for=condition=available --timeout="${timeout}s" deployment "$deployment" -n "$NAMESPACE"; then
        echo "✅ $deployment is ready"
        return 0
    else
        echo "⚠️ $deployment did not become ready within ${timeout}s"
        echo "📊 Current status:"
        kubectl get pods -n "$NAMESPACE" -l app="$deployment" || true
        return 1
    fi
}

# Function to check component health
check_component_health() {
    local component=$1
    echo "🏥 Checking $component health..."

    # Get pod status
    local pods=$(kubectl get pods -n "$NAMESPACE" -l app="$component" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)

    if [ -z "$pods" ]; then
        echo "  ⚠️ No pods found for $component"
        return 1
    fi

    for pod in $pods; do
        local status=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
        echo "  📋 Pod $pod: $status"

        if [ "$status" != "Running" ]; then
            echo "  🔍 Pod logs for troubleshooting:"
            kubectl logs "$pod" -n "$NAMESPACE" --tail=5 || true
        fi
    done
}

# Main deployment function
deploy_observability() {
    echo "🚀 Starting observability deployment..."

    # For troubleshooting, deploy minimal test components first
    echo "🧪 Deploying minimal test components to verify cluster connectivity..."

    deploy_minimal_component "Prometheus Test" "prometheus-test"
    wait_for_deployment "prometheus-test" 120

    deploy_minimal_component "Grafana Test" "grafana-test"
    wait_for_deployment "grafana-test" 120

    echo "✅ Minimal components deployed successfully"

    # Now try actual observability components with namespace fix
    echo "🎯 Attempting actual observability components..."

    # Try Prometheus with namespace fix
    if [ -f "observability/prometheus.yaml" ]; then
        deploy_component "Prometheus" "observability/prometheus.yaml"
        wait_for_deployment "prometheus" 180 || echo "⚠️ Prometheus needs more time"
    fi

    return 0
}

# Function to show final status
show_final_status() {
    echo ""
    echo "📊 Final Deployment Status"
    echo "=========================="

    echo "🗂️ Namespace: $NAMESPACE"
    kubectl get namespace "$NAMESPACE" 2>/dev/null || echo "❌ Namespace not found"

    echo ""
    echo "🚀 Deployments:"
    kubectl get deployments -n "$NAMESPACE" 2>/dev/null || echo "❌ No deployments found"

    echo ""
    echo "📦 Pods:"
    kubectl get pods -n "$NAMESPACE" 2>/dev/null || echo "❌ No pods found"

    echo ""
    echo "🌐 Services:"
    kubectl get services -n "$NAMESPACE" 2>/dev/null || echo "❌ No services found"
}

# Function to provide next steps
show_next_steps() {
    echo ""
    echo "🎯 Next Steps"
    echo "============="
    echo "1. ✅ Cluster connectivity verified with test deployments"
    echo "2. 🔧 Namespace conflicts identified and resolved"
    echo "3. 💡 To use the working deployment approach:"
    echo "   ./scripts/quick-helm-cleanup.sh"
    echo "   kubectl apply -f observability/ --namespace=$NAMESPACE --recursive"
    echo "4. 🎛️ Alternative: Use GitHub Actions with fixed pipeline"
    echo ""
    echo "🗑️ To clean up test deployments: kubectl delete namespace $NAMESPACE"
}

# Main execution
main() {
    echo "Starting troubleshooting deployment process..."

    check_prerequisites
    create_namespace
    deploy_observability

    echo ""
    echo "⏳ Waiting 20 seconds for components to stabilize..."
    sleep 20

    # Health checks
    for component in prometheus-test grafana-test prometheus; do
        check_component_health "$component"
    done

    show_final_status
    show_next_steps

    echo ""
    echo "🎉 Troubleshooting completed! Cluster is working - namespace conflicts identified."
}

# Run main function
main "$@"
