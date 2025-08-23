# MIS Cloud Native - Helm Chart

This Helm chart deploys all microservices in the repository using a single release. Each microservice is configured in `values.yaml` under the `services:` map.

Included Kubernetes resources per service:
- Deployment (with non-root security context)
- Service (ClusterIP by default)
- Optional Ingress (controlled globally)

## Usage

Install with default values:

```
helm install mis ./helm/mis-cloud-native
```

Customize images, ports, replicas, or ingress via a custom values file:

```
helm install mis ./helm/mis-cloud-native -f my-values.yaml
```

Upgrade:

```
helm upgrade mis ./helm/mis-cloud-native -f my-values.yaml
```

Uninstall:

```
helm uninstall mis
```

## Values structure

- `global.imageRegistry`: Optional registry prefix applied to all images.
- `global.imagePullPolicy`: Image pull policy for all containers.
- `global.ingress`: Enable and configure Ingress for all services.
- `services.<name>`: Per-service configuration
  - `enabled`: Enable/disable this service
  - `name`: Container name (defaults to key)
  - `image`: Container image (e.g., sparkage/product-service:latest)
  - `replicaCount`: Number of replicas
  - `containerPort`: Container port exposed by the app
  - `service.type`: ClusterIP/NodePort/LoadBalancer
  - `service.port`: Service port
  - `env`: List of env variables `{ name: KEY, value: VAL }`
  - `resources`: Container resource limits/requests
  - `livenessProbe.path` and `readinessProbe.path`: Override default actuator health endpoints if needed

By default, services are configured to use Spring Boot actuator health endpoints at `/actuator/health/liveness` and `/actuator/health/readiness`.
