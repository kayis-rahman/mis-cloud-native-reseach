Containerizing Services - Build and Run Instructions

This repository contains five Spring Boot services, each with its own Dockerfile and .dockerignore located in services/<service>.
Services: identity (9000), cart (9002), product (9001), order (9003), payment (9004)

Images are built using a secure multi-stage approach:
- Builder: maven:3.9.8-eclipse-temurin-17-alpine (used with Dockerfile directive: FROM --platform=linux/amd64 ...)
- Runtime: eclipse-temurin:17-jre-alpine
- Non-root user, minimal JAVA_OPTS

Prerequisites
- Docker installed
- Internet access to download base images and Maven dependencies

Build an Image (from repository root)
# Replace <service> with one of: identity, cart, product, order, payment
cd services/<service>
# Build the image (tag is optional)
docker build -t sparkage/<service>-service:latest .

Run a Container
# Example for product service (exposes 9001 by default)
docker run --rm -p 9001:9001 --name product sparkage/product-service:latest

# Other services and default ports
# identity: 9000 -> docker run --rm -p 9000:9000 sparkage/identity-service:latest
# cart:     9002 -> docker run --rm -p 9002:9002 sparkage/cart-service:latest
# order:    9003 -> docker run --rm -p 9003:9003 sparkage/order-service:latest
# payment:  9004 -> docker run --rm -p 9004:9004 sparkage/payment-service:latest

Passing environment (optional)
# Spring config via env variables (examples)
# -D style props can be added via JAVA_OPTS; the image reads JAVA_OPTS
# Example: override server.port to 9090 (not typical since image EXPOSE is fixed)
docker run --rm -e JAVA_OPTS="-Dserver.port=9090" -p 9090:9090 sparkage/product-service:latest

Multi-arch (optional)
# If you need multi-arch (e.g., amd64+arm64) and have Buildx set up:
docker buildx build --platform linux/amd64,linux/arm64 -t sparkage/product-service:latest --push .

Notes
- The Dockerfiles leverage Maven cache mounts and go-offline to speed up builds.
- Each image runs as a non-root user (spring) to improve container security.
- The runtime image is JRE-only and Alpine-based to minimize size.
- Tests run against an in-memory H2 database. Use scripts/run_tests.sh to execute tests inside a Maven container without requiring access to the host Docker daemon.
