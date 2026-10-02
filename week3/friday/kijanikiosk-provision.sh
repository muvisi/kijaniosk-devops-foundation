#!/usr/bin/env bash

set -uo pipefail

# ============================================================
# KijaniKiosk Production Server Foundation
# ============================================================
#
# Idempotent provisioning script for the KijaniKiosk host.
#
# Converges:
#   - service accounts and shared group
#   - directory ownership and permissions
#   - ACL and default ACL configuration
#   - package installation and package hold
#   - UFW firewall configuration
#   - hardened systemd services
#   - service dependency ordering
#   - persistent systemd journal
#   - log rotation
#   - health monitoring
#   - final state verification
#
# Designed to recover from clean, partial and dirty state.
# ============================================================


# ============================================================
# Global Configuration
# ============================================================

BASE="/opt/kijanikiosk"

CONFIG_DIR="$BASE/config"
LOG_DIR="$BASE/shared/logs"
HEALTH_DIR="$BASE/health"

API_DIR="$BASE/api"
PAYMENTS_DIR="$BASE/payments"
LOG_SERVICE_DIR="$BASE/logs"

FAILED=0


# ============================================================
# Helper Functions
# ============================================================

log() {
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}


pass() {
    printf '[PASS] %s\n' "$*"
}


fail() {
    printf '[FAIL] %s\n' "$*" >&2
    FAILED=$((FAILED + 1))
}


phase() {
    echo
    echo "============================================================"
    echo "$1"
    echo "============================================================"
}


# ============================================================
# Root Check
# ============================================================

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Run this script with sudo."
    exit 1
fi


# ============================================================
# PHASE 1: Preflight and Dirty-State Detection
# ============================================================

phase "PHASE 1: Preflight and Dirty-State Detection"

log "Inspecting existing KijaniKiosk state..."


# ------------------------------------------------------------
# Group
# ------------------------------------------------------------

if getent group kijanikiosk >/dev/null; then
    log "Already exists: group kijanikiosk"
else
    log "Missing group: kijanikiosk"
fi


# ------------------------------------------------------------
# Service accounts
# ------------------------------------------------------------

for user in kk-api kk-payments kk-logs; do

    if id "$user" >/dev/null 2>&1; then
        log "Already exists: $user (UID $(id -u "$user"))"
    else
        log "Missing service account: $user"
    fi

done


# ------------------------------------------------------------
# Config directory
# ------------------------------------------------------------

if [[ -d "$CONFIG_DIR" ]]; then

    mode="$(stat -c '%a' "$CONFIG_DIR")"

    log "Existing config directory detected with mode: $mode"

    if [[ "$mode" == "777" ]]; then

        log "Detected insecure config permissions: 777"

    elif [[ "$mode" != "750" ]]; then

        log "Detected unexpected config permissions: $mode"

    else

        log "Config directory permissions already correct"

    fi

else

    log "Config directory missing"

fi


# ------------------------------------------------------------
# Shared log directory and ACLs
# ------------------------------------------------------------

if [[ -d "$LOG_DIR" ]]; then

    log "Existing shared log directory detected"

    for user in kk-api kk-payments kk-logs; do

        if getfacl -cp "$LOG_DIR" 2>/dev/null |
            grep -q "^user:${user}:"; then

            log "Existing ACL detected for $user"

        else

            log "Missing ACL entry detected for $user"

        fi

    done

else

    log "Shared log directory missing"

fi


# ------------------------------------------------------------
# Package hold
# ------------------------------------------------------------

if apt-mark showhold 2>/dev/null |
    grep -qx 'curl'; then

    log "Detected held package: curl"

else

    log "curl is not currently held"

fi


# ------------------------------------------------------------
# Firewall
# ------------------------------------------------------------

if command -v ufw >/dev/null 2>&1 &&
   ufw status |
   grep -q '^Status: active'; then

    log "Detected active UFW configuration"

    if ufw status |
        grep -q '3001.*DENY'; then

        log "Detected stale/existing port 3001 deny rule"

    fi

else

    log "UFW currently inactive or unavailable"

fi


# ------------------------------------------------------------
# systemd units
# ------------------------------------------------------------

for service in kk-api kk-payments kk-logs; do

    if [[ -f "/etc/systemd/system/${service}.service" ]]; then

        log "Existing systemd unit detected: ${service}.service"

    else

        log "Missing systemd unit: ${service}.service"

    fi

done


# ============================================================
# PHASE 2: Service Accounts and Groups
# ============================================================

phase "PHASE 2: Service Accounts and Groups"


# ------------------------------------------------------------
# Shared group
# ------------------------------------------------------------

if getent group kijanikiosk >/dev/null; then

    log "Already exists: group kijanikiosk"

else

    groupadd --system kijanikiosk

    log "Created group: kijanikiosk"

fi


# ------------------------------------------------------------
# Service accounts
# ------------------------------------------------------------

for user in kk-api kk-payments kk-logs; do

    if id "$user" >/dev/null 2>&1; then

        log "Already exists: $user"

    else

        useradd \
            --system \
            --no-create-home \
            --shell /usr/sbin/nologin \
            --gid kijanikiosk \
            "$user"

        log "Created service account: $user"

    fi

done


# ============================================================
# PHASE 3: Directories, Permissions and ACLs
# ============================================================

phase "PHASE 3: Directories, Permissions and ACLs"


mkdir -p \
    "$CONFIG_DIR" \
    "$LOG_DIR" \
    "$HEALTH_DIR" \
    "$API_DIR" \
    "$PAYMENTS_DIR" \
    "$LOG_SERVICE_DIR"


log "Required KijaniKiosk directories exist"


# ------------------------------------------------------------
# Config directory
# ------------------------------------------------------------

chown root:kijanikiosk "$CONFIG_DIR"
chmod 750 "$CONFIG_DIR"

log "Converged config directory to root:kijanikiosk mode 750"


# ------------------------------------------------------------
# Shared logs
# ------------------------------------------------------------

chown root:kijanikiosk "$LOG_DIR"

# SGID causes newly created files/directories to retain the
# kijanikiosk group.
chmod 2770 "$LOG_DIR"


# Remove stale ACL state.
setfacl -b "$LOG_DIR"
setfacl -k "$LOG_DIR" 2>/dev/null || true


# Current ACLs.
setfacl -m u:kk-api:rwx "$LOG_DIR"
setfacl -m u:kk-payments:r-x "$LOG_DIR"
setfacl -m u:kk-logs:r-x "$LOG_DIR"
setfacl -m g:kijanikiosk:r-x "$LOG_DIR"


# Default ACLs inherited by newly created files.
setfacl -d -m u:kk-api:rwx "$LOG_DIR"
setfacl -d -m u:kk-payments:r-x "$LOG_DIR"
setfacl -d -m u:kk-logs:r-x "$LOG_DIR"
setfacl -d -m g:kijanikiosk:r-x "$LOG_DIR"


log "Converged shared log ACL and default ACL"


# ------------------------------------------------------------
# Health directory
# ------------------------------------------------------------

chown kk-logs:kijanikiosk "$HEALTH_DIR"
chmod 750 "$HEALTH_DIR"

log "Configured health directory"


# ============================================================
# PHASE 4: Package and Version State
# ============================================================

phase "PHASE 4: Package and Version State"


required_packages=(
    nginx
    curl
    acl
    logrotate
    ufw
)

apt_updated=0


for pkg in "${required_packages[@]}"; do

    status="$(
        dpkg-query \
            -W \
            -f='${db:Status-Status}' \
            "$pkg" \
            2>/dev/null ||
        true
    )"


    # Ubuntu releases may return simply "installed".
    # Other dpkg implementations/releases may return the
    # traditional full status text.
    if [[ "$status" == "installed" ||
          "$status" == "install ok installed" ||
          "$status" == "hold ok installed" ]]; then

        version="$(
            dpkg-query \
                -W \
                -f='${Version}' \
                "$pkg" \
                2>/dev/null
        )"

        log "Package already installed: $pkg ($version)"

    else

        if [[ "$apt_updated" -eq 0 ]]; then

            log "Refreshing package metadata"

            apt-get update

            apt_updated=1

        fi


        log "Installing missing package: $pkg"


        DEBIAN_FRONTEND=noninteractive \
            apt-get install -y "$pkg"

    fi

done


# ------------------------------------------------------------
# Package hold
# ------------------------------------------------------------

if apt-mark showhold |
    grep -qx 'curl'; then

    log "Existing package hold retained: curl"

else

    apt-mark hold curl

    log "Applied package hold: curl"

fi


log "Installed nginx version: $(dpkg-query -W -f='${Version}' nginx)"
log "Installed curl version: $(dpkg-query -W -f='${Version}' curl)"


# ============================================================
# PHASE 5: Firewall Configuration
# ============================================================

phase "PHASE 5: Firewall Configuration"


log "Resetting UFW to known baseline"


ufw --force reset


ufw default deny incoming
ufw default allow outgoing


# ------------------------------------------------------------
# SSH
# ------------------------------------------------------------

ufw allow 22/tcp \
    comment 'Allow administrative SSH'


# ------------------------------------------------------------
# Public HTTP
# ------------------------------------------------------------

ufw allow 80/tcp \
    comment 'Allow public HTTP'


# ------------------------------------------------------------
# Monitoring subnet access
# ------------------------------------------------------------

ufw allow from 10.0.1.0/24 \
    to any port 3001 \
    proto tcp \
    comment 'Allow payments health checks from monitoring subnet'


# ------------------------------------------------------------
# Loopback access
# ------------------------------------------------------------

ufw allow in on lo \
    to any port 3001 \
    proto tcp \
    comment 'Allow loopback access to payments'


# ------------------------------------------------------------
# External payments access denied
# ------------------------------------------------------------

ufw deny 3001/tcp \
    comment 'Deny external access to internal payments service'


ufw --force enable


log "UFW converged to intended production rules"


# ============================================================
# PHASE 6: systemd Service Units and Hardening
# ============================================================

phase "PHASE 6: systemd Service Units and Hardening"


# ------------------------------------------------------------
# Environment files
# ------------------------------------------------------------

log "Creating environment files"


cat > "$CONFIG_DIR/api.env" <<'EOF'
PORT=3000
SERVICE_NAME=kk-api
EOF


cat > "$CONFIG_DIR/payments-api.env" <<'EOF'
PORT=3001
SERVICE_NAME=kk-payments
EOF


cat > "$CONFIG_DIR/logs.env" <<'EOF'
SERVICE_NAME=kk-logs
EOF


chown root:kijanikiosk \
    "$CONFIG_DIR/api.env" \
    "$CONFIG_DIR/payments-api.env" \
    "$CONFIG_DIR/logs.env"


chmod 640 \
    "$CONFIG_DIR/api.env" \
    "$CONFIG_DIR/payments-api.env" \
    "$CONFIG_DIR/logs.env"


log "Environment files created with mode 640"


# ------------------------------------------------------------
# API placeholder application
# ------------------------------------------------------------

cat > "$API_DIR/server.py" <<'PYEOF'
import http.server
import os
import socketserver

PORT = int(os.environ.get("PORT", "3000"))


class ReusableTCPServer(socketserver.TCPServer):
    allow_reuse_address = True


class Handler(http.server.BaseHTTPRequestHandler):

    def do_GET(self):
        body = b'{"service":"kk-api","status":"ok"}\n'

        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()

        self.wfile.write(body)

    def log_message(self, fmt, *args):
        pass


with ReusableTCPServer(
    ("127.0.0.1", PORT),
    Handler
) as server:
    server.serve_forever()
PYEOF


chown -R kk-api:kijanikiosk "$API_DIR"
chmod 750 "$API_DIR"
chmod 640 "$API_DIR/server.py"


# ------------------------------------------------------------
# Payments placeholder application
# ------------------------------------------------------------

cat > "$PAYMENTS_DIR/server.py" <<'PYEOF'
import http.server
import os
import socketserver

PORT = int(os.environ.get("PORT", "3001"))


class ReusableTCPServer(socketserver.TCPServer):
    allow_reuse_address = True


class Handler(http.server.BaseHTTPRequestHandler):

    def do_GET(self):
        body = b'{"service":"kk-payments","status":"ok"}\n'

        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()

        self.wfile.write(body)

    def log_message(self, fmt, *args):
        pass


with ReusableTCPServer(
    ("127.0.0.1", PORT),
    Handler
) as server:
    server.serve_forever()
PYEOF


chown -R kk-payments:kijanikiosk "$PAYMENTS_DIR"
chmod 750 "$PAYMENTS_DIR"
chmod 640 "$PAYMENTS_DIR/server.py"


# ------------------------------------------------------------
# Logs placeholder application
# ------------------------------------------------------------

cat > "$LOG_SERVICE_DIR/logger.py" <<'PYEOF'
import signal
import time

running = True


def stop_service(signum, frame):
    global running
    running = False


signal.signal(signal.SIGTERM, stop_service)
signal.signal(signal.SIGINT, stop_service)


while running:
    time.sleep(5)
PYEOF


chown -R kk-logs:kijanikiosk "$LOG_SERVICE_DIR"
chmod 750 "$LOG_SERVICE_DIR"
chmod 640 "$LOG_SERVICE_DIR/logger.py"


# ------------------------------------------------------------
# Verify EnvironmentFile readability
# ------------------------------------------------------------

for pair in \
    "kk-api:$CONFIG_DIR/api.env" \
    "kk-payments:$CONFIG_DIR/payments-api.env" \
    "kk-logs:$CONFIG_DIR/logs.env"
do

    user="${pair%%:*}"
    envfile="${pair#*:}"


    if runuser -u "$user" -- \
        cat "$envfile" >/dev/null; then

        pass "$user can read its EnvironmentFile"

    else

        fail "$user cannot read $envfile"

    fi

done


# ------------------------------------------------------------
# kk-api.service
# ------------------------------------------------------------

cat > /etc/systemd/system/kk-api.service <<EOF
[Unit]
Description=KijaniKiosk API Service
After=network.target

[Service]
Type=simple

User=kk-api
Group=kijanikiosk

EnvironmentFile=$CONFIG_DIR/api.env

ExecStart=/usr/bin/python3 $API_DIR/server.py

Restart=on-failure
RestartSec=5

NoNewPrivileges=true

PrivateTmp=true
PrivateDevices=true

ProtectSystem=strict
ProtectHome=true

ProtectKernelTunables=true
ProtectKernelModules=true
ProtectKernelLogs=true

ProtectControlGroups=true

ProtectClock=true
ProtectHostname=true

RestrictSUIDSGID=true
RestrictRealtime=true
RestrictNamespaces=true

LockPersonality=true

MemoryDenyWriteExecute=true

CapabilityBoundingSet=
AmbientCapabilities=

SystemCallArchitectures=native

RestrictAddressFamilies=AF_INET AF_INET6

UMask=0027

[Install]
WantedBy=multi-user.target
EOF


# ------------------------------------------------------------
# kk-payments.service
#
# Payments receives stronger systemd hardening.
#
# Baseline systemd-analyze exposure:
#     2.8
#
# Tested hardened exposure:
#     1.4
#
# Requirement:
#     < 2.5
#
# PrivateNetwork=true is intentionally rejected because the
# service must remain reachable through host loopback on
# 127.0.0.1:3001.
#
# AF_INET is intentionally retained because the service uses
# an IPv4 TCP listener.
# ------------------------------------------------------------

cat > /etc/systemd/system/kk-payments.service <<EOF
[Unit]
Description=KijaniKiosk Payments Service

After=network.target kk-api.service
Wants=kk-api.service

[Service]
Type=simple

User=kk-payments
Group=kijanikiosk

EnvironmentFile=$CONFIG_DIR/payments-api.env

ExecStart=/usr/bin/python3 $PAYMENTS_DIR/server.py

Restart=on-failure
RestartSec=5

NoNewPrivileges=true

PrivateTmp=true
PrivateDevices=true

ProtectSystem=strict
ProtectHome=true

ProtectKernelTunables=true
ProtectKernelModules=true
ProtectKernelLogs=true

ProtectControlGroups=true

ProtectClock=true
ProtectHostname=true

ProtectProc=invisible
ProcSubset=pid

RestrictSUIDSGID=true
RestrictRealtime=true
RestrictNamespaces=true

LockPersonality=true

MemoryDenyWriteExecute=true

CapabilityBoundingSet=
AmbientCapabilities=

SystemCallArchitectures=native

SystemCallFilter=~@clock @cpu-emulation @debug @module @mount @obsolete @privileged @raw-io @reboot @swap

RestrictAddressFamilies=AF_INET AF_INET6

RemoveIPC=true

UMask=0077

[Install]
WantedBy=multi-user.target
EOF


# ------------------------------------------------------------
# kk-logs.service
# ------------------------------------------------------------

cat > /etc/systemd/system/kk-logs.service <<EOF
[Unit]
Description=KijaniKiosk Log Monitoring Service
After=network.target

[Service]
Type=simple

User=kk-logs
Group=kijanikiosk

EnvironmentFile=$CONFIG_DIR/logs.env

ExecStart=/usr/bin/python3 $LOG_SERVICE_DIR/logger.py

Restart=on-failure
RestartSec=5

NoNewPrivileges=true

PrivateTmp=true
PrivateDevices=true

ProtectSystem=strict
ProtectHome=true

ProtectKernelTunables=true
ProtectKernelModules=true
ProtectKernelLogs=true

ProtectControlGroups=true

ProtectClock=true
ProtectHostname=true

RestrictSUIDSGID=true
RestrictRealtime=true
RestrictNamespaces=true

LockPersonality=true

MemoryDenyWriteExecute=true

CapabilityBoundingSet=
AmbientCapabilities=

SystemCallArchitectures=native

RestrictAddressFamilies=AF_UNIX

UMask=0027

[Install]
WantedBy=multi-user.target
EOF


# ------------------------------------------------------------
# Remove temporary experimental payments override.
#
# Hardening now lives directly in the generated unit.
# ------------------------------------------------------------

if [[ -f \
    /etc/systemd/system/kk-payments.service.d/override.conf ]]; then

    rm -f \
        /etc/systemd/system/kk-payments.service.d/override.conf

    rmdir \
        /etc/systemd/system/kk-payments.service.d \
        2>/dev/null || true

    log "Removed obsolete kk-payments experimental override"

fi


# ------------------------------------------------------------
# Reload and start services
# ------------------------------------------------------------

systemctl daemon-reload


systemctl enable kk-api.service
systemctl enable kk-payments.service
systemctl enable kk-logs.service


systemctl restart kk-api.service
systemctl restart kk-payments.service
systemctl restart kk-logs.service


sleep 2


for service in kk-api kk-payments kk-logs; do

    if systemctl is-active --quiet "$service.service"; then

        pass "$service is running"

    else

        fail "$service failed to start"

        journalctl \
            -u "$service.service" \
            -n 20 \
            --no-pager

    fi

done


# ============================================================
# PHASE 7: Journal Persistence and Log Rotation
# ============================================================

phase "PHASE 7: Journal Persistence and Log Rotation"


# ------------------------------------------------------------
# Persistent journal
# ------------------------------------------------------------

log "Configuring persistent journal storage"


mkdir -p /var/log/journal

mkdir -p /etc/systemd/journald.conf.d


cat > /etc/systemd/journald.conf.d/kijanikiosk.conf <<'EOF'
[Journal]
Storage=persistent
SystemMaxUse=500M
EOF


systemctl restart systemd-journald


if [[ -d /var/log/journal ]]; then

    pass "Persistent journal directory exists"

else

    fail "Persistent journal directory missing"

fi


if [[ -f \
    /etc/systemd/journald.conf.d/kijanikiosk.conf ]] &&
   grep -q '^Storage=persistent' \
       /etc/systemd/journald.conf.d/kijanikiosk.conf &&
   grep -q '^SystemMaxUse=500M' \
       /etc/systemd/journald.conf.d/kijanikiosk.conf; then

    pass "Persistent journal configured with 500MB cap"

else

    fail "Journal persistence/cap configuration incorrect"

fi


# ------------------------------------------------------------
# Service log files
# ------------------------------------------------------------

touch "$LOG_DIR/kk-api.log"
touch "$LOG_DIR/kk-payments.log"
touch "$LOG_DIR/kk-logs.log"


chown kk-api:kijanikiosk \
    "$LOG_DIR/kk-api.log" \
    "$LOG_DIR/kk-payments.log" \
    "$LOG_DIR/kk-logs.log"


chmod 660 \
    "$LOG_DIR/kk-api.log" \
    "$LOG_DIR/kk-payments.log" \
    "$LOG_DIR/kk-logs.log"


# ------------------------------------------------------------
# Logrotate
#
# The parent directory is group writable by design.
# Therefore logrotate needs an explicit su directive.
# ------------------------------------------------------------

cat > /etc/logrotate.d/kijanikiosk <<EOF
$LOG_DIR/kk-api.log
$LOG_DIR/kk-payments.log
$LOG_DIR/kk-logs.log {
    su kk-api kijanikiosk
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0660 kk-api kijanikiosk
}
EOF


log "Created KijaniKiosk logrotate configuration"


if logrotate --debug \
    /etc/logrotate.d/kijanikiosk \
    >/tmp/kijanikiosk-logrotate-debug.txt \
    2>&1; then

    pass "logrotate --debug passed"

else

    fail "logrotate --debug failed"

    cat /tmp/kijanikiosk-logrotate-debug.txt

fi


# ============================================================
# PHASE 8: Monitoring Health Checks and Final Verification
# ============================================================

phase "PHASE 8: Monitoring Health Checks and Final Verification"


# ------------------------------------------------------------
# API status
# ------------------------------------------------------------

if timeout 2 \
    bash -c "echo >/dev/tcp/127.0.0.1/3000" \
    2>/dev/null; then

    api_status='"ok"'

else

    api_status='"down"'

fi


# ------------------------------------------------------------
# Payments status
# ------------------------------------------------------------

if timeout 2 \
    bash -c "echo >/dev/tcp/127.0.0.1/3001" \
    2>/dev/null; then

    payments_status='"ok"'

else

    payments_status='"down"'

fi


# ------------------------------------------------------------
# Health JSON
# ------------------------------------------------------------

printf \
    '{"timestamp":"%s","kk-api":%s,"kk-payments":%s}\n' \
    "$(date -Is)" \
    "$api_status" \
    "$payments_status" \
    > "$HEALTH_DIR/last-provision.json"


chown kk-logs:kijanikiosk \
    "$HEALTH_DIR/last-provision.json"


chmod 640 \
    "$HEALTH_DIR/last-provision.json"


log "Health check results written to $HEALTH_DIR/last-provision.json"


cat "$HEALTH_DIR/last-provision.json"


# ============================================================
# FINAL VERIFICATION
# ============================================================

echo
echo "============================================================"
echo "FINAL VERIFICATION"
echo "============================================================"


# ------------------------------------------------------------
# Users
# ------------------------------------------------------------

for user in kk-api kk-payments kk-logs; do

    if id "$user" >/dev/null 2>&1; then

        pass "Service account exists: $user"

    else

        fail "Service account missing: $user"

    fi

done


# ------------------------------------------------------------
# Group
# ------------------------------------------------------------

if getent group kijanikiosk >/dev/null; then

    pass "Group exists: kijanikiosk"

else

    fail "Group missing: kijanikiosk"

fi


# ------------------------------------------------------------
# Config permissions
# ------------------------------------------------------------

config_mode="$(stat -c '%a' "$CONFIG_DIR")"


if [[ "$config_mode" == "750" ]]; then

    pass "Config directory mode is 750"

else

    fail "Config directory mode is $config_mode, expected 750"

fi


# ------------------------------------------------------------
# Environment file access
# ------------------------------------------------------------

for pair in \
    "kk-api:$CONFIG_DIR/api.env" \
    "kk-payments:$CONFIG_DIR/payments-api.env" \
    "kk-logs:$CONFIG_DIR/logs.env"
do

    user="${pair%%:*}"
    envfile="${pair#*:}"


    if runuser -u "$user" -- \
        cat "$envfile" >/dev/null; then

        pass "$user can read $(basename "$envfile")"

    else

        fail "$user cannot read $(basename "$envfile")"

    fi

done


# ------------------------------------------------------------
# ACL verification
# ------------------------------------------------------------

acl_output="$(
    getfacl -cp "$LOG_DIR" 2>/dev/null
)"


if echo "$acl_output" |
    grep -q '^user:kk-api:rwx$'; then

    pass "kk-api ACL exists"

else

    fail "kk-api ACL missing"

fi


if echo "$acl_output" |
    grep -q '^user:kk-payments:r-x$'; then

    pass "kk-payments ACL exists"

else

    fail "kk-payments ACL missing"

fi


if echo "$acl_output" |
    grep -q '^user:kk-logs:r-x$'; then

    pass "kk-logs ACL exists"

else

    fail "kk-logs ACL missing"

fi


if echo "$acl_output" |
    grep -q '^default:user:kk-api:rwx$'; then

    pass "Default kk-api ACL exists"

else

    fail "Default kk-api ACL missing"

fi


if echo "$acl_output" |
    grep -q '^default:user:kk-payments:r-x$'; then

    pass "Default kk-payments ACL exists"

else

    fail "Default kk-payments ACL missing"

fi


if echo "$acl_output" |
    grep -q '^default:user:kk-logs:r-x$'; then

    pass "Default kk-logs ACL exists"

else

    fail "Default kk-logs ACL missing"

fi


# ------------------------------------------------------------
# Service status
# ------------------------------------------------------------

for service in kk-api kk-payments kk-logs; do

    if systemctl is-active --quiet "$service.service"; then

        pass "$service service is active"

    else

        fail "$service service is not active"

    fi

done


# ------------------------------------------------------------
# Payments dependency
# ------------------------------------------------------------

if grep -q '^After=.*kk-api.service' \
    /etc/systemd/system/kk-payments.service; then

    pass "kk-payments declares After=kk-api.service"

else

    fail "kk-payments missing After dependency"

fi


if grep -q '^Wants=kk-api.service' \
    /etc/systemd/system/kk-payments.service; then

    pass "kk-payments declares Wants=kk-api.service"

else

    fail "kk-payments missing Wants dependency"

fi


# ------------------------------------------------------------
# Payments syscall hardening
# ------------------------------------------------------------

if grep -q '^SystemCallFilter=~@clock' \
    /etc/systemd/system/kk-payments.service; then

    pass "kk-payments syscall hardening configured"

else

    fail "kk-payments syscall hardening missing"

fi


# ------------------------------------------------------------
# Port checks
# ------------------------------------------------------------

if timeout 2 \
    bash -c "echo >/dev/tcp/127.0.0.1/3000" \
    2>/dev/null; then

    pass "kk-api port 3000 is listening"

else

    fail "kk-api port 3000 is not listening"

fi


if timeout 2 \
    bash -c "echo >/dev/tcp/127.0.0.1/3001" \
    2>/dev/null; then

    pass "kk-payments port 3001 is listening"

else

    fail "kk-payments port 3001 is not listening"

fi


# ------------------------------------------------------------
# HTTP functional checks
# ------------------------------------------------------------

api_response="$(
    curl \
        -fsS \
        --max-time 3 \
        http://127.0.0.1:3000/ \
        2>/dev/null ||
    true
)"


if echo "$api_response" |
    grep -q '"status":"ok"'; then

    pass "kk-api HTTP health check passed"

else

    fail "kk-api HTTP health check failed"

fi


payments_response="$(
    curl \
        -fsS \
        --max-time 3 \
        http://127.0.0.1:3001/ \
        2>/dev/null ||
    true
)"


if echo "$payments_response" |
    grep -q '"status":"ok"'; then

    pass "kk-payments HTTP health check passed"

else

    fail "kk-payments HTTP health check failed"

fi


# ------------------------------------------------------------
# Health JSON
# ------------------------------------------------------------

if [[ -s "$HEALTH_DIR/last-provision.json" ]]; then

    pass "Health JSON exists"

else

    fail "Health JSON missing"

fi


if runuser -u kk-logs -- \
    cat "$HEALTH_DIR/last-provision.json" \
    >/dev/null; then

    pass "kk-logs can read health JSON"

else

    fail "kk-logs cannot read health JSON"

fi


# ------------------------------------------------------------
# Persistent journal
# ------------------------------------------------------------

if [[ -d /var/log/journal ]]; then

    pass "Persistent journal storage exists"

else

    fail "Persistent journal storage missing"

fi


if [[ -f \
    /etc/systemd/journald.conf.d/kijanikiosk.conf ]] &&
   grep -q '^Storage=persistent' \
       /etc/systemd/journald.conf.d/kijanikiosk.conf &&
   grep -q '^SystemMaxUse=500M' \
       /etc/systemd/journald.conf.d/kijanikiosk.conf; then

    pass "Journal persistence and 500MB cap verified"

else

    fail "Journal persistence/limit verification failed"

fi


# ------------------------------------------------------------
# Logrotate
# ------------------------------------------------------------

if logrotate --debug \
    /etc/logrotate.d/kijanikiosk \
    >/dev/null \
    2>&1; then

    pass "logrotate configuration validates"

else

    fail "logrotate configuration validation failed"

fi


# ------------------------------------------------------------
# Firewall
# ------------------------------------------------------------

firewall_status="$(ufw status)"


if echo "$firewall_status" |
    grep -q '22/tcp.*ALLOW'; then

    pass "SSH (22) allowed"

else

    fail "SSH firewall rule missing"

fi


if echo "$firewall_status" |
    grep -q '80/tcp.*ALLOW'; then

    pass "HTTP (80) allowed"

else

    fail "HTTP firewall rule missing"

fi


if echo "$firewall_status" |
    grep -q '3001/tcp.*10.0.1.0/24'; then

    pass "Monitoring subnet rule exists for port 3001"

else

    fail "Monitoring subnet rule missing for port 3001"

fi


if echo "$firewall_status" |
    grep -q '3001/tcp.*DENY'; then

    pass "External port 3001 deny exists"

else

    fail "External port 3001 deny missing"

fi


# ------------------------------------------------------------
# curl hold
# ------------------------------------------------------------

if apt-mark showhold |
    grep -qx 'curl'; then

    pass "curl package hold exists"

else

    fail "curl package hold missing"

fi


# ============================================================
# FINAL RESULT
# ============================================================

echo
echo "============================================================"


if [[ "$FAILED" -eq 0 ]]; then

    echo "PROVISIONING RESULT: PASS"
    echo "All verification checks passed."

    echo "============================================================"

    exit 0

else

    echo "PROVISIONING RESULT: FAIL"
    echo "$FAILED verification check(s) failed."

    echo "============================================================"

    exit 1

fi
