# Multi-stage build for Payment Service
FROM --platform=linux/amd64 maven:3.9.8-eclipse-temurin-17-alpine AS builder
WORKDIR /workspace
COPY pom.xml ./
RUN --mount=type=cache,target=/root/.m2 mvn -q -e -DskipTests dependency:go-offline
COPY src ./src

# Test stage for dockerized test runs
FROM builder AS test
RUN --mount=type=cache,target=/root/.m2 mvn -q -e -DskipTests=false -DdisableTestcontainers=true test

# Package stage (skip tests here)
FROM builder AS package
RUN --mount=type=cache,target=/root/.m2 mvn -q -e -DskipTests package

FROM eclipse-temurin:17-jre-alpine
ENV JAVA_OPTS="-XX:MaxRAMPercentage=75 -XX:+UseContainerSupport -Djava.security.egd=file:/dev/./urandom"
WORKDIR /app
RUN addgroup -S spring && adduser -S spring -G spring
COPY --from=package /workspace/target/*.jar /app/app.jar
EXPOSE 9004
USER spring:spring
ENTRYPOINT ["sh","-c","exec java $JAVA_OPTS -jar /app/app.jar"]
