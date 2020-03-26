#!/bin/bash
#
# This script should be run via curl:
#   bash -c "$(curl -fsSL https://git.io/Jv9a6)"
# or wget:
#   bash -c "$(wget -qO- https://git.io/Jv9a6)"
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
  pg_pass=${pg_pass:=$(random_string)}

  my_pass_root=${my_pass_root:=$(random_string)}
  my_pass_user=${my_pass_user:=$(random_string)}

  pg_pass_root=${pg_pass_root:=$(random_string)}
  pg_pass_user=${pg_pass_user:=$(random_string)}

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
    ufw disable
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw allow 22/tcp
    ufw allow 80/tcp
    ufw allow 443/tcp
    if [ -n "$SSH_CONNECTION" ] || [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
      expect -c "
        set timeout 3
        spawn ufw enable

        expect \"Command may disrupt existing ssh connections\"
        send -- \"y\r\"
        expect eof
"
    else
      ufw enable
    fi
    ufw logging on

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

    runuser -l $user -c $'php -r "copy(\'https://getcomposer.org/installer\', \'composer-setup.php\');"'
    runuser -l $user -c $'php composer-setup.php'
    runuser -l $user -c $'php -r "unlink(\'composer-setup.php\');"'

    local -r user_homedir=$(runuser -l $user -c $'pwd')
    mv $user_homedir/composer.phar /usr/local/bin/composer

    runuser -l $user -c $'composer global require hirak/prestissimo'

    runuser -l $user -c $'echo \'export PATH="$PATH:$HOME/.config/composer/vendor/bin"\' >> ~/.zshrc'
  fi
}
step_node() {
  # yarn with node and npm
  if [ "$NO_NODE" != "true" ]; then
    install yarn nodejs
  fi
}
step_mysql() {
  if [ "$NO_MYSQL" != "true" ]; then
    debconf-set-selections <<<"mariadb-server-5.5 mysql-server/root_password password $my_pass_root"
    debconf-set-selections <<<"mariadb-server-5.5 mysql-server/root_password_again password $my_pass_root"
    install mariadb-server-10.3
    expect -c "
        set timeout 3
        spawn mysql_secure_installation

        expect \"Enter current password for root (enter for none):\"
        send -- \"${my_pass_root}\r\"
        expect \"Set root password?\"
        send -- \"n\r\"
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

    local -r MY_USER_EXISTS="$(mysql -uroot -p"$my_pass_root" -sse "SELECT EXISTS(SELECT 1 FROM mysql.user WHERE user = '$user')")"
    if [ "$MY_USER_EXISTS" = 1 ]; then
      mysql -uroot -p"$my_pass_root" <<<"ALTER USER '$user'@'localhost' IDENTIFIED BY '${my_pass_user}';"
    else
      mysql -uroot -p"$my_pass_root" <<<"CREATE USER '$user'@'localhost' IDENTIFIED BY '${my_pass_user}';"
    fi
    mysql -uroot -p"$my_pass_root" <<<"FLUSH PRIVILEGES;"

    add_to_report "MariaDB,$RED${BOLD}${user}$RESET,$RED$BOLD${my_pass_user}$RESET"
  fi
}
step_postgres() {
  if [ "$NO_POSTGRES" != "true" ]; then
    install postgresql-11
    pg_ctlcluster 11 main start

    runuser -l postgres -c "psql -c \"CREATE ROLE ${user} CREATEDB CREATEROLE\""
    runuser -l postgres -c "psql -c \"ALTER USER ${user} PASSWORD '${pg_pass_user}';\""
    runuser -l postgres -c "psql -c \"ALTER USER postgres PASSWORD '${pg_pass_root}';\""

    usermod -p $(openssl passwd -1 "$pg_pass") postgres

    add_to_report "System,$RED${BOLD}postgres$RESET,$RED$BOLD${pg_pass}$RESET"
    add_to_report "PostgreSQL,$RED${BOLD}postgres$RESET,$RED$BOLD${pg_pass_root}$RESET"
    add_to_report "PostgreSQL,$RED${BOLD}${user}$RESET,$RED$BOLD${pg_pass_user}$RESET"

  fi
}
step_supervisor() {
  if [ "$NO_SUPERVISOR" != "true" ]; then
    install supervisor
    service supervisor restart
  fi
}
step_certbot() {
  if [ "$NO_CERTBOT" != "true" ]; then
    install certbot python-certbot-nginx python3-certbot-dns-cloudflare
  fi
}

step_final() {
  if [ "$NO_OMZ" != "true" ]; then
    info Installing ohmyzsh...
    runuser -l $user -c 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended'
  fi

  apt purge -y expect
  apt autoremove -y

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

  su "$user"
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
    info "Creating swapfile of $swapsize mb..."
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
    info Updates and Upgrades...

    install locales language-pack-en-base software-properties-common build-essential
    export LC_ALL=en_US.UTF-8
    export LANG=en_US.UTF-8

    # postgresql
    echo "deb http://apt.postgresql.org/pub/repos/apt/ bionic-pgdg main" | sudo tee /etc/apt/sources.list.d/pgdg.list
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -

    # yarn
    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list

    # node / npm
    curl -sL https://deb.nodesource.com/setup_12.x | sudo -E bash -

    # PHP
    LC_ALL=C.UTF-8 add-apt-repository -yn ppa:ondrej/php

    # MariaDB 10.4
    apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc'
    add-apt-repository -yn 'deb [arch=amd64,arm64,ppc64el] http://nyc2.mirrors.digitalocean.com/mariadb/repo/10.4/ubuntu bionic main'

    # CERTBot
    add-apt-repository -yn ppa:certbot/certbot

    apt update
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
    --skip-swap) # don't creates swapfile (Unlike default behavior)
      SKIP_SWAP="true"
      shift 1
      ;;
    --swap-size=*) # set swap file size in MB (Unlike default behavior)
      swapsize="${1#*=}"
      shift 1
      ;;
    --skip-updates) # don't updates nor upgrades the system (Unlike default behavior)
      SKIP_UPDATES="true"
      shift 1
      ;;
    --no-omz) # don't install oh-my-zsh framework (Unlike default behavior)
      NO_OMZ="true"
      shift 1
      ;;
    --no-ufw) # don't install or configure UFW firewall (Unlike default behavior)
      NO_UFW="true"
      shift 1
      ;;
    --no-nginx) # don't install or configure nginx (Unlike default behavior)
      NO_NGINX="true"
      shift 1
      ;;
    --no-php) # don't install or configure php (Unlike default behavior)
      NO_PHP="true"
      shift 1
      ;;
    --no-node) # don't install or configure yarn/node/npm (Unlike default behavior)
      NO_NODE="true"
      shift 1
      ;;
    --no-mysql) # don't install or configure mysql (Unlike default behavior)
      NO_MYSQL="true"
      shift 1
      ;;
    --no-postgres) # don't install or configure postgresql (Unlike default behavior)
      NO_POSTGRES="true"
      shift 1
      ;;
    --no-certbot) # don't install or configure certbot (let's encrypt) (Unlike default behavior)
      NO_CERTBOT="true"
      shift 1
      ;;
    --user=*) # set the username (instead default)
      user="${1#*=}"
      shift 1
      ;;
    --pass=*) # set the system user password (default is random)
      pass="${1#*=}"
      shift 1
      ;;
    --pg-pass=*) # set the system postgres user password (default is random)
      pg_pass="${1#*=}"
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
    --pg-pass-root=*) # set the pg root password (default is random)
      pg_pass_root="${1#*=}"
      shift 1
      ;;
    --pg-pass-user=*) # set the pg user password (default is random)
      pg_pass_user="${1#*=}"
      shift 1
      ;;
    --user | --pass | --pg-pass | --my-pass-root | --my-pass-user | --pg-pass-root | --pg-pass-user) error "$1 requires an argument" ;;

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
  step_supervisor
  step_certbot

  step_final

}

main "$@"
