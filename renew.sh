#!/bin/bash

echo "creating the temporary machine"
docker-machine create --driver amazonec2 --amazonec2-access-key $EC2_AKEY --amazonec2-secret-key $EC2_SKEY --amazonec2-vpc-id $EC2_VPCID --amazonec2-zone d renewcert

echo "binding to the machine"
eval "$(docker-machine env renewcert)"

echo "building the server to renew the certificates"
docker-compose build nginx_common && docker-compose up -d nginx_common

sleep 5 # give nginx a time to be up and running
echo ""
echo "The IP you must use is : `docker-machine ip renewcert`"
echo ""
read -p "Did you change your DNS already (point your domains to `docker-machine ip renewcert`)? (y/N) " -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
  echo "boostraping dependencies to work with letsencrypt and acquiring the certificates"
  docker exec -it `docker ps|grep nginx|cut -d' ' -f1` bash -c 'cd /opt/letsencrypt/ && ./letsencrypt-auto --config /var/www/letsencrypt/site.conf certonly --agree-tos'

  echo ""
  echo "Type the FIRST (full) domain you set up at `nginx/sites-enabled/site.conf`, followed by [ENTER]:"
  read first_domain

  docker cp `docker ps|grep common|cut -d " " -f 1`:/etc/letsencrypt/archive/$first_domain/privkey1.pem .
  docker cp `docker ps|grep common|cut -d " " -f 1`:/etc/letsencrypt/archive/$first_domain/fullchain1.pem .

  docker-machine stop renewcert
  docker-machine rm renewcert -y
fi

