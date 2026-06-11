#!/usr/bin/env bash
set -euo pipefail

DESKTOP_DIR="$(xdg-user-dir DESKTOP 2>/dev/null || true)"
[ -n "$DESKTOP_DIR" ] || DESKTOP_DIR="$HOME/Desktop"
mkdir -p "$DESKTOP_DIR" 2>/dev/null || true
[ -d "$DESKTOP_DIR" ] && [ -w "$DESKTOP_DIR" ] || DESKTOP_DIR="$HOME"
OUT="$DESKTOP_DIR/spark_f153_fix_proxy_env_$(date +%Y%m%d_%H%M%S).txt"
exec > >(tee "$OUT") 2>&1

PROXY_HOST="${PROXY_HOST:-}"
PROXY_PORT="${PROXY_PORT:-}"
PROXY_URL="${PROXY_URL:-}"
PROXY_ENV_DIR="$HOME/.config/environment.d"
PROXY_ENV_FILE="$PROXY_ENV_DIR/90-proxy.conf"
OPENCLAW_PROXY_DIR="$HOME/.config/openclaw"
OPENCLAW_PROXY_FILE="$OPENCLAW_PROXY_DIR/proxy.env"
SHELL_PROXY_FILE="$HOME/.proxy.env"

run() {
  echo
  echo "===== $1 ====="
  shift
  echo "+ $*"
  bash -lc "$*" || true
}

detect_proxy() {
  if [ -n "$PROXY_URL" ]; then
    return 0
  fi

  local mode host port
  mode="$(gsettings get org.gnome.system.proxy mode 2>/dev/null | tr -d "'" || true)"
  host="$(gsettings get org.gnome.system.proxy.http host 2>/dev/null | tr -d "'" || true)"
  port="$(gsettings get org.gnome.system.proxy.http port 2>/dev/null | tr -d "'" || true)"

  if [ "$mode" = "manual" ] && [ -n "$host" ] && [ -n "$port" ] && [ "$port" != "0" ]; then
    PROXY_HOST="$host"
    PROXY_PORT="$port"
    PROXY_URL="http://$host:$port"
    return 0
  fi

  for candidate in 7897 7890 20171 20170; do
    if ss -lnt "( sport = :$candidate )" 2>/dev/null | grep -q LISTEN; then
      PROXY_HOST="127.0.0.1"
      PROXY_PORT="$candidate"
      PROXY_URL="http://127.0.0.1:$candidate"
      return 0
    fi
  done

  return 1
}

echo "===== summary ====="
echo "report_file=$OUT"
echo "generated_at=$(date -Is)"
echo "hostname=$(hostname)"
echo "current_user=$(id -un)"

run precheck "id; echo; command -v gsettings || true; command -v systemctl || true; command -v curl || true; command -v ss || true"
run proxy_processes "ps -ef | egrep -i 'clash|mihomo|sing-box|v2ray|xray|clash-verge' | grep -v grep || true"

echo
echo "===== detect_proxy ====="
if detect_proxy; then
  echo "proxy_url=$PROXY_URL"
else
  echo "proxy_detect=failed" >&2
  exit 1
fi

mkdir -p "$PROXY_ENV_DIR" "$OPENCLAW_PROXY_DIR"

cat >"$PROXY_ENV_FILE" <<EOF
HTTP_PROXY=$PROXY_URL
HTTPS_PROXY=$PROXY_URL
ALL_PROXY=$PROXY_URL
http_proxy=$PROXY_URL
https_proxy=$PROXY_URL
all_proxy=$PROXY_URL
NO_PROXY=localhost,127.0.0.1,::1
no_proxy=localhost,127.0.0.1,::1
EOF

cp "$PROXY_ENV_FILE" "$OPENCLAW_PROXY_FILE"
cp "$PROXY_ENV_FILE" "$SHELL_PROXY_FILE"
chmod 600 "$OPENCLAW_PROXY_FILE" "$SHELL_PROXY_FILE"

if ! grep -Fq 'source "$HOME/.proxy.env"' "$HOME/.bashrc" 2>/dev/null; then
  printf '\n[ -f "$HOME/.proxy.env" ] && source "$HOME/.proxy.env"\n' >> "$HOME/.bashrc"
fi
if ! grep -Fq 'source "$HOME/.proxy.env"' "$HOME/.profile" 2>/dev/null; then
  printf '\n[ -f "$HOME/.proxy.env" ] && source "$HOME/.proxy.env"\n' >> "$HOME/.profile"
fi

set -a
source "$SHELL_PROXY_FILE"
set +a
systemctl --user import-environment HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY http_proxy https_proxy all_proxy no_proxy

run verify_env "echo 'shell:'; env | grep -i 'proxy' | sort; echo; echo 'systemd-user:'; systemctl --user show-environment | grep -i 'proxy' | sort"
run verify_files "ls -l $PROXY_ENV_FILE $OPENCLAW_PROXY_FILE $SHELL_PROXY_FILE; echo; cat $PROXY_ENV_FILE"
run connectivity "for u in https://api.github.com https://ollama.com/download/ollama-linux-arm64.tar.zst https://github.com/ollama/ollama/releases/download/v0.18.0/ollama-linux-arm64.tar.zst; do echo; echo URL=\$u; curl -I -L --connect-timeout 8 --max-time 20 -o /dev/null -sS -w 'http=%{http_code} remote_ip=%{remote_ip} time=%{time_total}\\n' \"\$u\" || echo curl_failed; done"

echo
echo "===== done ====="
echo "saved_to=$OUT"
