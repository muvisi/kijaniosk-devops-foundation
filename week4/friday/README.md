# KijaniKiosk Full IaC Pipeline

## Overview

This project implements an end-to-end Infrastructure as Code pipeline using Terraform and Ansible.

Terraform provisions the infrastructure and stores its state remotely in MinIO. Ansible dynamically receives the provisioned VM addresses and configures the Ubuntu servers to the required KijaniKiosk baseline.

## Architecture

    pipeline.sh
        |
        +-- Terraform
        |     |
        |     +-- Remote state -> MinIO
        |     |
        |     +-- app_server module
        |            |
        |            +-- kijanikiosk-api
        |            +-- kijanikiosk-payments
        |            +-- kijanikiosk-logs
        |
        +-- Multipass IP discovery
        |
        +-- Dynamic inventory.ini
        |
        +-- Ansible
              |
              +-- Packages
              +-- Service accounts
              +-- Directories and permissions
              +-- Environment configuration
              +-- systemd services
              +-- UFW firewall
              +-- Persistent journald
              +-- Logrotate
              +-- Security hardening

## Terraform

The Terraform configuration demonstrates:

- A reusable app_server module
- for_each for the three application servers
- Variables for configurable infrastructure values
- Outputs for provisioned server information
- Remote S3-compatible Terraform state using MinIO
- Idempotent infrastructure provisioning

The managed servers are:

- kijanikiosk-api
- kijanikiosk-payments
- kijanikiosk-logs

After convergence, Terraform reports:

    Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

A subsequent Terraform plan reports:

    No changes. Your infrastructure matches the configuration.

## Ansible

Ansible configures the three Ubuntu 22.04 servers with:

- Required packages
- Dedicated service accounts
- KijaniKiosk directory structure
- Correct ownership and permissions
- Environment files
- systemd services
- UFW firewall rules
- Persistent journald
- Logrotate configuration
- systemd security hardening

The Ansible inventory is generated dynamically by pipeline.sh using the current Multipass IP addresses.

## Running the Pipeline

See environment-setup.md for prerequisite setup.

From week4/friday run:

    chmod +x pipeline.sh
    ./pipeline.sh

The pipeline executes Terraform before Ansible and automatically performs the infrastructure-to-configuration handoff.

## Idempotency

Two complete pipeline executions were captured.

Terraform reported:

    Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

The converged Ansible execution reported:

    kijanikiosk-api       changed=0 failed=0
    kijanikiosk-logs      changed=0 failed=0
    kijanikiosk-payments  changed=0 failed=0

The final Terraform validation also reported no changes.

Evidence is stored in:

- pipeline-run-1.log
- pipeline-run-2.log

## Service Validation

The pipeline validates the three application services:

    kk-api       -> active
    kk-payments  -> active
    kk-logs      -> active

## Security Validation

The kk-payments systemd service was hardened and achieved:

    Overall exposure level for kk-payments.service: 1.1 OK

The required exposure score is below 2.5.

## Dynamic Inventory

The pipeline does not rely on hardcoded VM IP addresses.

After Terraform completes, pipeline.sh queries Multipass for the current IP address of each VM and generates ansible/inventory.ini automatically.

This allows the Terraform and Ansible layers to remain integrated even if VM addresses change.

## Remote State

Terraform state is stored in the MinIO bucket:

    kijanikiosk-tfstate

The Terraform state object is stored under:

    week4/friday/terraform.tfstate

Local Terraform state files and MinIO data are excluded from Git.

## Troubleshooting

Check the VMs:

    multipass list

Check Ansible connectivity:

    cd ansible
    ansible all -i inventory.ini -m ping

Check MinIO:

    ss -ltnp | grep ':9000'

Check the remote Terraform state:

    ~/go/bin/mc ls --recursive local/kijanikiosk-tfstate

Check the Payments service:

    ansible payments -i ansible/inventory.ini -b \
      -a "systemctl is-active kk-payments"

Check the Payments security score:

    ansible payments -i ansible/inventory.ini -b \
      -m shell \
      -a "systemd-analyze security kk-payments --no-pager | grep 'Overall exposure'"

## Evidence

Two successful complete pipeline runs are included:

- pipeline-run-1.log
- pipeline-run-2.log

Both demonstrate Terraform convergence, successful Ansible configuration, active application services, a Payments security exposure score of 1.1, and a final Terraform plan with no changes.
