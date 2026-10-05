# Week 4 Reflection

## 1. What changed in my understanding of Infrastructure as Code?

Before this project, I mainly viewed infrastructure provisioning and server configuration as separate activities.

Building the KijaniKiosk pipeline showed me that Infrastructure as Code becomes more useful when the complete lifecycle is connected. Terraform provisions and tracks the infrastructure, while Ansible configures the operating system and application services.

The pipeline connects both tools so that the infrastructure created by Terraform becomes the infrastructure configured by Ansible without requiring manual IP configuration.

## 2. Why does idempotency matter?

Idempotency makes infrastructure automation safe and repeatable.

After the environment converged, Terraform reported:

    0 added, 0 changed, 0 destroyed

Ansible also reported:

    changed=0
    failed=0

for all three servers.

This demonstrated that running the same automation repeatedly does not unnecessarily recreate infrastructure or modify resources that are already in the required state.

## 3. What was the most challenging integration point?

The most challenging part was connecting the different tools reliably.

Terraform needed remote state in MinIO. Multipass VM addresses needed to be discovered dynamically. SSH access needed to work on newly provisioned machines, and the discovered addresses then needed to be passed automatically into the Ansible inventory.

I also encountered and resolved issues involving:

- MinIO image availability
- MinIO filesystem permissions
- SSH host-key verification
- Ansible check-mode behaviour
- Dynamic inventory generation
- systemd security hardening

These issues helped me understand that a successful IaC pipeline needs to handle both provisioning and the handoff between tools.

## 4. What did I learn from systemd hardening?

I learned that running a service using a dedicated account alone does not provide sufficient security.

The service was hardened using controls including capability removal, filesystem protection, namespace restrictions, address-family restrictions and syscall filtering.

The final kk-payments service achieved a systemd security exposure score of:

    1.1 OK

This was below the required score of 2.5.

## 5. What would I improve for a production environment?

For production I would improve the solution by:

- Using a highly available remote Terraform backend
- Using a proper secrets-management platform
- Removing lab/default credentials
- Introducing CI/CD validation
- Pinning infrastructure dependencies and versions
- Adding automated infrastructure tests
- Adding centralized monitoring and alerting
- Adding backup and disaster-recovery procedures
- Using production cloud or data-centre infrastructure instead of local Multipass VMs

## Conclusion

The main lesson from this project is that reproducibility depends on the complete workflow rather than individual Terraform or Ansible files.

A reliable IaC solution needs provisioning, configuration management, state management, dynamic handoff between tools, security controls, validation and idempotency working together.
