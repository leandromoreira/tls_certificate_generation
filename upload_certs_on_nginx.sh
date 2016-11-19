#!/bin/bash
set -e

pattern=nginx
container_id=`docker ps|grep $pattern|cut -d' ' -f1`

print_certificates() {
  echo "========== current certificates ============="
  docker exec -it $container_id bash -c 'ls -lah /etc/nginx/conf.d/fullchain.pem'
  docker exec -it $container_id bash -c 'ls -lah /etc/nginx/conf.d/privkey.pem'
  echo "========== current certificates ============="
}

print_certificates

echo "========== copying certificates to container ============="
docker cp ./privkey1.pem $container_id:/etc/nginx/conf.d/privkey.pem
docker cp ./fullchain1.pem $container_id:/etc/nginx/conf.d/fullchain.pem
echo "========== done ============="

print_certificates

echo "reloading nginx"
docker exec -it $container_id bash -c 'nginx -s reload'
echo "the new certificates were transfered"

