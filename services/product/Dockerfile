# Multi-stage build for Product Service
# Builder stage: use lightweight Maven + JDK
FROM maven:3.9.8-eclipse-temurin-17-alpine AS builder
WORKDIR /workspace
# Copy only pom.xml first for better layer caching
COPY pom.xml ./
# Pre-download dependencies (no source yet)
RUN --mount=type=cache,target=/root/.m2 mvn -q -e -DskipTests dependency:go-offline
# Copy sources and build
COPY src ./src
RUN --mount=type=cache,target=/root/.m2 mvn -q -e -DskipTests package

# Runtime stage: minimal JRE image
FROM eclipse-temurin:17-jre-alpine
ENV JAVA_OPTS="-XX:MaxRAMPercentage=75 -XX:+UseContainerSupport -Djava.security.egd=file:/dev/./urandom"
WORKDIR /app
# Create non-root user
RUN addgroup -S spring && adduser -S spring -G spring
# Copy fat jar
COPY --from=builder /workspace/target/*.jar /app/app.jar
# Reduce image attack surface
EXPOSE 9001
USER spring:spring
ENTRYPOINT ["sh","-c","exec java $JAVA_OPTS -jar /app/app.jar"]
