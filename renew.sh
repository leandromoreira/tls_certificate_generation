#!/bin/bash

provider="$1"

if [[ $provider == digitalocean ]]; then
  if [ -z "$DO_ATOKEN" ]; then
    echo "You must need to provide your digital ocean token DO_ATOKEN=<value>"
    exit 1
  fi
  echo "creating the temporary machine"
  docker-machine create --driver digitalocean --digitalocean-access-token=$DO_ATOKEN renewcert
else
  if [ -z "$EC2_AKEY" ]; then
    echo "You must need to provide your amazon access key EC2_AKEY=<value>"
    exit 1
  fi
  if [ -z "$EC2_SKEY" ]; then
    echo "You must need to provide your amazon secret key EC2_SKEY=<value>"
    exit 1
  fi
  if [ -z "$EC2_VPCID" ]; then
    echo "You must need to provide your amazon vpc id EC2_VPCID=<value>"
    exit 1
  fi
  echo "creating the temporary machine"
  docker-machine create --driver amazonec2 --amazonec2-access-key $EC2_AKEY --amazonec2-secret-key $EC2_SKEY --amazonec2-vpc-id $EC2_VPCID --amazonec2-zone d renewcert
fi

echo "binding to the machine"
eval "$(docker-machine env renewcert)"

echo "building the server to renew the certificates"
docker-compose build nginx_common && docker-compose up -d nginx_common

sleep 5 # give nginx a time to be up and running
echo ""
echo ""
echo ""
echo "======================================================"
echo "The IP you must use is : `docker-machine ip renewcert`"
echo "======================================================"

pylookup() {
  python -c 'import socket, sys; print socket.gethostbyname(sys.argv[1])' "$@" 2>/dev/null
}

print_domains() {
  echo "======================================================"
  echo "The IP you must use is : `docker-machine ip renewcert`"
  echo "======================================================"
  for domain in $(cat nginx/sites-enabled/site.conf|grep domains|grep =|cut -d "=" -f 2)
  do
    address=$(pylookup $domain)
    echo "$domain ($address)"
  done
  echo "======================================================"
  echo "The IP you must use is : `docker-machine ip renewcert`"
  echo "======================================================"
}

print_domains

echo ""
read -p "Did you change your DNS already (point your domains to `docker-machine ip renewcert`) a wait its TTL? (y/N) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]
then
  echo "boostraping dependencies to work with letsencrypt and acquiring the certificates"
  docker exec -it `docker ps|grep nginx|cut -d' ' -f1` bash -c 'cd /opt/letsencrypt/ && ./letsencrypt-auto --config /var/www/letsencrypt/site.conf certonly --agree-tos'

  print_domains
  echo ""
  echo "Type the FIRST (full) domain you set up at `nginx/sites-enabled/site.conf`, followed by [ENTER]:"
  read first_domain

  docker cp `docker ps|grep common|cut -d " " -f 1`:/etc/letsencrypt/archive/$first_domain/privkey1.pem .
  docker cp `docker ps|grep common|cut -d " " -f 1`:/etc/letsencrypt/archive/$first_domain/fullchain1.pem .
  echo ""
  echo ""
  echo "the files privkey1 and fullchain1 were saved locally."
fi

docker-machine stop renewcert
docker-machine rm renewcert -y

