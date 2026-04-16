#!/usr/bin/env sh

print_help() {
  cat >&2 <<EOF
USAGE: $0 [OPTIONS…] [configuration]

OPTIONS:
  -d|--dry-run        Don't do anything, instead print what would be done
  -h|--help           Display this help
  -i|--install-docker Install docker if missing without prompting
  -u|--username       Admin username
  -p|--password       Admin password
  --no-open           Don't open the browser

ARGUMENTS:
  configuration       Installation configuration (one of empty, pms-core, pms-core-demo-data)
EOF
}

# Flags definitions
open_browser=true
install_docker=false
dry_run=false
bootstrap_image=
admin_username=
admin_password=

# Flags parsing
while :; do
  case "$1" in
    -h|--help)
      print_help
      exit 0
      ;;
    -i|--install-docker)
      install_docker=true
      ;;
    -d|--dry-run)
      dry_run=true
      ;;
    --no-open)
      open_browser=false
      ;;
    -u|--username)
      if [ -n "$2" ]; then
        admin_username="$2"
        shift
      else
        echo "--username requires an argument"
      fi
      ;;
    -p|--password)
      if [ -n "$2" ]; then
        admin_password="$2"
        shift
      else
        echo "--password requires an argument"
      fi
      ;;
    # Undocumented flag for development where the bootstrap image is not on Docker hub
    --bootstrap-image)
      if [ -n "$2" ]; then
        bootstrap_image="$2"
        shift
      else
        echo "--bootstrap-image requires an argument"
      fi
      ;;
    -*)
      echo "Invalid flag: $1"
      print_help
      exit 255
      ;;
    *)
      break
      ;;
  esac
  shift
done


# Arguments
database="$1"

################################################################################
# COMMON FUNCTIONS (copied from scripts/common_functions.sh                    #
################################################################################

# Printing helpers
csi_reset="\033[0m"
csi_bold="\033[1m"
csi_fg_default="\033[39m"
csi_fg_red="\033[91m"
csi_fg_green="\033[92m"
csi_fg_blue="\033[94m"


# cmd_open=$(command -v xdg-open || command -v open || 'cmd_open_fallback')
cmd_open='cmd_open_fallback'

print_newline() {
  echo >&2
}

print_step() {
 echo "$csi_bold$csi_fg_blue :: $csi_fg_default$1$csi_reset" >&2
}

print_step_info() {
  echo "    $1" >&2
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

################################################################################
# END OF COMMON FUNCTIONS                                                      #
################################################################################

# Utility functions

install_docker() {
  print_step "Install Docker"

  print_step_info "Downloading install script"
  curl -fsSL https://get.docker.com -o install-docker.sh

  print_step_info "Simulating install script"
  sh install-docker.sh --dry-run

  confirm=
  if [ "$install_docker" = "true" ]; then
    confirm=Y
  fi

  until [ -n "$confirm" ]; do
    print_prompt "Install? (yN)" confirm
    case "$confirm" in
      [Nn])
        fatal_step_error "Docker not installed. Exiting"
        ;;
      "")
        fatal_step_error "Docker not installed. Exiting"
        ;;
      [Yy])
        print_step_info "Installing docker"
        ;;
      *)
        confirm=
        ;;
    esac
  done
  sh install-docker.sh

}

check_prerequisites() {
  print_step "Prerequisites check"

  command -v docker > /dev/null 2>&1
  has_docker=$?
  print_prerequisite_status docker "$has_docker"

  if [ "$has_docker" -ne 0 ]; then
    command -v curl > /dev/null 2>&1
    has_curl=$?
    print_prerequisite_status curl "$has_curl"
  fi
}

create_bootstrap_image() {
  print_step "Get bootstrap container"
  if [ -f "bootstrap.Dockerfile" ]; then
    print_step_info "Building local boostrap container"
    docker build --tag "finmars/bootstrap:latest" --quiet -f bootstrap.Dockerfile .
  elif [ -n "$bootstrap_image" ]; then
    print_step_info "Loading bootstrap container file"
    docker image load -q >&2 < "$bootstrap_image"
    echo "finmars/bootstrap:latest"
  else
    print_step_info "Pulling boostrap image"
    docker pull --progress quiet "docker.io/finmars/bootstrap:latest"
  fi
}

run_bootstrap_container() {
  print_step "Run bootstrap container"
  host_dir="$PWD/finmars-community-edition"
  mkdir -p "$host_dir"
  docker run --rm --interactive --use-api-socket --volume "$host_dir:$host_dir" --workdir "$host_dir" --env "ADMIN_USERNAME=$admin_username" --env "ADMIN_PASSWORD=$admin_password" "$1" sh <<EOF
   #!/usr/bin/env sh
   set -eux
   export COMPOSE_PROGRESS=quiet
   if [ ! -d ".git" ]; then
     git clone --depth 1 https://github.com/finmars-platform/finmars-community-edition.git .
   fi
   install-demo.sh $2
   make up
EOF
}

choose_credentials() {
  print_step "Admin credentials"

  until [ -n "$admin_username" ]; do
    print_prompt "Enter admin username:" admin_username
  done

  until [ -n "$admin_password" ]; do
    print_prompt "Enter admin password:" admin_password
  done
}

choose_demo_db() {
  print_step "Select demo setup"

  if [ -n "$database" ] && [ ! "$database" = "empty" ] && [ ! "$database" = "pms-core" ] && [ ! "$database" = "pms-core-demo-data" ]; then
    print_step_warning "'$database' is not a valid configuration"
    database=
  fi

  until [ -n "$database" ]; do
    print_step_info "Choose one of the following demo setups:"
    print_option "empty"              "Minimal setup without configurations or demo data (e)"
    print_option "pms-core"           "PMS-core preconfigured, without demo data (p)"
    print_option "pms-core-demo-data" "PMS-core preconfigured, with demo data (default)"
    print_newline
    print_prompt "    Which demo database to use? (epD): " db
    case "$db" in
      e|E|empty)
        database="empty"
        ;;
      p|P|pms|PMS|pms-core|PMS-CORE)
        database="pms-core"
        ;;
      d|D|demo|DEMO|demo-data|DEMO-DATA|"")
        database="pms-core-demo-data"
        ;;
      *)
        echo "Invalid choice"
        ;;
    esac
  done
  print_step_info "Using '$database'"
}

check_prerequisites

if [ "$has_docker" -ne 0 ]; then
  install_docker
fi

choose_credentials
choose_demo_db
bootstrap_container=$(create_bootstrap_image)
echo "Bootstrap container: '$bootstrap_container'"

run_bootstrap_container "$bootstrap_container" "$database"

print_step "Opening Finmars"
$cmd_open https://127.0.0.1/