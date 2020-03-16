#!/bin/bash
#
# This script should be run via curl:
#   sh -c "$(curl -fsSL https://raw.githubusercontent.com/insign/server-for-laravel/master/install.sh)"
# or wget:
#   sh -c "$(wget -qO- https://raw.githubusercontent.com/insign/server-for-laravel/master/install.sh)"
#
# As an alternative, you can first download the install script and run it afterwards:
#   wget https://raw.githubusercontent.com/insign/server-for-laravel/master/install.sh
#   sh install.sh

set -e

# Other options
call_vars() {
  AUTO=${AUTO:-false}
  BLOCK_PW=${BLOCK_PW:-yes}
  MOSH=${MOSH:-yes}
  user=${user:-laravel}
  pass=${pass:=$(random_string)}
}

random_string() {
  cat /dev/urandom | tr -dc 'a-zA-Z0-9-#&' | fold -w 32 | head -n 1
}

command_exists() {
  command -v "$@" >/dev/null 2>&1
}

error() {
  echo "$RED""Error: $@""$RESET" >&2
  exit 1
}

info() {
  echo "$BLUE""$@""$RESET" >&2
}
warning() {
  echo "$YELLOW""Warning: $@""$RESET" >&2
}
success() {
  echo "$GREEN""$@""$RESET" >&2
}

root_required() {
  if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root"
  fi
}
others_checks() {
  if [[ $(lsb_release -rs) != "18.04" ]]; then
    warning "This script was tested only on Ubuntu 18.04 LTS, but let's go ahead..."
  fi
}

step_user_creation() {
  if [ $(getent passwd "$user") ]; then
    if [ "$AUTO" = "true" ] || [ "$DELETE_EXISTING_USER" = "true" ]; then
      info Deleting current user: "$GREEN""$BOLD""$user""$RESET"
      userdel -r $user
      success Deleted.
    else
      error user already exists, use --delete-existing-user or --auto or choose another: "$GREEN""$BOLD""$user""$RESET"
    fi
  fi

  useradd "$user" -m -p $(openssl passwd -1 "$pass") -s $(which zsh)
  usermod -aG sudo "$user" # append to sudo and user group
  success User created: "$BLUE""$BOLD""$user"
}

step_final() {
  if [ "$NOOMZ" != "true" ]; then
    info Installing ohmyzsh...
    runuser -l $user -c 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended'
  fi

  printf "$GREEN"
  # http://patorjk.com/software/taag/#p=display&f=ANSI%20Shadow&t=DONE!
  cat <<-'EOF'


      ██████╗  ██████╗ ███╗   ██╗███████╗██╗
      ██╔══██╗██╔═══██╗████╗  ██║██╔════╝██║
      ██║  ██║██║   ██║██╔██╗ ██║█████╗  ██║
      ██║  ██║██║   ██║██║╚██╗██║██╔══╝  ╚═╝
      ██████╔╝╚██████╔╝██║ ╚████║███████╗██╗
      ╚═════╝  ╚═════╝ ╚═╝  ╚═══╝╚══════╝╚═╝

	EOF
  printf "$RESET"

  echo "USER: $RED$BOLD$user$RESET and password: $RED$BOLD$pass$RESET" >&2

  # If this user's login shell is already "zsh", do not attempt to switch.
  if [ "$(basename "$SHELL")" = "zsh" ]; then
    return
  fi
  exec zsh -l
}

setup_color() {
  # Only use colors if connected to a terminal
  RED=$(printf '\033[31m')
  GREEN=$(printf '\033[32m')
  YELLOW=$(printf '\033[33m')
  BLUE=$(printf '\033[34m')
  BOLD=$(printf '\033[1m')
  RESET=$(printf '\033[m')
}

setup_shell() {
  if ! command_exists zsh; then
    info Installing zsh...
    apt install -y zsh curl wget
  fi
}

main() {
  setup_color
  call_vars
  others_checks
  root_required
  setup_shell

  # Run as unattended if stdin is closed
  if [ ! -t 0 ]; then
    AUTO=true
  fi

  # Parse arguments
  while [ "$#" -gt 0 ]; do
    case "$1" in
    -u)
      user="$2"
      shift 2
      ;;
    -p)
      pass="$2"
      shift 2
      ;;

    --auto)
      AUTO="true"
      shift 1
      ;;
    --delete-existing-user) # delete existent user if it exists (--auto deletes)
      DELETE_EXISTING_USER="true"
      shift 1
      ;;
    --no-ohmyzsh) # do not install oh-my-zsh framework (--auto installs)
      NOOMZ="true"
      shift 1
      ;;
    --user=*)
      user="${1#*=}"
      shift 1
      ;;
    --pass=*)
      pass="${1#*=}"
      shift 1
      ;;
    --user | --pass) error "$1 requires an argument" ;;

    -*)
      error "unknown option: $1" >&2
      exit 1
      ;;
    *)
      handle_argument "$1"
      shift 1
      ;;
    esac
  done

  step_user_creation
  step_final

}

main "$@"
