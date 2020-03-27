# server-for-laravel
One-time fully automated shell script to install all needed software to run Laravel on Ubuntu 18.04 LTS. Creates user, installs ufw, nginx, php, nodejs/yarn, MariaDB/MySQL, PostgreSQL, Certbot (Let's Encrypt), Redis, Memcached, Beanstalkd. Optional parameters available.

<p align="center">
  <a href="https://asciinema.org/a/311864"><img src="https://cdn.jsdelivr.net/gh/insign/server-for-laravel/demo.svg"></a>
</p>

>To understand what is installed, check [Parameters](#parameters-all-optional) section

### Recommended requisites
- **Ubuntu 18.04 LTS** ~~or at least newer~~ (not recommended)
- **root**/sudo as current user
- `curl` or `wget` should be installed
- a **_new server_**. We are not responsible for any loss you may suffer.

> Without a new server, the script possible will ask things to replace files. Never recommended.

### Basic Installation

This script is installed by running one of the following commands in your terminal. You can install this via the command-line with either `curl` or `wget`.

>**_At the end you'll receive a report with all passwords. Keep it safe._**
#### via curl

```shell
bash -c "$(curl -fsSL https://git.io/Jv9a6)"
```

#### via wget

```shell
bash -c "$(wget -qO- https://git.io/Jv9a6)"
```
#### Manual inspection

It's a good idea to inspect the install script from projects you don't yet know. You can do
that by downloading the install script first, looking through it so everything looks normal,
then running it:

```shell
curl -Lo install.sh https://raw.githubusercontent.com/insign/server-for-laravel/master/install.sh
bash install.sh
```

## Parameters (all optional)
* `-u|--user` - set new user name. Default: laravel
* `-p|--pass` - set new user password. Default is _random_ (shown at the end)
* `--dont-create-new-user` - don't creates a new user (not recommended)
* `--keep-existing-user` - keep existent user if it exists
* `--skip-swap` - skip creation swapfile (not recommended unless already exists)
* `--swap-size` - set swap file size in MB. Default is 2048 (2GB)
* `--skip-updates` - Skip updates and upgrade the system (not recommended)
* `--no-omz` - don't install oh-my-zsh framework (not recommended)
* `--no-ufw` - don't install or configure UFW firewall (not recommended)
* `--no-nginx` - don't install or configure nginx
* `--no-php` - don't install or configure php
* `--no-node` - don't install or configure yarn/node/npm
* `--no-mysql` - don't install or configure mysql (MariaDB actually)
* `--my-pass-root` - set the mysql root password. Default is _random_ (shown at the end)
* `--my-pass-user` - set the mysql user password. Default is _random_ (shown at the end)
* `--no-postgres` - don't install or configure postgresql
* `--pg-pass` - set the system user 'postgres' password. Default is _random_ (shown at the end) 
* `--pg-pass-root` - set the pg postgres user password. Default is _random_ (shown at the end)
* `--pg-pass-user` - set the pg user password. Default is _random_ (shown at the end)
* `--no-certbot` - don't install or configure certbot (let's encrypt)
* `--no-redis` - don't install or configure redis-server
* `--redis-pass` - set the redis master password. Default is _random_ (shown at the end)

## Examples
### Web Server
#### with nginx & php
```shell
bash -c "$(curl -fsSL https://git.io/Jv9a6)" "" --no-mysql --no-postgres --no-redis
```
### Database Server
> We don't auto allow any port to remote connection. You should prefer private networking.
#### with mysql
```shell
bash -c "$(curl -fsSL https://git.io/Jv9a6)" "" --no-nginx --no-php --no-postgres --no-certbot
```
#### with postgresql
```shell
bash -c "$(curl -fsSL https://git.io/Jv9a6)" "" --no-mysql --no-nginx --no-php --no-certbot
```
### Cache Server
```shell
bash -c "$(curl -fsSL https://git.io/Jv9a6)" "" --no-mysql --no-nginx --no-php --no-postgres --no-certbot
```


## Roadmap
- [X] Finish postgresql installation
- [X] Finish Certbot installation
- [X] Finish supervisord installation
- [X] Finish Redis server installation
- [ ] Finish Memcached installation
- [ ] Finish Beanstalkd installation
- [X] Finish fail2ban installation
- [ ] Use fail2ban to protect nginx
- [ ] Fix postgres time
- [ ] Enable better gzip config for nginx by default
- [ ] Generate ssh key
- [ ] Import private key
- [ ] Remove password login (ssh key only)
- [ ] Support for multiple php versions https://github.com/wilmoore/php-version
- [ ] Install mosh as alternative of ssh
- [ ] One-parameter group for every possible (web,cache,db,queue)
- [ ] Command to add sites, create db user and db, add ssl
- [ ] Configure nginx as loadbalancer
- [ ] Send report via e-mail
  - [ ] Hide report at the end
  - [ ] Hide more our warning/info/success
  - [ ] Run quiet installation with minimum verbosity
  - [ ] Reboot after done
- [ ] Count time passed during installation
- [ ] Add CI for this script.

## Contributing
You are welcome, just do a PR with some explanation.

## License
> Licensed under GNU LESSER GENERAL PUBLIC LICENSE. Check the [GNU GPL3 License](./LICENSE) file for more details.
