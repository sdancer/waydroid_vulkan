#!/usr/bin/env bash
set -euo pipefail

# Headless Waydroid over sway + wayvnc (with auth).
# Usage:
#   ./start-waydroid-vnc.sh start [width] [height] [port]   # infra + waydroid
#   ./start-waydroid-vnc.sh stop                            # infra + waydroid
#   ./start-waydroid-vnc.sh start-infra                     # sway + wayvnc only
#   ./start-waydroid-vnc.sh stop-infra                      # sway + wayvnc only
#   ./start-waydroid-vnc.sh start-waydroid                  # waydroid only
#   ./start-waydroid-vnc.sh stop-waydroid                   # waydroid only
#   ./start-waydroid-vnc.sh restart-waydroid                # waydroid only
#   ./start-waydroid-vnc.sh show-ui                         # trigger waydroid full UI
#   ./start-waydroid-vnc.sh status
#
# Optional env vars:
#   VNC_USERNAME (default: waydroid)
#   VNC_PASSWORD (default: waydroid)
#   VNC_OUTPUT   (default: HEADLESS-1)

ACTION="${1:-start}"
WIDTH="${2:-1920}"
HEIGHT="${3:-1080}"
PORT="${4:-5900}"

SOCKET_NAME="wayland-0"
XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
RUNTIME_DIR="${XDG_RUNTIME_DIR}/waydroid-vnc"

SWAY_LOG="/tmp/sway-headless.log"
WAYVNC_LOG="/tmp/wayvnc.log"
WAYDROID_LOG="/tmp/waydroid-session.log"
WAYDROID_UI_LOG="/tmp/waydroid-show-ui.log"

SWAY_PID_FILE="${RUNTIME_DIR}/sway.pid"
WAYVNC_PID_FILE="${RUNTIME_DIR}/wayvnc.pid"
WAYDROID_PID_FILE="${RUNTIME_DIR}/waydroid-session.pid"
SWAYSOCK_FILE="${RUNTIME_DIR}/swaysock"
WAYVNC_CONF="${RUNTIME_DIR}/wayvnc.conf"

TLS_CERT="${RUNTIME_DIR}/tls.crt"
TLS_KEY="${RUNTIME_DIR}/tls.key"
RSA_KEY="${RUNTIME_DIR}/rsa_key.pem"

VNC_USERNAME="${VNC_USERNAME:-waydroid}"
VNC_PASSWORD="${VNC_PASSWORD:-waydroid}"
VNC_OUTPUT="${VNC_OUTPUT:-HEADLESS-1}"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

cleanup_stale() {
  rm -f \
    "${XDG_RUNTIME_DIR}/${SOCKET_NAME}" \
    "${XDG_RUNTIME_DIR}/${SOCKET_NAME}.lock" \
    "${XDG_RUNTIME_DIR}/wayland-0" \
    "${XDG_RUNTIME_DIR}/wayland-0.lock" || true
}

stop_wayland0_owners() {
  local sock="${XDG_RUNTIME_DIR}/wayland-0"
  local pids=""

  # Best effort: stop Waydroid first so hwcomposer releases the socket.
  waydroid session stop >/dev/null 2>&1 || true

  if [ -S "$sock" ]; then
    if command -v fuser >/dev/null 2>&1; then
      pids="$(fuser "$sock" 2>/dev/null | tr ' ' '\n' | grep -E '^[0-9]+$' | sort -u || true)"
    elif command -v lsof >/dev/null 2>&1; then
      pids="$(lsof -t "$sock" 2>/dev/null | sort -u || true)"
    fi
  fi

  if [ -n "$pids" ]; then
    echo "Stopping existing wayland-0 owners: $pids"
    # shellcheck disable=SC2086
    kill $pids >/dev/null 2>&1 || true
    sleep 1
    # shellcheck disable=SC2086
    kill -9 $pids >/dev/null 2>&1 || true
  fi
}

wait_for_file() {
  local path="$1"
  local tries="${2:-50}"
  local delay="${3:-0.1}"
  for _ in $(seq 1 "$tries"); do
    [ -e "$path" ] && return 0
    sleep "$delay"
  done
  return 1
}

gen_password() {
  echo "$VNC_PASSWORD"
}

start_sway() {
  export XDG_RUNTIME_DIR
  export WAYLAND_DISPLAY="$SOCKET_NAME"
  export WLR_BACKENDS=headless
  export WLR_LIBINPUT_NO_DEVICES=1

  mkdir -p "$RUNTIME_DIR"
  chmod 700 "$RUNTIME_DIR"

  stop_wayland0_owners
  cleanup_stale

  # Start sway in headless mode.
  nohup sway --unsupported-gpu >"$SWAY_LOG" 2>&1 &
  echo $! > "$SWAY_PID_FILE"

  # Wait for WAYLAND socket.
  if ! wait_for_file "${XDG_RUNTIME_DIR}/${SOCKET_NAME}" 80 0.1; then
    # Some sway/wlroots builds pick an auto socket name; expose it as wayland-0.
    local alt_socket=""
    alt_socket="$(ls -1t "${XDG_RUNTIME_DIR}"/wayland-* 2>/dev/null | head -n1 || true)"
    if [ -n "$alt_socket" ] && [ -S "$alt_socket" ]; then
      ln -sfn "$alt_socket" "${XDG_RUNTIME_DIR}/${SOCKET_NAME}"
    else
      echo "Sway socket not created: ${XDG_RUNTIME_DIR}/${SOCKET_NAME}" >&2
      echo "Check log: $SWAY_LOG" >&2
      exit 1
    fi
  fi

  # Wait for sway IPC socket path. `sway --get-socketpath` may fail outside
  # the compositor environment, so also scan runtime dir as fallback.
  for _ in $(seq 1 80); do
    SWAYSOCK="$(sway --get-socketpath 2>/dev/null || true)"
    if [ -z "$SWAYSOCK" ]; then
      SWAYSOCK="$(ls -1t "${XDG_RUNTIME_DIR}"/sway-ipc."$(id -u)".*.sock 2>/dev/null | head -n1 || true)"
    fi
    if [ -n "$SWAYSOCK" ] && [ -S "$SWAYSOCK" ]; then
      echo "$SWAYSOCK" > "$SWAYSOCK_FILE"
      break
    fi
    sleep 0.1
  done

  if [ ! -f "$SWAYSOCK_FILE" ]; then
    echo "Failed to discover SWAYSOCK. Check log: $SWAY_LOG" >&2
    exit 1
  fi

  export SWAYSOCK
  SWAYSOCK="$(cat "$SWAYSOCK_FILE")"

  # Ensure a deterministic headless output with requested resolution.
  swaymsg -s "$SWAYSOCK" create_output "$VNC_OUTPUT" >/dev/null 2>&1 || true
  swaymsg -s "$SWAYSOCK" "output $VNC_OUTPUT mode ${WIDTH}x${HEIGHT}" >/dev/null 2>&1 || true

  # Pin initial focus to workspace 1 so VNC opens on the expected workspace.
  swaymsg -s "$SWAYSOCK" workspace number 1 >/dev/null 2>&1 || true
}

start_wayvnc() {
  need_cmd wayvnc
  need_cmd openssl

  local password
  password="$(gen_password)"
  VNC_PASSWORD="$password"

  if [ ! -s "$TLS_CERT" ] || [ ! -s "$TLS_KEY" ]; then
    openssl req -x509 -newkey rsa:2048 -nodes \
      -keyout "$TLS_KEY" -out "$TLS_CERT" \
      -days 3650 -subj "/CN=wayvnc" >/dev/null 2>&1
    chmod 600 "$TLS_KEY"
  fi
  if [ ! -s "$RSA_KEY" ] || ! grep -q "BEGIN RSA PRIVATE KEY" "$RSA_KEY" 2>/dev/null; then
    openssl genrsa -traditional -out "$RSA_KEY" 2048 >/dev/null 2>&1
    chmod 600 "$RSA_KEY"
  fi

  cat > "$WAYVNC_CONF" <<EOF
address=0.0.0.0
port=${PORT}
enable_auth=true
username=${VNC_USERNAME}
password=${VNC_PASSWORD}
rsa_private_key_file=${RSA_KEY}
private_key_file=${TLS_KEY}
certificate_file=${TLS_CERT}
EOF
  chmod 600 "$WAYVNC_CONF"

  export XDG_RUNTIME_DIR
  export WAYLAND_DISPLAY="$SOCKET_NAME"
  nohup wayvnc --config "$WAYVNC_CONF" --output "$VNC_OUTPUT" >"$WAYVNC_LOG" 2>&1 &
  echo $! > "$WAYVNC_PID_FILE"
}

start_waydroid() {
  need_cmd waydroid
  mkdir -p "${XDG_RUNTIME_DIR}/pulse"
  [ -e "${XDG_RUNTIME_DIR}/pulse/native" ] || touch "${XDG_RUNTIME_DIR}/pulse/native"

  export XDG_RUNTIME_DIR
  export WAYLAND_DISPLAY="$SOCKET_NAME"

  waydroid session stop >/dev/null 2>&1 || true
  nohup waydroid -l "$RUNTIME_DIR/waydroid-user.log" session start >"$WAYDROID_LOG" 2>&1 &
  echo $! > "$WAYDROID_PID_FILE"
}

show_waydroid_ui() {
  export XDG_RUNTIME_DIR
  export WAYLAND_DISPLAY="$SOCKET_NAME"
  nohup sh -lc 'sleep 2; waydroid show-full-ui' >"$WAYDROID_UI_LOG" 2>&1 &
}

start() {
  need_cmd sway
  need_cmd swaymsg
  need_cmd wayvnc
  need_cmd waydroid

  mkdir -p "$XDG_RUNTIME_DIR" "$RUNTIME_DIR"
  chmod 700 "$XDG_RUNTIME_DIR" "$RUNTIME_DIR" || true

  stop >/dev/null 2>&1 || true

  start_sway
  start_wayvnc
  start_waydroid
  show_waydroid_ui

  if [ -f "$SWAYSOCK_FILE" ]; then
    SWAYSOCK="$(cat "$SWAYSOCK_FILE")"
    swaymsg -s "$SWAYSOCK" workspace number 1 >/dev/null 2>&1 || true
  fi

  sleep 3
  waydroid status || true
  echo "VNC server: 0.0.0.0:${PORT}"
  echo "Username: ${VNC_USERNAME}"
  echo "Password: ${VNC_PASSWORD}"
  echo "Logs: $SWAY_LOG | $WAYVNC_LOG | $WAYDROID_LOG"
}

start_infra() {
  need_cmd sway
  need_cmd swaymsg
  need_cmd wayvnc

  mkdir -p "$XDG_RUNTIME_DIR" "$RUNTIME_DIR"
  chmod 700 "$XDG_RUNTIME_DIR" "$RUNTIME_DIR" || true

  stop_infra >/dev/null 2>&1 || true
  start_sway
  start_wayvnc

  if [ -f "$SWAYSOCK_FILE" ]; then
    SWAYSOCK="$(cat "$SWAYSOCK_FILE")"
    swaymsg -s "$SWAYSOCK" workspace number 1 >/dev/null 2>&1 || true
  fi

  echo "Infra up (sway + wayvnc)."
  echo "VNC server: 0.0.0.0:${PORT}"
  echo "Username: ${VNC_USERNAME}"
  echo "Password: ${VNC_PASSWORD}"
  echo "Logs: $SWAY_LOG | $WAYVNC_LOG"
}

start_waydroid_only() {
  start_waydroid
  show_waydroid_ui
  sleep 2
  waydroid status || true
}

stop_infra() {
  if [ -f "$WAYVNC_PID_FILE" ] && kill -0 "$(cat "$WAYVNC_PID_FILE")" 2>/dev/null; then
    kill "$(cat "$WAYVNC_PID_FILE")" || true
  fi
  if [ -f "$SWAY_PID_FILE" ] && kill -0 "$(cat "$SWAY_PID_FILE")" 2>/dev/null; then
    kill "$(cat "$SWAY_PID_FILE")" || true
  fi
  cleanup_stale
  rm -f "$SWAY_PID_FILE" "$WAYVNC_PID_FILE" "$SWAYSOCK_FILE"
  echo "Infra stopped."
}

stop_waydroid_only() {
  waydroid session stop >/dev/null 2>&1 || true
  if [ -f "$WAYDROID_PID_FILE" ] && kill -0 "$(cat "$WAYDROID_PID_FILE")" 2>/dev/null; then
    kill "$(cat "$WAYDROID_PID_FILE")" || true
  fi
  rm -f "$WAYDROID_PID_FILE"
  echo "Waydroid stopped."
}

restart_waydroid_only() {
  stop_waydroid_only
  start_waydroid_only
}

stop() {
  stop_waydroid_only
  stop_infra
  echo "Stopped."
}

status() {
  echo "sway:"
  if [ -f "$SWAY_PID_FILE" ] && kill -0 "$(cat "$SWAY_PID_FILE")" 2>/dev/null; then
    echo "  running (pid $(cat "$SWAY_PID_FILE"))"
  else
    echo "  not running"
  fi
  echo "wayvnc:"
  if [ -f "$WAYVNC_PID_FILE" ] && kill -0 "$(cat "$WAYVNC_PID_FILE")" 2>/dev/null; then
    echo "  running (pid $(cat "$WAYVNC_PID_FILE"))"
  else
    echo "  not running"
  fi
  waydroid status || true
}

case "$ACTION" in
  start) start ;;
  stop) stop ;;
  start-infra) start_infra ;;
  stop-infra) stop_infra ;;
  start-waydroid) start_waydroid_only ;;
  stop-waydroid) stop_waydroid_only ;;
  restart-waydroid) restart_waydroid_only ;;
  show-ui)
    show_waydroid_ui
    ;;
  restart)
    stop
    start
    ;;
  status) status ;;
  *)
    echo "Unknown action: $ACTION" >&2
    exit 1
    ;;
esac
