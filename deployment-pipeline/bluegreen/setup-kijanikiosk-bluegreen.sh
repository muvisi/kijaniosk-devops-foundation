#!/usr/bin/env bash
set -Eeuo pipefail
# Local Ubuntu lab setup. Run as ordinary user with sudo access.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${1:-$HOME/workspace/moringa/kijaniosk-devops-foundation}"
APP="$REPO/week8/kk-payments"
BASE=/opt/kijanikiosk
PORT=8088
if [[ ! -f "$APP/package.json" || ! -f "$APP/tsconfig.json" ]]; then echo "Missing application source: $APP" >&2; exit 1; fi
for p in 3100 3101 8088; do
  if sudo ss -ltnH "( sport = :$p )" | grep -q .; then echo "Port $p is occupied; aborting before changes" >&2; exit 1; fi
done
if sudo test -e "$BASE/.active-env" || sudo test -e /etc/nginx/conf.d/kijanikiosk-bluegreen.conf; then echo "Existing blue/green configuration found; refusing overwrite" >&2; exit 1; fi
command -v node >/dev/null || { echo 'Install Node.js before continuing'; exit 1; }
command -v npm >/dev/null || { echo 'Install npm before continuing'; exit 1; }
command -v nginx >/dev/null || { echo 'Install nginx before continuing'; exit 1; }
node -e 'const p=require(process.argv[1]); console.log("App version:",p.version)' "$APP/package.json"
(cd "$APP" && npm ci && npm run build)
[[ -f "$APP/dist/index.js" ]] || { echo 'Expected dist/index.js missing'; exit 1; }
sudo install -d -m 755 "$BASE" "$BASE/scripts" "$BASE/blue" "$BASE/green" /etc/nginx/kijanikiosk
# Install Node.js outside /home so systemd ProtectHome=true works.
sudo install -d -m 755 "$BASE/runtime"
sudo install -m 755 "$(command -v node)" "$BASE/runtime/node"
"$BASE/runtime/node" --version

if ! id kijani >/dev/null 2>&1; then sudo useradd --system --home-dir "$BASE" --shell /usr/sbin/nologin kijani; fi
for env in blue green; do
 sudo cp -a "$APP/dist" "$BASE/$env/"
 sudo cp "$APP/package.json" "$BASE/$env/package.json"
 sudo chown -R kijani:kijani "$BASE/$env"
done
# Fail safely if runtime dependencies are required: copied app is dependency-free in this assignment.
if node -e 'const p=require(process.argv[1]);process.exit(Object.keys(p.dependencies||{}).length?1:0)' "$APP/package.json"; then :; else
  echo 'Runtime dependencies detected; install them separately in both release directories before starting.' >&2
  exit 1
fi
sudo tee /etc/systemd/system/kk-api-blue.service >/dev/null <<'UNIT'
[Unit]
Description=KijaniKiosk blue payments API
After=network.target
[Service]
Type=simple
User=kijani
Group=kijani
WorkingDirectory=/opt/kijanikiosk/blue
Environment=NODE_ENV=production
Environment=PORT=3100
Environment=APP_VERSION=v1.3.0
ExecStart=/opt/kijanikiosk/runtime/node /opt/kijanikiosk/blue/dist/index.js
Restart=on-failure
RestartSec=2
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
ReadWritePaths=/opt/kijanikiosk/blue
[Install]
WantedBy=multi-user.target
UNIT
sudo tee /etc/systemd/system/kk-api-green.service >/dev/null <<'UNIT'
[Unit]
Description=KijaniKiosk green payments API
After=network.target
[Service]
Type=simple
User=kijani
Group=kijani
WorkingDirectory=/opt/kijanikiosk/green
Environment=NODE_ENV=production
Environment=PORT=3101
Environment=APP_VERSION=v1.4.0
ExecStart=/opt/kijanikiosk/runtime/node /opt/kijanikiosk/green/dist/index.js
Restart=on-failure
RestartSec=2
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
ReadWritePaths=/opt/kijanikiosk/green
[Install]
WantedBy=multi-user.target
UNIT
sudo tee /etc/nginx/kijanikiosk/blue.conf >/dev/null <<'CONF'
upstream kijanikiosk_active { server 127.0.0.1:3100; }
CONF
sudo tee /etc/nginx/kijanikiosk/green.conf >/dev/null <<'CONF'
upstream kijanikiosk_active { server 127.0.0.1:3101; }
CONF
sudo ln -s /etc/nginx/kijanikiosk/blue.conf /etc/nginx/kijanikiosk-active-env.conf
sudo tee /etc/nginx/conf.d/kijanikiosk-bluegreen.conf >/dev/null <<'CONF'
include /etc/nginx/kijanikiosk-active-env.conf;
server {
    listen 127.0.0.1:8088;
    server_name localhost;
    location / {
        proxy_pass http://kijanikiosk_active;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_connect_timeout 2s;
        proxy_read_timeout 5s;
    }
}
CONF
printf 'blue\n' | sudo tee "$BASE/.active-env" >/dev/null
printf 'green\n' | sudo tee "$BASE/.previous-env" >/dev/null
sudo chown root:root "$BASE/.active-env" "$BASE/.previous-env"
sudo chmod 644 "$BASE/.active-env" "$BASE/.previous-env"
sudo systemctl daemon-reload
sudo systemctl enable --now kk-api-blue.service kk-api-green.service
sudo nginx -t
sudo systemctl reload nginx || sudo systemctl start nginx
sudo cp "$ROOT/switch-env.sh" "$ROOT/rollback.sh" "$ROOT/post-deploy-monitor.sh" "$BASE/scripts/"
sudo chmod 755 "$BASE/scripts/"*.sh
for pair in '3100 v1.3.0' '3101 v1.4.0'; do read -r p version <<< "$pair"; data=$(curl -fsS --max-time 3 "http://127.0.0.1:$p/health"); echo "$data"; echo "$data" | grep -Fq '"version":"'"$version"'"' || { echo "Version mismatch on $p: expected $version" >&2; exit 1; }; done
curl -fsS --max-time 3 http://127.0.0.1:8088/health; echo
printf '\nSETUP COMPLETE. Initial blue state confirmed.\n'
