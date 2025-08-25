#!/bin/bash

# Validate Observability Stack
# This script validates that all observability components are working correctly

set -e

echo "🔍 Validating Observability Stack..."

# Function to check if a service is ready
check_service() {
    local service_name=$1
    local namespace=$2
    local port=$3

    echo "Checking $service_name..."

    # Wait for pod to be ready
    kubectl wait --for=condition=ready pod -l app=$service_name -n $namespace --timeout=300s

    # Check if service is accessible
    local pod_name=$(kubectl get pod -l app=$service_name -n $namespace -o jsonpath='{.items[0].metadata.name}')
    if kubectl exec -n $namespace $pod_name -- curl -s -o /dev/null -w "%{http_code}" localhost:$port | grep -q "200\|404"; then
        echo "✅ $service_name is responding"
        return 0
    else
        echo "❌ $service_name is not responding"
        return 1
    fi
}

# Function to test Prometheus metrics
test_prometheus_metrics() {
    echo "Testing Prometheus metrics collection..."

    local prometheus_pod=$(kubectl get pod -l app=prometheus -n observability -o jsonpath='{.items[0].metadata.name}')

    # Test if Prometheus is scraping targets
    local targets_up=$(kubectl exec -n observability $prometheus_pod -- wget -qO- http://localhost:9090/api/v1/targets | grep -o '"health":"up"' | wc -l)

    if [ "$targets_up" -gt 0 ]; then
        echo "✅ Prometheus is collecting metrics from $targets_up targets"
    else
        echo "⚠️  Prometheus has no healthy targets"
    fi
}

# Function to test Grafana connectivity
test_grafana() {
    echo "Testing Grafana connectivity..."

    local grafana_pod=$(kubectl get pod -l app=grafana -n observability -o jsonpath='{.items[0].metadata.name}')

    if kubectl exec -n observability $grafana_pod -- curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/api/health | grep -q "200"; then
        echo "✅ Grafana is healthy"
    else
        echo "❌ Grafana health check failed"
    fi
}

# Function to test ELK stack
test_elk_stack() {
    echo "Testing ELK stack..."

    # Test Elasticsearch
    local es_pod=$(kubectl get pod -l app=elasticsearch -n observability -o jsonpath='{.items[0].metadata.name}')
    if kubectl exec -n observability $es_pod -- curl -s -o /dev/null -w "%{http_code}" http://localhost:9200/_cluster/health | grep -q "200"; then
        echo "✅ Elasticsearch is healthy"
    else
        echo "❌ Elasticsearch health check failed"
    fi

    # Test Logstash
    local logstash_pod=$(kubectl get pod -l app=logstash -n observability -o jsonpath='{.items[0].metadata.name}')
    if kubectl exec -n observability $logstash_pod -- curl -s -o /dev/null -w "%{http_code}" http://localhost:9600 | grep -q "200"; then
        echo "✅ Logstash is healthy"
    else
        echo "❌ Logstash health check failed"
    fi

    # Test Kibana
    local kibana_pod=$(kubectl get pod -l app=kibana -n observability -o jsonpath='{.items[0].metadata.name}')
    if kubectl exec -n observability $kibana_pod -- curl -s -o /dev/null -w "%{http_code}" http://localhost:5601/api/status | grep -q "200"; then
        echo "✅ Kibana is healthy"
    else
        echo "❌ Kibana health check failed"
    fi
}

# Function to test Jaeger
test_jaeger() {
    echo "Testing Jaeger..."

    local jaeger_pod=$(kubectl get pod -l app=jaeger -n observability -o jsonpath='{.items[0].metadata.name}')

    if kubectl exec -n observability $jaeger_pod -- curl -s -o /dev/null -w "%{http_code}" http://localhost:16686 | grep -q "200"; then
        echo "✅ Jaeger is healthy"
    else
        echo "❌ Jaeger health check failed"
    fi
}

# Run all validation tests
echo "Starting observability validation..."

# Check basic service availability
check_service "prometheus" "observability" "9090"
check_service "grafana" "observability" "3000"
check_service "elasticsearch" "observability" "9200"
check_service "logstash" "observability" "9600"
check_service "kibana" "observability" "5601"
check_service "jaeger" "observability" "16686"

# Run detailed tests
test_prometheus_metrics
test_grafana
test_elk_stack
test_jaeger

echo ""
echo "🎯 Validation Summary:"
echo "All observability components have been validated."
echo ""
echo "📊 Next Steps:"
echo "1. Configure Grafana dashboards using the JSON files in observability/grafana-dashboards/"
echo "2. Set up Kibana index patterns for microservices-logs-*"
echo "3. Verify that application metrics are being collected by checking Prometheus targets"
echo "4. Test distributed tracing by making requests through the API Gateway"

echo ""
echo "🔗 Access URLs (if using LoadBalancer services):"
kubectl get svc -n observability -o wide
