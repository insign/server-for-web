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

install() {
  apt install -y "$@"
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
  root_required

  if [[ $(lsb_release -rs) != "18.04" ]]; then
    warning "This script was tested only on Ubuntu 18.04 LTS, but let's go ahead..."
  fi
}

step_user_creation() {
  if [ "$CREATE_NEW_USER" != "false" ]; then
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
  fi
}

step_ufw() {
  if [ "$NO_UFW" != "true" ]; then
    # TODO allow add ips via command
    install ufw
    ufw logging on
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw allow 22
    ufw allow 80
    ufw allow 443

    ufw enable
    ufw status
  fi
}

step_nginx() {
  if [ "$NO_NGINX" != "true" ]; then
    install nginx

    cat >/etc/nginx/conf.d/gzip.conf <<EOF
gzip on;
gzip_comp_level 5;
gzip_min_length 1000;
gzip_proxied no-cache no-store private expired auth;
gzip_vary on;
gzip_types
application/atom+xml
application/javascript
application/json
application/rss+xml
application/vnd.ms-fontobject
application/x-font-ttf
application/x-web-app-manifest+json
application/xhtml+xml
application/xml
font/opentype
image/svg+xml
image/x-icon
text/css
text/plain
text/x-component;
EOF
    service nginx restart

    if command_exists ufw; then
      ufw allow 'Nginx HTTP'
      ufw allow 'Nginx HTTPS'
    fi
  fi
}
step_php() {
  # TODO Composer, php-fpm, laravel command
  if [ "$NO_UFW" != "true" ]; then
    echo ''
  fi
}
step_node() {
  # TODO node, npm, yarn
  if [ "$NO_UFW" != "true" ]; then
    echo ''
  fi
}
step_mysql() {
  if [ "$NO_UFW" != "true" ]; then
    echo ''
  fi
}
step_postgres() {
  if [ "$NO_UFW" != "true" ]; then
    echo ''
  fi
}
step_lets_encrypt() {
  if [ "$NO_UFW" != "true" ]; then
    echo ''
  fi
}

step_final() {
  if [ "$NO_OMZ" != "true" ]; then
    info Installing ohmyzsh...
    runuser -l $user -c 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended'
  fi

  echo "$GREEN"
  # http://patorjk.com/software/taag/#p=display&f=ANSI%20Shadow&t=DONE!
  cat <<-'EOF'


      ██████╗  ██████╗ ███╗   ██╗███████╗██╗
      ██╔══██╗██╔═══██╗████╗  ██║██╔════╝██║
      ██║  ██║██║   ██║██╔██╗ ██║█████╗  ██║
      ██║  ██║██║   ██║██║╚██╗██║██╔══╝  ╚═╝
      ██████╔╝╚██████╔╝██║ ╚████║███████╗██╗
      ╚═════╝  ╚═════╝ ╚═╝  ╚═══╝╚══════╝╚═╝

	EOF
  echo "$RESET"

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

setup_basics() {
  if [ "$SKIP_UPDATES" != "true" ]; then
    info Update and Upgrade
    apt update && apt upgrade -y
  fi
  info Installing zsh and other basics...
  install zsh curl wget software-properties-common locales
}

parse_arguments() {
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
    --dont-create-new-user) # don't creates a new user (--auto creates)
      CREATE_NEW_USER="false"
      shift 1
      ;;
    --delete-existing-user) # delete existent user if it exists (--auto deletes)
      DELETE_EXISTING_USER="true"
      shift 1
      ;;
    --skip-updates) # do not updates nor upgrades the system (--auto does)
      SKIP_UPDATES="true"
      shift 1
      ;;
    --no-ohmyzsh) # do not install oh-my-zsh framework (--auto installs)
      NO_OMZ="true"
      shift 1
      ;;
    --no-ufw) # do not install or configure UFW firewall (--auto does)
      NO_UFW="true"
      shift 1
      ;;
    --no-nginx) # do not install or configure nginx (--auto does)
      NO_NGINX="true"
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
}

main() {
  setup_color
  call_vars
  others_checks

  # Run as unattended if stdin is closed
  if [ ! -t 0 ]; then
    AUTO="true"
  fi

  parse_arguments "$@"

  setup_basics

  step_user_creation
  step_ufw
  step_nginx
  step_final

}

main "$@"
