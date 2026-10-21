# KijaniKiosk CI Pipeline — Board-Ready Delivery Report

**Project:** KijaniKiosk DevOps Foundation  
**Reporting period:** Week 5  
**Delivery status:** Pipeline operational; final submission evidence under review  
**Repository branch:** `feature/week5-ci-pipeline`

## Executive Summary

KijaniKiosk has implemented an automated software delivery pipeline that checks application changes before they are released to the organization's package repository. The objective is to improve release reliability, reduce manual verification, and give stakeholders clearer evidence that software has passed defined quality and security checks.

The pipeline is operational and has been tested against six deliberately introduced failures. In each case, the system stopped the affected release from progressing inappropriately. After the fault was removed, a successful run confirmed that normal delivery could resume.

The implementation establishes a repeatable foundation for software delivery. It does not, by itself, guarantee that every application defect or security weakness will be detected.

## How Software Moves Through the Pipeline

Every pipeline run follows a defined sequence of checks:

| Step | Purpose | Business Value |
|---|---|---|
| Code checks | Validate basic code syntax and structure | Identify simple errors early |
| Build | Prepare a distributable application package | Produce a consistent release candidate |
| Functional tests | Verify expected application behaviour | Reduce the risk of releasing defects |
| Security audit | Check dependencies for known high-severity vulnerabilities | Identify important dependency risks |
| Artifact archive | Preserve the package and record its fingerprint | Support traceability and investigation |
| Publication | Deliver the approved package to Nexus | Provide a controlled distribution location |

Functional tests and security auditing operate in parallel. Both must succeed before the package can advance to archiving and publication. This design reduces unnecessary waiting without removing either verification requirement.

The pipeline uses a fixed Node.js container image to provide a consistent execution environment. A ten-minute limit prevents stalled jobs from running indefinitely.

## Delivery Evidence and Results

The final successful recovery run used source commit `199482c` and produced package version `1.0.0-199482c`.

The execution log confirmed successful code checks, package creation, functional test execution, security auditing, artifact archiving, fingerprint recording, and publication to the Nexus package repository.

The security audit reported zero vulnerabilities in the checked dependencies. This is a useful result for the tested dependency set, but it is not a comprehensive security assessment of the entire application.

The final run completed in approximately three seconds according to the recorded pipeline timestamps. This demonstrates good performance for the current small application, although future workloads may take longer.

Each package version incorporates a source commit identifier, allowing a published release to be associated with the code used to produce it.

## What Happens When Something Goes Wrong

A reliable delivery process must respond safely when checks fail. Six independent failure scenarios were deliberately introduced: code checking, building, functional testing, security auditing, artifact archiving, and publication.

When code checking or building failed, later stages did not proceed. When either functional testing or security auditing failed, the other parallel check was allowed to complete, but the package was not published. When archiving failed, publication was blocked.

In the publication failure scenario, earlier checks succeeded and the package was archived, but the overall run was correctly reported as failed. This distinction matters because a successfully prepared package is not the same as a successfully published release.

Following each scenario, the fault was disabled and the pipeline recovered successfully. Failure reporting and test-result collection continued to run, providing useful diagnostic information.

These results demonstrate that the tested failure conditions are handled predictably and that an unsuccessful release is not incorrectly presented as successful.

## Security, Accountability, and Operational Controls

Publication uses credentials supplied through Jenkins' protected credential mechanism. The successful run showed credential masking and disabled command tracing during the publication step. The pipeline also executed a command to remove its temporary npm configuration file.

Artifact fingerprints help identify the files associated with a particular run, while version identifiers connect packages to source changes.

These measures improve accountability. However, complete confirmation that temporary credentials are created and removed within the same protected command, and that no secrets exist in repository history, requires a separate source and history audit.

## Remaining Work and Recommendations

Before final sign-off, the team should confirm that two distinct package versions from different commits are present in Nexus, inspect their package contents, and retain evidence of the published artifacts.

The credential-handling implementation and repository history should also be reviewed against the security checklist. The completed failure scenarios and final recovery results should remain available as supporting evidence.

The next improvement should be automatic validation of proposed code changes before they are merged, followed by stronger release approval controls as the development team grows.

## Scope and Limitations

This delivery validates the current KijaniKiosk demonstration application and its configured Jenkins-to-Nexus workflow. It does not establish production deployment readiness, comprehensive application security, high-load performance, disaster recovery, or suitability for a substantially larger engineering organization. Those areas require additional testing and operational controls before broader adoption.
