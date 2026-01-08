#!/bin/bash

set -euo pipefail

LOG_FILE="$(mktemp)"

if ! pip install -r requirements.txt >"$LOG_FILE" 2>&1; then
  echo "UI setup failed during dependency installation. See error details below:"
  cat "$LOG_FILE"
  rm -f "$LOG_FILE"
  exit 1
fi

rm -f "$LOG_FILE"

LOG_FILE="$(mktemp)"

if command -v lsof >/dev/null 2>&1; then
  EXISTING_PIDS="$(lsof -ti:8888 || true)"
  if [ -n "$EXISTING_PIDS" ]; then
    kill $EXISTING_PIDS || true
  fi
fi

python3 -m community_edition.main >"$LOG_FILE" 2>&1 & SERVER_PID=$!

sleep 3

if ps -p "$SERVER_PID" >/dev/null 2>&1; then
  rm -f "$LOG_FILE"
  cat > .init-setup-state.json << 'EOF'
{
  "generate_env": "done",
  "init_cert": "done",
  "init_keycloak": "done",
  "update_versions": "done",
  "restore_backup": "done",
  "docker_up": "done"
}
EOF
  echo "UI setup complete!"
else
  echo "UI setup failed while starting web server. See error details below:"
  cat "$LOG_FILE"
  rm -f "$LOG_FILE"
  exit 1
fi
