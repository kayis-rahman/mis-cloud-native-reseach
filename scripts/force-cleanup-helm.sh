#!/bin/bash

# Force Cleanup Helm Operations Script
# This script forcefully cancels stuck Helm operations and cleans up observability stack

set -e

echo "🛑 Force Cleanup Helm Operations - Local Terminal"
echo "=================================================="

# Function to check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        echo "❌ kubectl not found. Please install kubectl first."
        exit 1
    fi

    if ! kubectl cluster-info &> /dev/null; then
        echo "❌ No active Kubernetes cluster found. Please connect to your cluster first."
        exit 1
    fi

    echo "✅ Connected to Kubernetes cluster"
}

# Function to check if helm is available
check_helm() {
    if ! command -v helm &> /dev/null; then
        echo "❌ Helm not found. Please install Helm first."
        exit 1
    fi
    echo "✅ Helm found"
}

# Function to force cleanup stuck Helm operations
force_cleanup_helm() {
    echo ""
    echo "🔍 Checking for stuck Helm operations..."

    # List all Helm releases across all namespaces
    echo "📋 Current Helm releases:"
    helm list --all-namespaces -a || true

    echo ""
    echo "🧹 Force cleaning up observability-stack releases..."

    # Find all namespaces with observability-stack
    NAMESPACES_WITH_OBS=$(helm list --all-namespaces -a | grep observability-stack | awk '{print $2}' || true)

    if [ -z "$NAMESPACES_WITH_OBS" ]; then
        echo "ℹ️  No observability-stack releases found"
    else
        echo "Found observability-stack in namespaces: $NAMESPACES_WITH_OBS"

        for ns in $NAMESPACES_WITH_OBS; do
            echo "🗑️  Removing observability-stack from namespace: $ns"
            helm uninstall observability-stack -n "$ns" --wait --timeout=30s || true
        done
    fi

    # Additional cleanup - remove any remaining observability-stack releases
    echo ""
    echo "🔍 Scanning all namespaces for any remaining observability-stack instances..."
    for ns in $(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}'); do
        if helm list -n "$ns" 2>/dev/null | grep -q "observability-stack"; then
            echo "🗑️  Found and removing observability-stack from namespace: $ns"
            helm uninstall observability-stack -n "$ns" --wait --timeout=30s || true
        fi
    done
}

# Function to remove Helm lock secrets
remove_helm_locks() {
    echo ""
    echo "🔧 Removing Helm lock secrets that cause 'operation in progress' errors..."

    # Remove Helm secrets that might be causing locks
    kubectl delete secret -l owner=helm,name=observability-stack --all-namespaces || true
    kubectl delete secret -l app.kubernetes.io/managed-by=Helm,app.kubernetes.io/instance=observability-stack --all-namespaces || true

    # Remove any ConfigMaps related to Helm releases
    kubectl delete configmap -l owner=helm,name=observability-stack --all-namespaces || true

    echo "✅ Helm lock secrets removed"
}

# Function to clean up observability namespaces and resources
cleanup_observability_resources() {
    echo ""
    echo "🧽 Cleaning up observability resources..."

    # List of potential observability namespaces
    OBS_NAMESPACES=("observability" "observability-dev" "observability-prod" "observability-development" "observability-production")

    for ns in "${OBS_NAMESPACES[@]}"; do
        if kubectl get namespace "$ns" &> /dev/null; then
            echo "🗑️  Cleaning up namespace: $ns"

            # Force delete all resources in the namespace
            kubectl delete all --all -n "$ns" --timeout=30s || true
            kubectl delete pvc --all -n "$ns" --timeout=30s || true
            kubectl delete configmap --all -n "$ns" --timeout=30s || true
            kubectl delete secret --all -n "$ns" --timeout=30s || true

            # Optionally delete the namespace itself (uncomment if needed)
            # kubectl delete namespace "$ns" --timeout=60s || true

            echo "✅ Cleaned up namespace: $ns"
        fi
    done
}

# Function to verify cleanup
verify_cleanup() {
    echo ""
    echo "🔍 Verifying cleanup completion..."

    # Check for any remaining observability-stack releases
    REMAINING_RELEASES=$(helm list --all-namespaces -a | grep observability-stack || true)

    if [ -z "$REMAINING_RELEASES" ]; then
        echo "✅ No observability-stack releases found - cleanup successful"
    else
        echo "⚠️  Some releases still exist:"
        echo "$REMAINING_RELEASES"
    fi

    # Check for stuck Helm operations
    echo ""
    echo "📋 Current Helm releases after cleanup:"
    helm list --all-namespaces -a || true
}

# Function to show next steps
show_next_steps() {
    echo ""
    echo "🎯 Next Steps:"
    echo "=============="
    echo "1. Wait 30-60 seconds for Kubernetes to complete cleanup"
    echo "2. Try deploying observability stack again:"
    echo "   ./scripts/deploy_observability.sh"
    echo "   OR"
    echo "   ./scripts/deploy-observability-helm.sh"
    echo "3. If you want to deploy via GitHub Actions, trigger the workflow manually"
    echo ""
    echo "💡 If you still get 'operation in progress' errors, run this script again"
}

# Main execution
main() {
    echo "Starting force cleanup process..."

    # Check prerequisites
    check_kubectl
    check_helm

    # Perform cleanup
    force_cleanup_helm
    remove_helm_locks
    cleanup_observability_resources

    # Wait for cleanup to complete
    echo ""
    echo "⏳ Waiting 15 seconds for cleanup to complete..."
    sleep 15

    # Verify results
    verify_cleanup

    # Show next steps
    show_next_steps

    echo ""
    echo "🎉 Force cleanup completed!"
}

# Run main function
main "$@"
