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
  my_pass=${my_pass:=$(random_string)}
}

random_string() {
  sed "s/[^a-zA-Z0-9]//g" <<<$(cat /dev/urandom | tr -dc 'a-zA-Z0-9!@#$%*()+-' | fold -w 32 | head -n 1)
}

command_exists() {
  command -v "$@" >/dev/null 2>&1
}

install() {
  LC_ALL=C.UTF-8 apt install -y "$@"
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
    # TODO enable gzip

    if command_exists ufw; then
      ufw allow 'Nginx HTTP'
      ufw allow 'Nginx HTTPS'
    fi

    service nginx restart
  fi
}
step_php() {
  if [ "$NO_PHP" != "true" ]; then
    install php php-{common,json,bcmath,pear,curl,dev,gd,mbstring,zip,mysql,xml,fpm,imagick,sqlite3,tidy,xmlrpc,intl,imap,pgsql,tokenizer,redis}

    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
    php composer-setup.php
    php -r "unlink('composer-setup.php');"
    mv composer.phar /usr/local/bin/composer

    composer global require hirak/prestissimo laravel/installer

    runuser -l $user -c $'echo \'export PATH="$PATH:$HOME/.config/composer/vendor/bin"\' >> ~/.zshrc'
  fi
}
step_node() {
  # yarn with node and npm
  if [ "$NO_NODE" != "true" ]; then
    install yarn
  fi
}
step_mysql() {
  if [ "$NO_MYSQL" != "true" ]; then
    debconf-set-selections <<<"mariadb-server-5.5 mysql-server/root_password password $my_pass"
    debconf-set-selections <<<"mariadb-server-5.5 mysql-server/root_password_again password $my_pass"
    i mariadb-server
  fi
}
step_postgres() {
  if [ "$NO_POSTGRES" != "true" ]; then
    echo ''
  fi
}
step_lets_encrypt() {
  if [ "$NO_LETS" != "true" ]; then
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
  echo "MariaDB => User $RED$BOLD$user$RESET and password: $RED$BOLD$my_pass$RESET" >&2

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

step_initial() {
  export DEBIAN_FRONTEND=noninteractive

  if [ "$SKIP_UPDATES" != "true" ]; then
    info Update and Upgrade

    install language-pack-en-base software-properties-common
    export LC_ALL=en_US.UTF-8
    export LANG=en_US.UTF-8

    # yarn / node / npm
    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
    LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php # forces apt update

    apt upgrade -y
  fi

  info Installing zsh and other basics...
  install zsh curl wget locales zip unzip
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
    --no-php) # do not install or configure php (--auto does)
      NO_PHP="true"
      shift 1
      ;;
    --no-node) # do not install or configure yarn/node/npm (--auto does)
      NO_NODE="true"
      shift 1
      ;;
    --no-mysql) # do not install or configure mysql (--auto does)
      NO_MYSQL="true"
      shift 1
      ;;
    --no-postgres) # do not install or configure postgresql (--auto does)
      NO_POSTGRES="true"
      shift 1
      ;;
    --no-lets-encrypt) # do not install or configure let's encrypt / certbot (--auto does)
      NO_LETS="true"
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

  step_initial

  step_user_creation
  #  step_ufw
  #  step_nginx
  #  step_php
  #  step_node
  #  step_mysql # Actually, it's MariaDB
  #  step_postgres
  #  step_lets_encrypt

  step_final

}

main "$@"
