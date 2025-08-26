# AI Architecture Diagram Generator — Prompt Template

Copy and paste the prompt below into your AI of choice (e.g., ChatGPT, Claude, Gemini). The AI should generate a complete system architecture diagram for this repository. Prefer Mermaid output first (for GitHub rendering), and optionally provide a high-resolution image.

---

You are an expert cloud-native solution architect. Generate an accurate, production-ready architecture diagram for the following microservices application. Output MUST include:
- Mermaid diagram (graph TB). Keep node labels concise and legible.
- A short textual legend explaining key components and ports.
- If you can, also provide an optional exportable PNG/SVG or a PlantUML alternative.

Hard requirements and ground truth from the codebase and deployment:
1) Platform & Networking
- Kubernetes: Google Kubernetes Engine (GKE)
- Ingress: GKE Ingress class "gce" fronting the API Gateway Service
- Namespace: default (assume services are deployed there)
- Service types: ClusterIP for all internal services

2) Services and Ports (match Helm values exactly)
- api-gateway: 8080
- identity-service: 8085
- product-service: 8081
- order-service: 8082
- cart-service: 8083
- payment-service: 8084

3) Routing via API Gateway (Spring Cloud Gateway)
- Routes:
  - /api/identity/** -> identity-service:8085
  - /api/products/** -> product-service:8081
  - /api/cart/** -> cart-service:8083
  - /api/orders/** -> order-service:8082
  - /api/payments/** -> payment-service:8084
- Rate limiting with RequestRateLimiter; Redis backend is optional
- Security header: X-API-Key (value from secret)

4) Health, Metrics, and Tracing
- Liveness/Readiness probes: /actuator/health/liveness and /actuator/health/readiness enabled for services
- Prometheus metrics endpoint: /actuator/prometheus for all services
- OpenTelemetry (OTLP/HTTP) exporter target: in-cluster Grafana Alloy receiver at
  http://grafana-k8s-monitoring-alloy-receiver.grafana.svc.cluster.local:4318
- Tracing propagators: tracecontext,baggage

5) Databases
- Each service uses its own PostgreSQL database (logical separation): identitydb, productdb, orderdb, cartdb, paymentdb
- Show DBs as separate logical components; in production these may be Cloud SQL instances or managed Postgres

6) CI/CD & Container Registry
- Images are built and pushed by GitHub Actions
- Image registry: GHCR under repository
  ghcr.io/kayis-rahman/mis-cloud-native-reseach/<service>:<tag>
- Helm chart path: helm/mis-cloud-native
- Deployments are applied via helm upgrade --install

7) Network Policy (api-gateway)
- Egress allowed to: ports 8081–8085 (services), 53 (DNS TCP/UDP), 6379 (Redis)

8) Environment Profiles
- Global environment usually production; assume probes and observability are enabled

Diagram style and content guidelines:
- Prefer a top-to-bottom (graph TB) layout: Client/Ingress at top, services in the middle, databases below, observability/CI-CD on the side
- Use clear groupings (subgraphs) for: GKE Cluster, Applications, Observability, Databases, CI/CD
- Show Services (ClusterIP) and Deployments distinctly if space permits; otherwise, keep them combined but indicate the service port
- Include optional Redis (for rate limiting) with a note that it’s optional
- Add arrows for routing paths from api-gateway to downstream services, labeled with their route prefixes
- Include arrows from services to Prometheus (metrics scraping) and to Grafana Alloy (OTLP traces)
- Include arrows from CI/CD to GHCR and to the GKE cluster via Helm

Acceptance criteria:
- Ports must match: 8080 (gateway), 8081 product, 8082 order, 8083 cart, 8084 payment, 8085 identity
- Health endpoints and Prometheus exposure must be represented
- OTLP endpoint and propagators present in legend or diagram annotations
- GKE Ingress (gce) in front of api-gateway Service
- GHCR image path and Helm-based deployment are visible in the diagram

Output format:
1) Start with a short summary (2–4 sentences)
2) Provide the Mermaid diagram in a fenced code block: ```mermaid ... ```
3) Provide a concise legend explaining icons, ports, and optional Redis
4) Optionally add a PlantUML alternative or a linkable image export if supported

Example node names (use similar but not necessarily identical):
- Users / Clients
- GKE Ingress (class: gce)
- Service: api-gateway (8080)
- product (8081), order (8082), cart (8083), payment (8084), identity (8085)
- Redis (optional)
- Prometheus, Grafana Alloy Receiver (4318), Grafana
- Databases: productdb, orderdb, cartdb, paymentdb, identitydb
- CI/CD: GitHub Actions; Registry: GHCR (ghcr.io/kayis-rahman/mis-cloud-native-reseach/<service>:<tag>)

Important: Do not invent components beyond the items listed above. Keep the diagram faithful to the given repository and Helm values.

---

How to use this prompt
- Paste it into your AI tool and run. The output should be immediately usable in GitHub (Mermaid) and in docs.
- If deploying to staging or development, adjust the environment label in the annotations; ports and routes stay the same.

Tip: Commit the AI’s Mermaid output to docs/ARCHITECTURE.md if you want to update the existing diagram, and regenerate an image (PNG/SVG) for presentations as needed.