---
description: Argo Rollouts Demo Application - GitHub Copilot Instructions
globs: "**/*.{go,yaml,yml,dockerfile,Dockerfile,md,sh}"
alwaysApply: true
---

# Argo Rollouts Demo Application

This repository contains a demo application for [Argo Rollouts](https://github.com/argoproj/argo-rollouts), showcasing various deployment strategies and progressive delivery features. The application is built with Go, containerized with Docker, and deployed using Kubernetes and Argo Rollouts.

## Project Context

- **Main Application**: Go HTTP server that serves colored pages with configurable error rates and latency
- **Load Tester**: Utility Docker image with `wrk` for load testing and `jq` for JSON processing
- **Examples**: Various Argo Rollouts deployment strategies (canary, blue-green, analysis, etc.)
- **CI/CD**: GitHub Actions for building and publishing Docker images to GitHub Container Registry

## Key Principles

- **Progressive Delivery**: Focus on safe, gradual deployments using Argo Rollouts
- **Observability**: Built-in metrics, error injection, and latency simulation for testing
- **Container-First**: All components are containerized and Kubernetes-native
- **Multi-Variant**: Support for multiple color variants with different behaviors (normal, bad, slow)

## Before Writing Code

1. Understand the Argo Rollouts deployment strategy being modified
2. Consider the impact on progressive delivery features
3. Test changes with both normal and error scenarios
4. Ensure compatibility with existing Kubernetes manifests

## Development Guidelines

### Go Development

#### Code Style and Structure
- Use standard Go formatting with `gofmt`
- Follow Go naming conventions (PascalCase for exported, camelCase for unexported)
- Use meaningful variable and function names that describe their purpose
- Keep functions focused and small (preferably under 50 lines)
- Use early returns to reduce nesting

#### Error Handling
- Always handle errors explicitly, never ignore them
- Use descriptive error messages that help with debugging
- Log errors at appropriate levels before returning them
- For HTTP handlers, return appropriate status codes (400, 500, etc.)

#### HTTP Server Patterns
- Use `http.ServeMux` for routing as shown in the existing codebase
- Implement proper middleware patterns for logging, metrics, etc.
- Use context for request-scoped values and cancellation
- Implement graceful shutdown handling

#### Configuration Management
- Use environment variables for configuration as shown in the existing code
- Provide sensible defaults for all configuration values
- Validate configuration on startup and fail fast if invalid
- Document all environment variables in README.md

#### Example: Adding a new endpoint
```go
func (s *server) handleNewEndpoint(w http.ResponseWriter, r *http.Request) {
    if r.Method != http.MethodGet {
        http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
        return
    }
    
    // Add your logic here
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(http.StatusOK)
    json.NewEncoder(w).Encode(map[string]string{
        "status": "ok",
    })
}
```

### Docker and Containerization

#### Multi-Stage Builds
- Always use multi-stage builds for Go applications
- Use minimal base images like `scratch` or `alpine` for production images
- Copy only necessary files to the final image
- Set appropriate build arguments for configuration

#### Build Arguments
- Support `COLOR`, `ERROR_RATE`, and `LATENCY` build arguments as in existing Dockerfile
- Use build arguments to create different behavioral variants
- Document all build arguments and their effects

#### Example: Adding a new build argument
```dockerfile
ARG NEW_CONFIG
ENV NEW_CONFIG=${NEW_CONFIG}
```

### Kubernetes and Argo Rollouts

#### Manifest Structure
- Use Kustomize for managing different environments
- Follow Kubernetes resource naming conventions
- Include proper labels and selectors for Argo Rollouts
- Use appropriate resource limits and requests

#### Rollout Strategies
- Understand the different rollout strategies: canary, blue-green, analysis
- Configure appropriate success conditions and failure thresholds
- Use Argo Rollouts analysis templates for automated decision making
- Include proper rollback configurations

#### Service Mesh Integration
- Support Istio traffic splitting configurations when applicable
- Use proper destination rules and virtual services
- Configure appropriate timeout and retry policies

#### Example: Adding a new rollout step
```yaml
steps:
- setWeight: 20
- pause: {duration: 30s}
- analysis:
    templates:
    - templateName: success-rate
    args:
    - name: service-name
      value: canary-demo
```

### Load Testing and Analysis

#### Load Tester Usage
- Use the `argoproj/load-tester` image for consistent load testing
- Configure appropriate test duration and connection parameters
- Use the provided `report.lua` script for JSON output
- Analyze results with `jq` for automated decision making

#### Metrics and Analysis
- Define success criteria (error rate < 5%, latency < 100ms)
- Use Prometheus metrics for analysis templates
- Configure appropriate analysis intervals and thresholds

#### Example: Load test configuration
```yaml
containers:
- name: load-tester
  image: argoproj/load-tester:latest
  command: [sh, -c, -x, -e]
  args:
  - |
    wrk -t10 -c40 -d45s -s report.lua http://canary-demo-preview/color
    jq -e '.errors_ratio <= 0.05 and .latency_avg_ms < 100' report.json
```

### CI/CD and GitHub Actions

#### Workflow Structure
- Build and test on pull requests
- Build and push images only on main branch
- Support matrix builds for color variants
- Use appropriate caching strategies

#### Image Tagging
- Use semantic versioning when possible
- Tag with branch name, commit SHA, and `latest` for main branch
- Build all color variants (red, orange, yellow, green, blue, purple)
- Create normal, bad (high error), and slow (high latency) variants

#### Security
- Use GitHub's built-in GITHUB_TOKEN for authentication
- Follow principle of least privilege for workflow permissions
- Scan images for vulnerabilities before publishing

### Testing Guidelines

#### Unit Testing
- Write tests for all public functions
- Use table-driven tests for multiple scenarios
- Mock external dependencies appropriately
- Achieve reasonable test coverage (>80%)

#### Integration Testing
- Test HTTP endpoints with real requests
- Verify error injection and latency simulation
- Test graceful shutdown scenarios
- Validate configuration loading

#### Load Testing
- Use the load-tester image for performance validation
- Test different load patterns and durations
- Validate error rates and latency thresholds
- Document performance benchmarks

### Documentation

#### README Updates
- Keep the main README.md current with new features
- Document all environment variables and their effects
- Include usage examples for new functionality
- Update the examples table when adding new deployment strategies

#### Code Comments
- Comment complex algorithms or business logic
- Document public APIs and their expected behavior
- Explain non-obvious configuration choices
- Include examples in comments when helpful

#### Deployment Documentation
- Document new Argo Rollouts strategies in their respective directories
- Include step-by-step setup instructions
- Explain the purpose and benefits of each strategy
- Provide troubleshooting guidance

## Common Tasks

### Building and Running
```bash
# Build the application
make build

# Build Docker image
make image COLOR=blue

# Build with error injection
make image COLOR=red ERROR_RATE=15

# Build with latency simulation
make image COLOR=yellow LATENCY=2

# Run locally
go run main.go -listen-addr=:8080
```

### Testing Deployment
```bash
# Apply a rollout example
kustomize build examples/canary | kubectl apply -f -

# Watch the rollout
kubectl argo rollouts get rollout canary-demo --watch

# Update to trigger a rollout
kubectl argo rollouts set image canary-demo "*=argoproj/rollouts-demo:yellow"

# Promote or abort
kubectl argo rollouts promote canary-demo
kubectl argo rollouts abort canary-demo
```

### Load Testing
```bash
# Run load test with the load-tester image
kubectl run load-test --rm -i --image=argoproj/load-tester:latest -- \
  sh -c "wrk -t10 -c40 -d45s -s report.lua http://canary-demo/color && \
         jq '.errors_ratio, .latency_avg_ms' report.json"
```

## Architecture Notes

- The main application serves static files (HTML, CSS, JS) and a `/color` API endpoint
- Color variants are built into separate Docker images with different behaviors
- The application supports error injection and latency simulation for testing rollout scenarios
- Load testing is performed using a separate container with `wrk` and `jq`
- Argo Rollouts manages the deployment strategy and traffic splitting
- Analysis templates use metrics to make automated promotion/rollback decisions

## Best Practices

1. **Always test changes with multiple scenarios** - normal, error injection, and high latency
2. **Use appropriate resource limits** in Kubernetes manifests
3. **Configure meaningful health checks** and readiness probes
4. **Monitor rollout progress** and set up proper alerting
5. **Document deployment strategies** with clear explanations of their benefits
6. **Keep examples simple but realistic** to help users understand the concepts
7. **Validate CI/CD changes** in feature branches before merging to main