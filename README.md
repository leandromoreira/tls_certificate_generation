[![license](https://img.shields.io/badge/license-BSD--3--Clause-blue.svg)](https://img.shields.io/badge/license-BSD--3--Clause-blue.svg)

# Create / Renew [letsencrypt](https://letsencrypt.org) certificates using temporary [Amazon EC2](https://aws.amazon.com/ec2/) / [Digital Ocean](https://www.digitalocean.com/) machines  #

### Steps ###

* Make sure you have docker installed
* Configure your domains / email at `nginx/sites-enabled/site.conf`
* For AWS usage
  * Run `EC2_AKEY=xxx EC2_SKEY=yyy EC2_VPCID=kkk ./renew.sh` and follow the steps (like configuring DNS and etc)
* For DO usage
  * Run `DO_ATOKEN=xxx ./renew.sh digitalocean` and follow the steps (like configuring DNS and etc)
* Get the certificates `privkey1.pem` and `fullchain1.pem`.

### Bonus round ###

You can also transfer the downloaded certificates to your site, there is an opinionated script `upload_certs_on_nginx`.

* Make sure you have bound to your docker machine already (ex:`eval "$(docker-machine --storage-path /usr/local/share/web/docker_machines/ env mysite)"`)
* Double check the content of `upload_certs_on_nginx`, it assumes: container name, certificate path and others.
