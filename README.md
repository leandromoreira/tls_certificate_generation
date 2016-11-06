# Renew or create let's encrypt certificates using temporary AWS machines #

### Steps ###

* Make sure you have docker installed
* Configure your domains at `nginx/sites-enabled/site.conf`
* Edit the nginx to your domains at `nginx/sites-enabled/nginx.conf`
* Run `EC2_AKEY=xxx EC2_SKEY=yyy EC2_VPCID=kkk ./renew.sh` and follow the steps (like configuring DNS and etc)
* Get the certificates `privkey1.pem` and `fullchain1.pem`.
