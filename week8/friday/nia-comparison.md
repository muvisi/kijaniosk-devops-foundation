# Nia's Comparison: Week 7 and Week 8 Container Delivery

## Introduction

The purpose of this comparison is to explain how the KijaniKiosk deployment process changes when an application is packaged as a container and managed by Kubernetes. The comparison focuses on deployment, rollback, failure recovery, and scaling. It also considers the operational improvements achieved during Week 8 and the work still needed to make delivery fully automated.

The Week 8 implementation was tested locally using Docker, GitHub Container Registry, and Minikube. The available repository does not contain the Week 7 deployment artifacts, so the Week 7 descriptions below represent a conventional manually managed deployment baseline rather than independently verified measurements.

## Deployment Comparison

| Area | Week 7: Manual Deployment Baseline | Week 8: Container Delivery |
|---|---|---|
| Deployment mechanism | Application files and dependencies are deployed and configured directly on a server. | A versioned Docker image is published to a private registry and deployed through Kubernetes. |
| Rollback mechanism | The operator restores an earlier application version and restarts the service manually. | Kubernetes supports reverting a Deployment to an earlier revision, provided the previous image remains available. |
| Failure recovery | An operator investigates the failure and restores the application, unless a separate recovery mechanism exists. | Kubernetes automatically creates a replacement Pod to maintain the desired number of replicas. |
| Scaling | Additional instances require manual configuration or separate automation. | The Deployment manages the desired replica count; two replicas were successfully maintained during testing. |

## Deployment Reliability

A manually managed deployment depends heavily on the operator following the correct sequence. Differences between servers can also create problems when installed dependencies, runtime versions, or configuration settings are inconsistent. These differences make deployments more difficult to reproduce and troubleshoot.

During Week 8, the application was packaged into a production Docker image using a multi-stage build. The build process separated development dependencies from the final runtime environment. The resulting image was approximately 44.93 MB, which satisfied the assignment requirement of remaining below 100 MB.

The container was configured to run as a non-root user. Its health check was also tested and corrected before deployment. This demonstrated why successful image creation alone is insufficient evidence that an application is ready for production.

The image was published to a private GitHub Container Registry repository with an application-version and Git-commit-based tag. After publishing, the local registry tag was removed and the image was downloaded again. Matching image digests confirmed that the published artifact could be retrieved consistently.

## Failure Recovery and Availability

The most significant operational improvement was Kubernetes' ability to restore the desired application state automatically.

The application was deployed with two replicas. Both became ready, and the Kubernetes Service exposed them through a single network endpoint. Requests to the health endpoint returned a successful response, confirming that the application could be reached through the Service.

To test failure recovery, one running Pod was deliberately deleted. Kubernetes detected that the desired replica count was no longer satisfied and created a replacement Pod.

The deletion was recorded at 21:13:50 East Africa Time on 4 November 2026. Two ready replicas were observed again at 21:13:58, giving a measured recovery time of eight seconds. The observation used polling at two-second intervals, so the result represents the observed recovery time rather than the precise instant readiness changed.

After recovery, the application remained accessible and returned a healthy response. This provided direct evidence of self-healing rather than relying only on Kubernetes documentation or expected behavior.

## Scaling and Operational Trade-offs

Managing multiple application instances becomes easier when a deployment platform maintains the desired number of replicas. In Week 8, Kubernetes successfully maintained two running instances and replaced a deleted instance without manual recreation.

However, container orchestration introduces additional operational responsibilities. Teams must manage image registry access, cluster resources, networking, health probes, and deployment configuration. A working container does not guarantee that Kubernetes will consider the application ready, which is why readiness checks are necessary.

The Week 8 implementation also remains a local demonstration. It does not establish production-level high availability because both replicas were running on a single Minikube node. A production deployment would need stronger infrastructure resilience, monitoring, secure configuration management, and appropriate capacity planning.

## Conclusion and Week 9 Readiness

Week 8 demonstrated a repeatable container delivery process, a lightweight runtime image, private image distribution, two ready application replicas, and automatic failure recovery measured at eight seconds. These are practical improvements over a conventional manual deployment baseline, although the specific Week 7 implementation still needs verification before making historical performance claims.

Week 9 should focus on connecting these individually verified activities into an automated CI/CD pipeline. Automated testing, image building, security checks, registry publishing, deployment verification, and controlled rollback would reduce manual effort and make the release process more consistent. The next improvement is not simply deploying faster, but making every release traceable, secure, testable, and recoverable.
