# CI/CD Quick Reference Guide

## 🚀 Quick Start

### 1. Initial Setup (One-time)
```bash
# Configure repository secrets in GitHub Settings > Secrets and variables > Actions
KUBE_CONFIG_STAGING=<base64-kubeconfig>
KUBE_CONFIG_PRODUCTION=<base64-kubeconfig>
DB_PASSWORD_STAGING=<password>
DB_PASSWORD_PRODUCTION=<password>
JWT_SECRET_STAGING=<secret>
JWT_SECRET_PRODUCTION=<secret>
GCP_SA_KEY=<service-account-json>  # if using GCP
```

### 2. Workflow Triggers

| Action | Trigger | Result |
|--------|---------|--------|
| Push to `develop` | Automatic | → Staging deployment |
| Push to `main` | Automatic | → Production deployment |
| Create PR | Automatic | → Code quality + tests only |
| Push `v*` tag | Automatic | → Release pipeline |
| Change service code | Automatic | → Service-specific pipeline |
| Manual dispatch | Manual | → Custom deployment options |

## 📋 Available Workflows

### Core Pipelines
- **`ci-cd-pipeline.yml`** - Main pipeline (full lifecycle)
- **`service-specific-cicd.yml`** - Optimized for single service changes
- **`release.yml`** - Release management and versioning

### Operations & Monitoring
- **`security-scan.yml`** - Daily security scanning
- **`infrastructure.yml`** - Terraform/Helm management
- **`monitoring.yml`** - Health checks every 15min
- **`dependency-management.yml`** - Weekly dependency audits

## 🛠️ Manual Operations

### Deploy Specific Service
```bash
# Via GitHub Actions UI
Workflow: Service-Specific CI/CD
Inputs:
  - service: [identity|product|cart|order|payment|api-gateway]
  - environment: [staging|production]
```

### Emergency Deployment
```bash
# Via GitHub Actions UI
Workflow: CI/CD Pipeline
Inputs:
  - deploy_environment: [staging|production]
  - services: "identity product" (or "all")
```

### Infrastructure Management
```bash
# Via GitHub Actions UI
Workflow: Infrastructure Management
Inputs:
  - action: [plan|apply|destroy|validate]
  - environment: [staging|production]
```

### Create Release
```bash
# Via GitHub Actions UI
Workflow: Release Management
Inputs:
  - version: "v1.2.3"
  - environment: [staging|production]
  - release_notes: "Description of changes"
```

## 🔍 Monitoring & Health Checks

### Service Health Status
```bash
# Automatic every 15 minutes
# Manual trigger via GitHub Actions UI
Workflow: Monitoring & Health Checks
Inputs:
  - environment: [staging|production]
  - check_type: [all|services|infrastructure|performance]
```

### Security Scanning
```bash
# Automatic daily at 2 AM UTC
# Manual trigger via GitHub Actions UI
Workflow: Security & Compliance Scan
Inputs:
  - scan_type: [all|images|code|infrastructure|secrets]
```

## 🔧 Script Usage (Local Development)

### Test Single Service
```bash
./scripts/run_tests.sh identity
```

### Build All Images
```bash
GHCR_OWNER=your-github-username GHCR_TOKEN=your-token ./scripts/docker-build-all.sh
```

### Deploy All Services
```bash
GLOBAL_REGISTRY=ghcr.io/your-username ./scripts/deploy_all_services.sh
```

### Security Scan
```bash
./scripts/scan_security.sh
IMAGE=ghcr.io/your-username/identity:latest ./scripts/scan_security.sh
```

### Smoke Test
```bash
./scripts/smoke_test_all_services.sh
SERVICE=identity ./scripts/smoke_test_a_service.sh
```

## 📊 Pipeline Status Indicators

### Success Indicators
- ✅ All checks passed
- 🟢 Deployment successful
- 🔒 Security scan clean
- 📈 Performance tests passed

### Warning Indicators
- ⚠️ Minor security issues found
- 🟡 Performance degradation detected
- 📋 Dependencies need updates

### Failure Indicators
- ❌ Tests failed
- 🔴 Deployment failed
- 🚨 Critical security vulnerabilities
- 💥 Infrastructure issues

## 🆘 Troubleshooting

### Pipeline Failures
1. Check GitHub Actions logs
2. Verify script permissions: `chmod +x scripts/*.sh`
3. Validate secrets configuration
4. Check Kubernetes connectivity

### Deployment Issues
```bash
# Validate infrastructure
./scripts/validate_infra.sh

# Check deployment status
./scripts/validate_deploy.sh

# Manual smoke test
./scripts/smoke_test_all_services.sh
```

### Security Scan Failures
1. Review Trivy reports in artifacts
2. Update vulnerable dependencies
3. Rebuild containers with updated base images
4. Check for false positives

## 📞 Emergency Procedures

### Rollback Production
1. Go to GitHub Releases
2. Find previous stable release
3. Use "Release Management" workflow
4. Deploy previous version to production

### Stop All Deployments
```bash
# Via kubectl (if you have access)
kubectl delete deployment --all -n default

# Or use destroy script
./scripts/destroy_all.sh
```

### Infrastructure Emergency
1. Use "Infrastructure Management" workflow
2. Action: "validate" to check status
3. If needed, use "destroy" to tear down
4. Contact infrastructure team

## 📈 Performance Optimization

### Faster Builds
- Service-specific pipeline triggers automatically for changed services
- Maven dependencies cached between runs
- Docker layer caching enabled

### Resource Management
- Parallel test execution across services
- Conditional deployment based on changes
- Efficient artifact storage and cleanup

### Cost Optimization
- Scheduled workflows run only when needed
- Service-specific builds reduce unnecessary work
- Efficient container registry usage

This quick reference provides everything you need to operate the CI/CD pipelines effectively!
