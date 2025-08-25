#!/bin/bash

# Quick Helm Cleanup - Enhanced for rate limiting issues
echo "🛑 Quick Helm Cleanup - Canceling stuck operations and handling rate limits..."

# Check cluster connectivity first
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Cannot connect to Kubernetes cluster"
    exit 1
fi

echo "✅ Connected to cluster"

# Force remove observability-stack from all namespaces with retries
echo "🔍 Checking for observability-stack releases..."
for ns in $(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "default"); do
    # Check if observability-stack exists in this namespace
    if helm list -n "$ns" 2>/dev/null | grep -q "observability-stack"; then
        echo "🗑️ Removing observability-stack from namespace: $ns"

        # Try multiple times with increasing delays to handle rate limits
        for attempt in 1 2 3; do
            if helm uninstall observability-stack -n "$ns" --wait --timeout=60s 2>/dev/null; then
                echo "✅ Successfully removed from $ns on attempt $attempt"
                break
            else
                echo "⚠️ Attempt $attempt failed for $ns, waiting before retry..."
                sleep $((attempt * 10))
            fi
        done
    fi
done

# Remove Helm lock secrets with retries
echo "🔧 Removing Helm lock secrets..."
for attempt in 1 2 3; do
    if kubectl delete secret -l owner=helm,name=observability-stack --all-namespaces --timeout=30s 2>/dev/null; then
        echo "✅ Helm owner secrets removed on attempt $attempt"
        break
    else
        echo "⚠️ Attempt $attempt failed for owner secrets, waiting..."
        sleep $((attempt * 5))
    fi
done

for attempt in 1 2 3; do
    if kubectl delete secret -l app.kubernetes.io/managed-by=Helm,app.kubernetes.io/instance=observability-stack --all-namespaces --timeout=30s 2>/dev/null; then
        echo "✅ Helm managed-by secrets removed on attempt $attempt"
        break
    else
        echo "⚠️ Attempt $attempt failed for managed-by secrets, waiting..."
        sleep $((attempt * 5))
    fi
done

# Additional cleanup for rate limiting issues
echo "🧹 Additional cleanup for rate limiting issues..."

# Remove any stuck pods in observability namespaces
OBS_NAMESPACES=("observability" "observability-dev" "observability-prod" "observability-development" "observability-production")
for ns in "${OBS_NAMESPACES[@]}"; do
    if kubectl get namespace "$ns" &>/dev/null; then
        echo "🔄 Cleaning stuck resources in $ns..."

        # Force delete stuck pods
        kubectl delete pods --all -n "$ns" --force --grace-period=0 --timeout=30s 2>/dev/null || true

        # Remove finalizers from stuck resources
        kubectl patch pods -n "$ns" --all -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true

        # Wait between operations to avoid rate limiting
        sleep 2
    fi
done

# Clean up any webhook configurations that might cause rate limiting
echo "🕸️ Checking for problematic webhook configurations..."
kubectl delete validatingwebhookconfiguration observability-stack-webhook 2>/dev/null || true
kubectl delete mutatingwebhookconfiguration observability-stack-webhook 2>/dev/null || true

# Final verification with retry
echo "🔍 Verifying cleanup..."
sleep 5

REMAINING=$(helm list --all-namespaces -a 2>/dev/null | grep observability-stack || true)
if [ -z "$REMAINING" ]; then
    echo "✅ Complete cleanup successful - no observability-stack releases remain"
else
    echo "⚠️ Some releases may still exist:"
    echo "$REMAINING"
    echo "💡 You may need to run this script again or use the comprehensive cleanup"
fi

echo "✅ Enhanced cleanup completed! Wait 60 seconds before retrying deployment to avoid rate limits."
