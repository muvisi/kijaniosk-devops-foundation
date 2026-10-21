# Week 5 — Fault Injection and Recovery Log

## Project Information

- **Project:** KijaniKiosk CI Pipeline
- **Jenkins Job:** KijaniKiosk-CI
- **Branch:** feature/week5-ci-pipeline
- **Commit:** 199482cc2c449c4e563bc9a9df6011bf07812d4d
- **Package Version:** 1.0.0-199482c
- **Registry:** http://localhost:8081/repository/kijanikiosk-npm/
- **Test Method:** Jenkins `FAULT_STAGE` build parameter

## Objective

Verify that each pipeline stage correctly handles an intentional failure, prevents unsafe downstream execution, executes post-build reporting, and recovers when `FAULT_STAGE=None`.

## Fault Injection Results

| Fault Stage | Observed Behaviour | Recovery |
|---|---|---|
| Lint | Lint failed; Build, Verify, Archive, and Publish were skipped. | SUCCESS |
| Build | Lint passed; Build failed; Verify, Archive, and Publish were skipped. | SUCCESS |
| Test | Test failed; Security Audit completed; Archive and Publish were skipped. | SUCCESS |
| Security Audit | Security Audit failed; Test completed; Archive and Publish were skipped. | SUCCESS |
| Archive | Quality checks passed; Archive failed; Publish was skipped. | SUCCESS |
| Publish | Quality checks and Archive passed; Publish failed before publishing. | SUCCESS |

## Engineering Rationale

### 1. Lint Failure

**Observed:** The pipeline stopped after the intentional Lint failure.

**Rationale:** Code that fails basic syntax and quality checks should not proceed to building, testing, or publication.

### 2. Build Failure

**Observed:** Lint passed, but Build failed. All subsequent stages were skipped.

**Rationale:** An unsuccessful build cannot produce a verified release artifact and must not proceed to publication.

### 3. Test Failure

**Observed:** Test failed intentionally while the parallel Security Audit completed. Archive and Publish were skipped.

**Rationale:** Software that fails functional verification must not be published, regardless of its security audit result.

### 4. Security Audit Failure

**Observed:** Security Audit failed intentionally while Test completed. Archive and Publish were skipped.

**Rationale:** Security verification is a release gate. A security failure must prevent publication even when functional tests pass.

### 5. Archive Failure

**Observed:** Lint, Build, Test, and Security Audit passed. Archive failed before artifact archiving, and Publish was skipped.

**Rationale:** Publication should not proceed when the required archived artifact and fingerprint evidence have not been recorded.

### 6. Publish Failure

**Observed:** All quality checks passed. Jenkins archived and fingerprinted the artifact before the intentional Publish failure.

**Rationale:** A publishing failure must mark the pipeline as failed. The archived artifact provides evidence for investigation and controlled recovery.

## Post-Build Behaviour

Across the injected failures, Jenkins executed post-build actions, including:

- Removing `.npmrc` if present.
- Recording JUnit test results.
- Reporting pipeline failure.
- Reporting build status changes where applicable.

The console output also showed:

```text
[Checks API] No suitable checks publisher found.






















```

This message did not prevent successful recovery builds.

## Final Recovery Evidence

After the Publish fault, the pipeline was rerun with `FAULT_STAGE=None`.

All six stages completed successfully.

```text
20:54:08 Archiving artifacts
20:54:08 Recording fingerprints
20:54:09 + kijanikiosk@1.0.0-199482c
20:54:09 SUCCESS: Published kijanikiosk version 1.0.0-199482c.
Finished: SUCCESS
```

**Final status:** SUCCESS

**Published package:** `kijanikiosk-1.0.0-199482c.tgz`

**Artifact URL:**

http://localhost:8081/repository/kijanikiosk-npm/kijanikiosk/-/kijanikiosk-1.0.0-199482c.tgz

## Conclusion

All six fault-injection scenarios were successfully tested.

Each intentional failure correctly prevented inappropriate downstream execution. Post-build reporting continued, and each scenario was followed by a successful recovery build using `FAULT_STAGE=None`.

The final recovery confirmed that linting, building, parallel testing and security auditing, artifact archiving, fingerprinting, and Nexus publication were functioning correctly.

The pipeline was left in a successful state, ready for final submission.
