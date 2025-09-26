# AI Agent Instructions

This repository contains instructions for AI coding agents working on the Argo Rollouts demo application.

## PR Guidelines

When creating PRs always append to the description:

```
@gemini-code-assist
@claude
```

## Repository Context

- **Project**: Argo Rollouts demo application showcasing progressive delivery
- **Language**: Go (HTTP server), Docker (containerization), Kubernetes (deployment)
- **Focus**: Progressive delivery, canary deployments, blue-green deployments, analysis
- **Testing**: Load testing with wrk, automated analysis with Prometheus metrics

## Key Considerations for AI Agents

1. **Rollout Safety**: Any changes should maintain the safety and reliability of deployment strategies
2. **Multi-Variant Support**: The application supports multiple color variants with different behaviors (normal, bad, slow)
3. **Containerization**: All changes should work correctly within the Docker containerization setup
4. **Kubernetes Native**: Consider impact on Kubernetes manifests and Argo Rollouts configurations
5. **CI/CD Integration**: Changes should work with the existing GitHub Actions workflows

## Testing Requirements

- Build and test changes locally before committing
- Verify Docker image builds correctly with different variants
- Test Kubernetes deployment examples when modifying manifests
- Run load tests when changing application behavior
- Validate CI/CD workflows for image building and publishing

## Documentation Requirements

- Update README.md for any new features or changes to usage
- Update example documentation in the `examples/` directory
- Add comments for complex logic or non-obvious design decisions
- Document any new environment variables or configuration options
