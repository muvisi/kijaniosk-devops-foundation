# KijaniKiosk DevOps Delivery Notes

## Overview

The KijaniKiosk project follows a simple Git-based DevOps workflow designed around the principles of Flow, Feedback and Learning.

## Flow

Development work is performed using small and controlled changes.

The repository uses three levels of branches:

- `main` represents the stable version of the project.
- `develop` is used to integrate development changes.
- `feature/*` branches are used to implement individual features.

For this project, the DevOps Starter Kit is developed in the `feature/starter-kit-files` branch.

Once the work is complete, a Pull Request is created from the feature branch into `develop`.

This approach allows changes to move through the development process without directly modifying the stable `main` branch.

## Feedback

Pull Requests provide a feedback point before changes are integrated.

The PR allows team members to:

- Review architectural decisions.
- Identify security issues.
- Review documentation.
- Suggest improvements.
- Verify that project requirements have been satisfied.

This reduces the possibility of incorrect or insecure changes being introduced into the shared development branch.

## Learning

Architectural decisions and lessons learned are documented in the repository.

For example, the project documents why network segmentation, least-privilege IAM permissions and multi-AZ deployment are important.

Feedback received during code reviews can be incorporated into future changes.

This creates a continuous learning cycle where the team's infrastructure and development practices improve over time.

## Delivery Workflow

The workflow used for this project is:

`main → develop → feature/starter-kit-files → Pull Request → develop`

This provides a simple but controlled process for delivering infrastructure documentation and future application changes.
