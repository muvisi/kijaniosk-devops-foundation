#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$BASE_DIR/terraform"
ANSIBLE_DIR="$BASE_DIR/ansible"
INVENTORY="$ANSIBLE_DIR/inventory.ini"
SSH_KEY="$HOME/.ssh/id_rsa"
SSH_PUB_KEY="$HOME/.ssh/id_rsa.pub"

export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-minioadmin}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-minioadmin}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"

echo "=================================================="
echo " KijaniKiosk Full IaC Pipeline"
echo "=================================================="

# --------------------------------------------------
# Phase 1: Prerequisite checks
# --------------------------------------------------
echo
echo "[1/7] Checking prerequisites..."

for cmd in terraform ansible ansible-playbook multipass ssh; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: Required command '$cmd' is not installed."
        exit 1
    fi
done

if [[ ! -f "$SSH_KEY" || ! -f "$SSH_PUB_KEY" ]]; then
    echo "ERROR: SSH key pair not found at $SSH_KEY"
    exit 1
fi

echo "Prerequisites OK."

# --------------------------------------------------
# Phase 2: Terraform
# --------------------------------------------------
echo
echo "[2/7] Running Terraform..."

cd "$TERRAFORM_DIR"

terraform init -input=false
terraform fmt -check -recursive
terraform validate

terraform plan \
    -input=false \
    -out=tfplan

terraform apply \
    -input=false \
    -auto-approve \
    tfplan

rm -f tfplan

echo "Terraform complete."

# --------------------------------------------------
# Phase 3: Discover Multipass IP addresses
# --------------------------------------------------
echo
echo "[3/7] Discovering VM addresses..."

get_ip() {
    local vm="$1"

    multipass info "$vm" 2>/dev/null |
        awk '/IPv4/ {print $2; exit}'
}

API_IP="$(get_ip kijanikiosk-api)"
PAYMENTS_IP="$(get_ip kijanikiosk-payments)"
LOGS_IP="$(get_ip kijanikiosk-logs)"

for value in "$API_IP" "$PAYMENTS_IP" "$LOGS_IP"; do
    if [[ -z "$value" ]]; then
        echo "ERROR: Failed to discover one or more VM IP addresses."
        exit 1
    fi
done

echo "API:      $API_IP"
echo "Payments: $PAYMENTS_IP"
echo "Logs:     $LOGS_IP"

# --------------------------------------------------
# Phase 4: Bootstrap SSH
# --------------------------------------------------
echo
echo "[4/7] Preparing SSH access..."

PUBKEY="$(cat "$SSH_PUB_KEY")"

for vm in kijanikiosk-api kijanikiosk-payments kijanikiosk-logs; do
    echo "Ensuring SSH key exists on $vm..."

    multipass exec "$vm" -- bash -c "
        mkdir -p /home/ubuntu/.ssh
        chmod 700 /home/ubuntu/.ssh
        touch /home/ubuntu/.ssh/authorized_keys
        grep -qxF '$PUBKEY' /home/ubuntu/.ssh/authorized_keys ||
            echo '$PUBKEY' >> /home/ubuntu/.ssh/authorized_keys
        chmod 600 /home/ubuntu/.ssh/authorized_keys
        chown -R ubuntu:ubuntu /home/ubuntu/.ssh
    "
done

# Refresh host keys so recreated VMs do not break the pipeline.
for ip in "$API_IP" "$PAYMENTS_IP" "$LOGS_IP"; do
    ssh-keygen -R "$ip" >/dev/null 2>&1 || true

    ssh-keyscan -H "$ip" >> "$HOME/.ssh/known_hosts" 2>/dev/null
done

# --------------------------------------------------
# Phase 5: Generate Ansible inventory
# --------------------------------------------------
echo
echo "[5/7] Generating Ansible inventory..."

cat > "$INVENTORY" <<INVENTORY_EOF
[api]
kijanikiosk-api ansible_host=$API_IP

[payments]
kijanikiosk-payments ansible_host=$PAYMENTS_IP

[logs]
kijanikiosk-logs ansible_host=$LOGS_IP

[kijanikiosk:children]
api
payments
logs

[kijanikiosk:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=$SSH_KEY
ansible_python_interpreter=/usr/bin/python3
INVENTORY_EOF

cat "$INVENTORY"

# --------------------------------------------------
# Phase 6: Ansible
# --------------------------------------------------
echo
echo "[6/7] Running Ansible..."

cd "$ANSIBLE_DIR"

ansible all \
    -i "$INVENTORY" \
    -m ping

ansible-playbook \
    -i "$INVENTORY" \
    kijanikiosk.yml

# --------------------------------------------------
# Phase 7: Validation
# --------------------------------------------------
echo
echo "[7/7] Validating environment..."

ansible api \
    -i "$INVENTORY" \
    -b \
    -m command \
    -a "systemctl is-active kk-api"

ansible payments \
    -i "$INVENTORY" \
    -b \
    -m command \
    -a "systemctl is-active kk-payments"

ansible logs \
    -i "$INVENTORY" \
    -b \
    -m command \
    -a "systemctl is-active kk-logs"

echo
echo "Checking kk-payments security exposure..."

SECURITY_SCORE="$(
    ansible payments \
        -i "$INVENTORY" \
        -b \
        -m shell \
        -a "systemd-analyze security kk-payments --no-pager | grep 'Overall exposure'" |
        grep -oE '[0-9]+\.[0-9]+' |
        tail -1
)"

echo "kk-payments exposure score: $SECURITY_SCORE"

if awk "BEGIN {exit !($SECURITY_SCORE < 2.5)}"; then
    echo "Security requirement PASSED (< 2.5)."
else
    echo "ERROR: Security exposure requirement FAILED."
    exit 1
fi

echo
echo "Checking final Terraform state..."

cd "$TERRAFORM_DIR"

set +e
terraform plan -input=false -detailed-exitcode
TF_EXIT=$?
set -e

if [[ "$TF_EXIT" -eq 0 ]]; then
    echo "Terraform idempotency check PASSED: no changes."
elif [[ "$TF_EXIT" -eq 2 ]]; then
    echo "ERROR: Terraform detected additional changes."
    exit 1
else
    echo "ERROR: Terraform plan failed."
    exit "$TF_EXIT"
fi

echo
echo "=================================================="
echo " KijaniKiosk pipeline completed successfully"
echo "=================================================="
