# Week 8 – Container Delivery Pipeline Reflection

## 1. What risks should CI/CD automation address?

The most important risks are deploying untested images, exposing credentials, and releasing an application that cannot serve traffic reliably.

During this project, I learned that a successful Docker build does not automatically mean an application is healthy. My initial container responded to requests, but Docker reported it as unhealthy because the health check could not connect through localhost. I corrected the health check and rebuilt the image before deploying it.

A future CI/CD pipeline should automatically validate the application build, image size, security configuration, health checks, and deployment readiness. It should also prevent deployment when any critical verification fails.

## 2. How did translating plain-language requirements into technical instructions help?

The assignment described outcomes such as a lightweight image, a private registry, two running replicas, and automatic failure recovery.

I translated these outcomes into measurable technical checks. For example, I verified the image size, confirmed that the application runs as a non-root user, tested the health endpoint, and checked that Kubernetes maintained two ready replicas.

The self-healing experiment demonstrated this approach clearly. I deleted one Pod and measured the time Kubernetes took to restore the desired state. The observed recovery time was eight seconds.

This helped me understand how deployment requirements can become repeatable verification steps.

## 3. Which hardcoded values should move to ConfigMaps or Secrets?

The application currently uses fixed values for its port, deployment image, and health-check configuration.

Non-sensitive runtime settings, such as application configuration and feature flags, could be managed through Kubernetes ConfigMaps. The application port can also be configured through environment variables.

Sensitive values, including registry credentials, database passwords, API tokens, and external service credentials, should be managed through Kubernetes Secrets or a dedicated secrets-management solution.

The image reference should be updated through an automated deployment process so that every release uses a traceable, immutable image.

In Week 9, I would focus on automating these checks and deployment steps through a CI/CD pipeline, reducing manual intervention while retaining verification and rollback controls.
