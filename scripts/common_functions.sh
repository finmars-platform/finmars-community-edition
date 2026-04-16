#!/usr/bin/env sh

if [ -f .env ]; then
  set -a
  . ./.env
  set +a
fi

# Printing helpers
csi_reset="\033[0m"
csi_bold="\033[1m"
csi_fg_default="\033[39m"
csi_fg_red="\033[91m"
csi_fg_green="\033[92m"
csi_fg_blue="\033[94m"

print_newline() {
  echo >&2
}

print_step() {
  echo "$csi_bold$csi_fg_blue :: $csi_fg_default$1$csi_reset" >&2
  if [ -n "$installer_mode" ]; then
    echo "INSTALLER:CURSTEP:$1"
  fi
}

print_step_info() {
  echo "    $1" >&2
  if [ -n "$installer_mode" ]; then
    echo "INSTALLER:STEPINF:$1"
  fi
}

print_step_warning() {
  echo " ⚠  $1" >&2
}

fatal_step_error() {
  echo " 🛑 $1" >&2
  exit 255
}

print_prerequisite_status() (
  name=$1
  found=$2
  status=$([ "$found" -eq 0 ] && echo "$csi_fg_green found" || echo "$csi_fg_red missing")
  printf "    - %-20s %s $csi_fg_default\n" "$name" "$status" >&2
)

print_option() (
  name=$1
  description=$2
  printf "    - ${csi_bold}%-20s${csi_reset} %s\n" "$name" "$description"
)

print_prompt() {
  printf "    %s " "$1" >&2
  read -r "$2"
}

cmd_open_fallback() {
  print_step_info "Click to open $1"
}

cmd_open=$(command -v xdg-open || command -v open || 'cmd_open_fallback')
