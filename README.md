# server-for-laravel
One-time fully automated shell script to install all needed software to run any php framework on Ubuntu 18.04 LTS. Creates user, installs ufw, nginx (or apache), php, nodejs/yarn, MariaDB/MySQL, PostgreSQL, Certbot (Let's Encrypt), Redis, Memcached, Beanstalkd, fail2ban, mosh. Optional parameters available.

<p align="center">
  <a href="https://asciinema.org/a/311864"><img src="https://cdn.jsdelivr.net/gh/insign/server-for-laravel/demo.svg"></a>
</p>

Beyond the description, here some things that this script does (by default):
- Enables ubuntu auto-upgrade security releases
- Uses apt-fast to speed-up instalation
- CLI tools: [`ncdu`](https://en.wikipedia.org/wiki/Ncdu), [`awscli`](https://aws.amazon.com/cli/), `whois`, [`httpie`](https://httpie.org/), [`mc`](http://linuxcommand.org/lc3_adv_mc.php), [`speedtest`](https://github.com/sivel/speedtest-cli), [`micro`](https://micro-editor.github.io/), [`mosh`](https://mosh.org/)
- Installs and enable zsh with [oh-my-zsh](https://ohmyz.sh/), [pure](https://github.com/sindresorhus/pure), [neofetch](https://github.com/dylanaraps/neofetch)
- Creates swap file to avoid lack of memory
- Auto-generates secure and easy-to-copy passwords
- Installs and enable ufw, and fail2ban
- nginx with better gzip on, or Apache if you prefer. 
- Installs php7.4 (with FPM) (and others versions), many popular extensions, composer, [prestissimo](https://github.com/hirak/prestissimo)
- Secure install MariaDB (mysql) and PostgreSQL
- Installs supervisor daemon
- [Certbot](https://certbot.eff.org/) with [DNS plugins](https://certbot.eff.org/docs/using.html#dns-plugins):cloudflare,digitalocean,dnsimple,google,rfc2136,route53
- Generates server ssh key
- Import keys from popular git services (github, bitbucket, gitlab)

 

>To better choose what to install, check [Parameters](#parameters-all-optional) section

### Requisites
- **Ubuntu 18.04 LTS**
- **root**/sudo as current user
- `curl` or `wget` should be installed
- a **_new server_**. We are not responsible for any loss you may suffer.
  -  My referral links: [Vultr](https://www.vultr.com/?ref=7205888) - [DigitalOcean](https://m.do.co/c/4361152a43e1)

> Without a new server, the script possible will ask things to replace files. Never recommended.

### Full Installation

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
* `-u|--user=` - set new user name. Default: laravel
* `-p|--pass=` - set new user password. Default is _random_ (shown at the end)
* `--name=` - set your name. Default is _DevOps_
* `--email=` - set your e-mail. Default is _none@none_
* `--dont-create-new-user` - don't creates a new user (not recommended)
* `--keep-existing-user` - keep existent user if it exists
* `--skip-swap` - skip creation swapfile (not recommended unless already exists)
* `--swap-size` - set swap file size in MB. Default is 2048 (2GB)
* `--skip-updates` - Skip updates and upgrade the system (not recommended)
* `--no-omz` - don't install [oh-my-zsh](https://ohmyz.sh/) framework (not recommended)
* `--no-mosh` - don't install [mosh](https://mosh.org) (ssh alternative)
* `--no-ufw` - don't install or configure UFW firewall (not recommended)
* `--prefer-apache` - Install Apache Server (and don't install or configure nginx)
* `--no-nginx` - don't install or configure nginx
* `--no-php` - don't install or configure php
* `--no-node` - don't install or configure yarn/node/npm
* `--no-mysql` - don't install or configure mysql (MariaDB actually)
* `--my-pass-root=` - set the mysql root password. Default is _random_ (shown at the end)
* `--my-pass-user=` - set the mysql user password. Default is _random_ (shown at the end)
* `--no-postgres` - don't install or configure postgresql
* `--pg-pass=` - set the system user 'postgres' password. Default is _random_ (shown at the end) 
* `--pg-pass-root=` - set the pg postgres user password. Default is _random_ (shown at the end)
* `--pg-pass-user=` - set the pg user password. Default is _random_ (shown at the end)
* `--no-supervisor` - don't install or configure supervisor daemon
* `--no-certbot` - don't install or configure certbot (let's encrypt)
* `--no-redis` - don't install or configure redis-server
* `--redis-pass` - set the redis master password. Default is _random_ (shown at the end)
* `--no-memcached` - don't install or configure memcached
* `--no-beanstalkd` - don't install or configure beanstalkd
* `--key-only=` - put here (with quotes) your personal ssh pubkey if you want to disable login using password. _**WARNING**: Be sure to know what you are doing._
* `--reboot` - reboot the system at the end of the script executation. Normally should **_not_** be used.

## Examples
#### Directly from you computer
##### Importing your SSH pubkey
```shell script
ssh root@YOUR.SERVER.IP.HERE "bash -c \"\$(curl -fsSL https://git.io/Jv9a6)\" \"\" --reboot --key-only=\"$(cat ~/.ssh/id_rsa.pub)\""
```
> In the above case, it is safe to use `--reboot` parameter.
### Web Server
#### with nginx & php
```shell script
bash -c "$(curl -fsSL https://git.io/Jv9a6)" "" --no-mysql --no-postgres --no-redis --no-memcached --no-beanstalkd
```
### Database Server
> UFW are not configured to allow remote ports to db or cache. You should prefer private networking.
#### with mysql
```shell script
bash -c "$(curl -fsSL https://git.io/Jv9a6)" "" --no-nginx --no-php --no-postgres --no-node --no-certbot --no-redis --no-memcached --no-beanstalkd
```
#### with postgresql
```shell script
bash -c "$(curl -fsSL https://git.io/Jv9a6)" "" --no-mysql --no-nginx --no-php --no-node --no-certbot --no-redis --no-memcached --no-beanstalkd
```
### Cache Server / Queue Server
```shell script
bash -c "$(curl -fsSL https://git.io/Jv9a6)" "" --no-mysql --no-nginx --no-php --no-node --no-postgres --no-certbot
```


## Roadmap
- [ ] Add [transfer.sh](https://transfer.sh) alias
- [X] Add Apache Server as alternative to nginx
- [ ] Configure private network
- [ ] Allow only some IPs via as parameter
- [ ] Fine tune our apps
- [ ] Make the maintenance time random
- [ ] Add mysql as alternative to MariaDB
- [ ] Add colorls
- [ ] Add zsh some plugins by default
- [ ] Add insign/server-scripts
- [X] Finish postgresql installation
- [X] Finish Certbot installation
- [X] Finish supervisord installation
- [X] Finish Redis server installation
- [X] Finish Memcached installation
- [X] Finish Beanstalkd installation
- [X] Finish fail2ban installation
- [X] Enable better gzip config for nginx by default
- [X] Import popular git services ssh keys
- [X] Generate ssh key
- [X] Import private key
- [X] Remove password login (ssh key only)
- [X] Support for multiple php versions
- [X] Install mosh as alternative of ssh
- [ ] Send report via e-mail
  - [ ] Hide report at the end
  - [ ] Run quiet installation with minimum verbosity
  - [X] Reboot after done
- [X] Count time passed during installation
- [ ] Add CI for this script.

## Contributing
You are welcome, just do a PR with some explanation.

## License
> Licensed under lgpl-3.0. Check the [GNU GPL3 License](./LICENSE) file for more details.
