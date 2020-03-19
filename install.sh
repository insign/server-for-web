#!/bin/bash
#
# This script should be run via curl:
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/insign/server-for-laravel/master/install.sh)"
# or wget:
#   bash -c "$(wget -qO- https://raw.githubusercontent.com/insign/server-for-laravel/master/install.sh)"
#
# As an alternative, you can first download the install script and run it afterwards:
#   wget https://raw.githubusercontent.com/insign/server-for-laravel/master/install.sh
#   bash install.sh

set -e

# Other options
call_vars() {
  BLOCK_PW=${BLOCK_PW:-yes}
  MOSH=${MOSH:-yes}
  swapsize=${swapsize:-2048}
  user=${user:-laravel}
  pass=${pass:=$(random_string)}
  my_pass_root=${my_pass_root:=$(random_string)}
  my_pass_user=${my_pass_user:=$(random_string)}

  REPORT=''
}

add_to_report() {
  REPORT="$REPORT""\n""$1"
}

show_report() {
  printTable ',' "$REPORT" 'true'

  warning "Lose this data then go cry to you mom."
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
  echo -e "$RED""Error: $@""$RESET" >&2
  exit 1
}

info() {
  echo -e "$BLUE""$@""$RESET" >&2
}
warning() {
  echo -e "$YELLOW""Warning: $@""$RESET" >&2
}
success() {
  echo -e "$GREEN""$@""$RESET" >&2
}

removeEmptyLines() {
  echo -e "${1}" | sed '/^\s*$/d'
}

isEmptyString() {
  if [[ "$(trimString "${1}")" == '' ]]; then
    echo 'true' && return 0
  fi

  echo 'false' && return 1
}

trimString() {
  sed 's,^[[:blank:]]*,,' <<<"${1}" | sed 's,[[:blank:]]*$,,'
}

isPositiveInteger() {
  if [[ "${1}" =~ ^[1-9][0-9]*$ ]]; then
    echo 'true' && return 0
  fi

  echo 'false' && return 1
}

repeatString() {
  local -r string="${1}"
  local -r numberToRepeat="${2}"

  if [[ "${string}" != '' && "$(isPositiveInteger "${numberToRepeat}")" == 'true' ]]; then
    local -r result="$(printf "%${numberToRepeat}s")"
    echo -e "${result// /${string}}"
  fi
}

printTable() {
  local -r delimiter="${1}"
  local -r tableData="$(removeEmptyLines "${2}")"
  local -r colorHeader="${3}"
  local -r displayTotalCount="${4}"

  if [[ "${delimiter}" != '' && "$(isEmptyString "${tableData}")" == 'false' ]]; then
    local -r numberOfLines="$(trimString "$(wc -l <<<"${tableData}")")"

    if [[ "${numberOfLines}" -gt '0' ]]; then
      local table=''
      local i=1

      for ((i = 1; i <= "${numberOfLines}"; i = i + 1)); do
        local line=''
        line="$(sed "${i}q;d" <<<"${tableData}")"

        local numberOfColumns=0
        numberOfColumns="$(awk -F "${delimiter}" '{print NF}' <<<"${line}")"

        # Add Line Delimiter

        if [[ "${i}" -eq '1' ]]; then
          table="${table}$(printf '%s#+' "$(repeatString '#+' "${numberOfColumns}")")"
        fi

        # Add Header Or Body

        table="${table}\n"

        local j=1

        for ((j = 1; j <= "${numberOfColumns}"; j = j + 1)); do
          table="${table}$(printf '#|  %s' "$(cut -d "${delimiter}" -f "${j}" <<<"${line}")")"
        done

        table="${table}#|\n"

        # Add Line Delimiter

        if [[ "${i}" -eq '1' ]] || [[ "${numberOfLines}" -gt '1' && "${i}" -eq "${numberOfLines}" ]]; then
          table="${table}$(printf '%s#+' "$(repeatString '#+' "${numberOfColumns}")")"
        fi
      done

      if [[ "$(isEmptyString "${table}")" == 'false' ]]; then
        local output=''
        output="$(echo -e "${table}" | column -s '#' -t | awk '/^\+/{gsub(" ", "-", $0)}1')"

        if [[ "${colorHeader}" == 'true' ]]; then
          echo -e "\033[1;32m$(head -n 3 <<<"${output}")\033[0m"
          tail -n +4 <<<"${output}"
        else
          echo "${output}"
        fi
      fi
    fi

    if [[ "${displayTotalCount}" == 'true' && "${numberOfLines}" -ge '0' ]]; then
      echo -e "\n\033[1;36mTOTAL ROWS : $((numberOfLines - 1))\033[0m"
    fi
  fi
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
  add_to_report "System,root,untouched"
  if [ "$CREATE_NEW_USER" != "false" ]; then
    if [ $(getent passwd "$user") ]; then
      if [ "$KEEP_EXISTING_USER" != "true" ]; then
        info Deleting current user: "$GREEN""$BOLD""$user""$RESET"
        userdel -r $user
        success Deleted.
      else
        error user already exists, remove --keep-existing-user or choose another: "$GREEN""$BOLD""$user""$RESET"
      fi
    fi

    useradd "$user" -m -p $(openssl passwd -1 "$pass") -s $(which zsh)
    usermod -aG sudo "$user" # append to sudo and user group
    success User created: "$BLUE""$BOLD""$user"

    add_to_report "System,$RED$BOLD$user$RESET,$RED$BOLD$pass$RESET"
  fi
}

step_ufw() {
  if [ "$NO_UFW" != "true" ]; then
    # TODO allow add ips via command
    install ufw
    ufw --force reset
    ufw logging on
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw allow 22/tcp
    ufw allow 80/tcp
    ufw allow 443/tcp

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
    install php-{common,json,bcmath,pear,curl,dev,gd,mbstring,zip,mysql,xml,fpm,imagick,sqlite3,tidy,xmlrpc,intl,imap,pgsql,tokenizer,redis}
    install php

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
    debconf-set-selections <<<"mariadb-server-5.5 mysql-server/root_password password $my_pass_root"
    debconf-set-selections <<<"mariadb-server-5.5 mysql-server/root_password_again password $my_pass_root"
    install mariadb-server
    expect -c "
        set timeout 3
        spawn mysql_secure_installation

        expect \"Enter current password for root (enter for none):\"
        send -- \"\r\"
        expect \"Set root password?\"
        send -- \"Y\r\"
        expect \"New password:\"
        send -- \"${my_pass_root}\r\"
        expect \"Re-enter new password:\"
        send -- \"${my_pass_root}\r\"
        expect \"Remove anonymous users?\"
        send -- \"Y\r\"
        expect \"Disallow root login remotely?\"
        send -- \"Y\r\"
        expect \"Remove test database and access to it?\"
        send -- \"Y\r\"
        expect \"Reload privilege tables now?\"
        send -- \"Y\r\"
        expect eof
"

    add_to_report "MariaDB,$RED${BOLD}root$RESET,$RED$BOLD$my_pass_root$RESET"

    local -r MY_USER_EXISTS="$(mysql -sse "SELECT EXISTS(SELECT 1 FROM mysql.user WHERE user = '$user')")"
    if [ "$MY_USER_EXISTS" = 1 ]; then
      mysql <<<"ALTER USER '$user'@'localhost' IDENTIFIED BY '$my_pass_user';"
    else
      mysql <<<"CREATE USER '$user'@'localhost' IDENTIFIED BY '$my_pass_user';"
    fi
    mysql <<<"FLUSH PRIVILEGES;"

    add_to_report "MariaDB,$RED${BOLD}$user$RESET,$RED$BOLD$my_pass_user$RESET"
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

  apt purge -y expect

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

  show_report

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

  if [ "$SKIP_SWAP" != "true" ]; then
    if [[ $(swapon --show) ]]; then
      swapoff /swapfile
      rm /swapfile
    fi
    dd if=/dev/zero of=/swapfile bs=1M count=$swapsize
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    swapon -s # status
  fi

  if [ "$SKIP_UPDATES" != "true" ]; then
    info Update and Upgrade

    install locales language-pack-en-base software-properties-common
    export LC_ALL=en_US.UTF-8
    export LANG=en_US.UTF-8

    # yarn / node / npm
    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
    LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php # forces apt update

    apt upgrade -y
  fi

  info Installing zsh and other basics...
  install zsh curl wget zip unzip expect

  add_to_report "TYPE,USER,PASSWORD"
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
    --dont-create-new-user) # don't creates a new user (Unlike default behavior)
      CREATE_NEW_USER="false"
      shift 1
      ;;
    --keep-existing-user) # keep existent user if it exists (Unlike default behavior)
      KEEP_EXISTING_USER="true"
      shift 1
      ;;
    --skip-swap) # do not creates swapfile (Unlike default behavior)
      SKIP_SWAP="true"
      shift 1
      ;;
    --skip-updates) # do not updates nor upgrades the system (Unlike default behavior)
      SKIP_UPDATES="true"
      shift 1
      ;;
    --no-omz) # do not install oh-my-zsh framework (Unlike default behavior)
      NO_OMZ="true"
      shift 1
      ;;
    --no-ufw) # do not install or configure UFW firewall (Unlike default behavior)
      NO_UFW="true"
      shift 1
      ;;
    --no-nginx) # do not install or configure nginx (Unlike default behavior)
      NO_NGINX="true"
      shift 1
      ;;
    --no-php) # do not install or configure php (Unlike default behavior)
      NO_PHP="true"
      shift 1
      ;;
    --no-node) # do not install or configure yarn/node/npm (Unlike default behavior)
      NO_NODE="true"
      shift 1
      ;;
    --no-mysql) # do not install or configure mysql (Unlike default behavior)
      NO_MYSQL="true"
      shift 1
      ;;
    --no-postgres) # do not install or configure postgresql (Unlike default behavior)
      NO_POSTGRES="true"
      shift 1
      ;;
    --no-lets-encrypt) # do not install or configure let's encrypt / certbot (Unlike default behavior)
      NO_LETS="true"
      shift 1
      ;;
    --user=*) # set the username (instead default)
      user="${1#*=}"
      shift 1
      ;;
    --pass=*) # set the user password (default is random)
      pass="${1#*=}"
      shift 1
      ;;
    --my-pass-root=*) # set the mysql root password (default is random)
      my_pass_root="${1#*=}"
      shift 1
      ;;
    --my-pass-user=*) # set the mysql user password (default is random)
      my_pass_user="${1#*=}"
      shift 1
      ;;
    --user | --pass | --my-pass-root | --my-pass-user) error "$1 requires an argument" ;;

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

  parse_arguments "$@"

  step_initial

  step_user_creation
  step_ufw
  step_nginx
  step_php
  step_node
  step_mysql # Actually, it's MariaDB
  step_postgres
  step_lets_encrypt

  step_final

}

main "$@"
