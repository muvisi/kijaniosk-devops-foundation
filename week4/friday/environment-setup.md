# KijaniKiosk Environment Setup

## Prerequisites

The Week 4 IaC pipeline requires Terraform, Ansible Core, Multipass, MinIO, MinIO Client (mc), SSH and an Ubuntu/Linux host.

## Verify Tools

    terraform version
    ansible --version
    multipass version

## Install Ansible

    sudo apt update
    sudo apt install -y ansible-core

## Install Multipass

    sudo snap install multipass

## SSH Key

Generate an SSH key for Ansible if one does not already exist:

    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -C "kijanikiosk-ansible"

Never commit the private SSH key.

## MinIO Terraform Backend

Start MinIO:

    MINIO_ROOT_USER=minioadmin \
    MINIO_ROOT_PASSWORD=minioadmin \
    nohup ~/go/bin/minio server "$(pwd)/minio-data" \
      --address ":9000" \
      --console-address ":9001" \
      > minio.log 2>&1 &

Configure the MinIO client:

    ~/go/bin/mc alias set local http://127.0.0.1:9000 minioadmin minioadmin

Create the Terraform state bucket:

    ~/go/bin/mc mb local/kijanikiosk-tfstate

The bucket only needs to be created once.

## Terraform Backend Environment

For this local lab:

    export AWS_ACCESS_KEY_ID=minioadmin
    export AWS_SECRET_ACCESS_KEY=minioadmin
    export AWS_DEFAULT_REGION=us-east-1

Production credentials must never be committed to Git.

## Run the Pipeline

From week4/friday:

    chmod +x pipeline.sh
    ./pipeline.sh

The pipeline performs:

1. Prerequisite validation
2. Terraform initialization, validation, plan and apply
3. Dynamic Multipass IP discovery
4. SSH bootstrap
5. Dynamic Ansible inventory generation
6. Ansible configuration
7. Service, security and Terraform idempotency validation

## Expected Infrastructure

The pipeline manages three Ubuntu 22.04 instances:

- kijanikiosk-api
- kijanikiosk-payments
- kijanikiosk-logs

The kk-payments systemd security exposure score must remain below 2.5.
