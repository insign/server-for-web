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
  swapsize=${swapsize:-2048}
  user=${user:-laravel}
  pass=${pass:=$(random_string)}
  pg_pass=${pg_pass:=$(random_string)}

  my_pass_root=${my_pass_root:=$(random_string)}
  my_pass_user=${my_pass_user:=$(random_string)}

  pg_pass_root=${pg_pass_root:=$(random_string)}
  pg_pass_user=${pg_pass_user:=$(random_string)}

  redis_pass=${redis_pass:=$(random_string)}

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
  LC_ALL=C.UTF-8 apt-fast install -y "$@"
}

error() {
  echo -e "$RED""Error: $@""$RESET" >&2
  exit 1
}

info() {
  echo -e "$GREEN""$BOLD"SERVER FOR LARAVEL:"$RESET $BLUE""$@""$RESET" >&2
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
    error "This script was tested only on Ubuntu 18.04 LTS"
  fi
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

    add-apt-repository -yn ppa:apt-fast/stable

    # postgresql
    echo "deb http://apt.postgresql.org/pub/repos/apt/ bionic-pgdg main" | sudo tee /etc/apt/sources.list.d/pgdg.list
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -

    # yarn
    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list

    # PHP
    LC_ALL=C.UTF-8 add-apt-repository -yn ppa:ondrej/php

    # MariaDB 10.4
    apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc'
    add-apt-repository -yn 'deb [arch=amd64,arm64,ppc64el] http://nyc2.mirrors.digitalocean.com/mariadb/repo/10.4/ubuntu bionic main'

    # CERTBot
    add-apt-repository -yn ppa:certbot/certbot

    # Redis Server
    add-apt-repository -yn ppa:chris-lea/redis-server

    # node / npm
    curl -sL https://deb.nodesource.com/setup_12.x | sudo -E bash -

    apt update && apt upgrade -y
  fi

  info Installing zsh and other basics...

  apt -y install apt-fast
  echo debconf apt-fast/maxdownloads string 16 | debconf-set-selections
  echo debconf apt-fast/dlflag boolean true | debconf-set-selections
  echo debconf apt-fast/aptmanager string apt | debconf-set-selections

  install zsh curl wget zip unzip expect fail2ban xclip

  curl https://getmic.ro | bash
  mv ./micro /usr/bin/micro

  add_to_report "TYPE,USER,PASSWORD"
}

step_user_creation() {
  add_to_report "System,root,(untouched)"
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

    useradd "$user" --create-home --password $(openssl passwd -1 "$pass") --shell $(which zsh)
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

    ufw --force enable

    ufw logging on

    ufw status
  fi
}

step_nginx() {
  if [ "$NO_NGINX" != "true" ]; then
    install nginx

    if command_exists ufw; then
      ufw allow 'Nginx Full'
    fi

    cat >/etc/nginx/conf.d/gzip.conf <<EOF
gzip_comp_level 6;
gzip_min_length 256;
gzip_proxied any;
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

    sed -i "s/user www-data;/user ${user};/" /etc/nginx/nginx.conf
    sed -i 's/# server_names_hash_bucket_size/server_names_hash_bucket_size/' /etc/nginx/nginx.conf
    # sed -i "s/worker_processes.*/worker_processes auto;/" /etc/nginx/nginx.conf # already default
    service nginx restart
  fi
}
step_php() {
  if [ "$NO_PHP" != "true" ]; then
    install php-{common,json,bcmath,pear,curl,dev,gd,mbstring,zip,mysql,xml,fpm,imagick,sqlite3,tidy,xmlrpc,intl,imap,pgsql,tokenizer,redis,memcached}
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
    install mariadb-server-10.4
    expect -c "
        set timeout 3
        spawn mysql_secure_installation

        expect \"Enter current password for root (enter for none):\"
        send -- \"${my_pass_root}\r\"
        expect \"Switch to unix_socket authentication\"
        send -- \"n\r\"
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

step_redis() {
  if [ "$NO_REDIS" != "true" ]; then
    install redis-server

    sed -i 's/bind 127.0.0.1/bind 0.0.0.0/' /etc/redis/redis.conf
    echo "requirepass $redis_pass" >>/etc/redis/redis.conf
    add_to_report "Redis,(none),$RED$BOLD$redis_pass$RESET"
    service redis-server restart
  fi
}

step_memcached() {
  if [ "$NO_MEMCACHED" != "true" ]; then
    install memcached libmemcached-tools
    sed -i 's/-l 127.0.0.1/-l 0.0.0.0/' /etc/memcached.conf
    service memcached restart
  fi
}

step_beanstalkd() {
  if [ "$NO_BEANSTALKD" != "true" ]; then
    install beanstalkd
    sed -i "s/BEANSTALKD_LISTEN_ADDR.*/BEANSTALKD_LISTEN_ADDR=0.0.0.0/" /etc/default/beanstalkd
    service beanstalkd restart
  fi
}

step_final() {
  if [ "$NO_OMZ" != "true" ]; then
    runuser -l $user -c 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended'
  fi

  if [ "$NO_MOSH" != "true" ]; then
    install mosh
    if command_exists ufw; then
      ufw allow 60000:61000/udp
    fi
  fi

  apt purge -y expect
  apt autoremove -y

  mkdir -p /home/laravel/.ssh/
  ssh-keygen -f /home/"$user"/.ssh/id_rsa -t rsa -N ''

  ssh-keyscan -H github.com >>/home/"$user"/.ssh/known_hosts
  ssh-keyscan -H bitbucket.org >>/home/"$user"/.ssh/known_hosts
  ssh-keyscan -H gitlab.com >>/home/"$user"/.ssh/known_hosts

  # Auto upgrade security
  cat >>/etc/apt/apt.conf.d/50unattended-upgrades <<EOF
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "02:38";
EOF

  cat >/etc/apt/apt.conf.d/10periodic <<EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

  apt update && apt -y upgrade

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

  su -l "$user"
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
    --no-mosh) # don't install mosh (ssh alternative) (Unlike default behavior)
      NO_MOSH="true"
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
    --no-redis) # don't install or configure redis server (Unlike default behavior)
      NO_REDIS="true"
      shift 1
      ;;
    --no-memcached) # don't install or configure memcached (Unlike default behavior)
      NO_MEMCACHED="true"
      shift 1
      ;;
    --no-beanstalkd) # don't install or configure beanstalkd (Unlike default behavior)
      NO_BEANSTALKD="true"
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
    --redis-pass=*) # set the redis master password (default is random)
      redis_pass="${1#*=}"
      shift 1
      ;;
    --user | --pass | --pg-pass | --my-pass-root | --my-pass-user | --pg-pass-root | --pg-pass-user | --redis-pass) error "$1 requires an argument" ;;

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

  info "Initial actions...."
  step_initial

  info "Creating user"
  step_user_creation

  info "Installing UFW"
  step_ufw

  info "Installing nginx"
  step_nginx

  info "Installing php 7.4"
  step_php

  info "Installing node 12"
  step_node

  info "Installing MariaDB 10.4"
  step_mysql # Actually, it's MariaDB

  info "Installing PostgreSQL"
  step_postgres

  info "Installing supervisor daemon"
  step_supervisor

  info "Installing certbot (with CloudFlare plugin)"
  step_certbot

  info "Installing Redis"
  step_redis

  info "Installing Memcached"
  step_memcached

  info "Installing beanstalkd"
  step_beanstalkd

  info "Finishing up"
  step_final
}

main "$@"
