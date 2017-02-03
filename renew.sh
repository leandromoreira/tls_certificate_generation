#!/bin/bash
# Contributor: JConner <snafuxnj@yahoo.com>
#
# *************************************************************** 
TEMP=$(getopt -n $0 --long aws-zone:,aws-region:,provider:,aws-profile:,credentials-file:,aws-vpcid:,help -o r:z:R:p:C:V:h -- "$@")
CREDENTIALS_FILE=${credentials_file:-~/.aws/credentials}

# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"

usage()
{
  cat <<EOM
  Usage: $0 [--provider digitalocean] [--credentials-file </path/to/aws-credentials>] [--help]
            [--vpc-id <aws-vpc-id>] [--aws-profile <aws-profile>] [--aws-zone <a,b,c,...>]
            [--aws-region <region>]

  --provider|-r           : currently only supports digitalocean
  --credentials-file|-C   : Provide path to your .aws/credentials file.
  --vpc-id|-V             : AWS VPC ID
  --aws-profile|-p        : aws profile IE if your credentials file has multiple profiles,
                            specify the one you want to use for your credentials. Defaults
                            to "default"
  --aws-region|-r         : aws region IE us-west-2. Defaults to docker-machine default.
  --aws-zone|-z           : aws zone within the region IE a,b,c,n... Defaults to "a"
  --help|-h               : This help message.
EOM
}

get_aws_credentials()
{
  aws_creds_profile=${1:-default}

  # default to "default" in the credentials file if the
  # profile header doesn't exist in it.
  [[ $(grep -c $aws_creds_profile $CREDENTIALS_FILE) == 0 ]] && aws_creds_profile="default"

  creds=$(grep -A2 "\[$aws_creds_profile" $CREDENTIALS_FILE)

  sep_creds=$(echo $creds | \
                  perl -nw -e '
                    my($id, $key);
                    /aws_access_key_id\s+=\s+(\w+)/; $id = $1;
                    /aws_secret_access_key\s+=\s+([\w\+-_\.]+)/; $key = $1;

                    print "$id $key"')

  [[ $? == 0 ]] && EC2_AKEY=$(echo $sep_creds | awk '{print $1}') && \
                   EC2_SKEY=$(echo $sep_creds | awk '{print $2}')

  [[ -z $EC2_AKEY ]] && echo 'Unable to determine AWS credential: aws_id. Please investigate' && \
                      exit 30

  [[ -z $EC2_SKEY ]] && echo 'Unable to determine AWS credential: aws_id. Please investigate' && \
                          exit 31
}

while true
do
    case $1 in
        -C|--credentials-file)
            shift
            credentials_file=$1
        ;;
        -R|--provider)
            shift
            provider=$1
        ;;
        -p|--aws-profile)
            shift
            aws_profile=$1
        ;;
        -r|--aws-region)
            shift
            aws_region="--amazonec2-region $1"
        ;;
        -z|--aws-zone)
            shift
            aws_zone="--amazonec2-zone $1"
        ;;
        -V|--aws-vpcid)
            shift
            EC2_VPCID=$1
        ;;
        -h|--help)
            shift
            usage
            exit
        ;;
        --) break;;
        *) shift;;
    esac
done

get_aws_credentials $aws_profile

if [[ $provider == digitalocean ]]; then
  if [ -z "$DO_ATOKEN" ]; then
    echo "You must need to provide your digital ocean token DO_ATOKEN=<value>"
    exit 1
  fi
  echo "creating the temporary machine"
  docker-machine create --driver digitalocean --digitalocean-access-token=$DO_ATOKEN --digitalocean-image ubuntu-16-04-x64 renewcert
else
  [ -z "$EC2_AKEY" -o -z "$EC2_SKEY" ]   && echo "--credentials-file <path> required." && usage && exit 2
  [ -z "$EC2_VPCID" ]                    && echo "--vpc-id <VPCID> required."          && usage && exit 4
  [ -z "$aws_zone"  ]                    && aws_zone="--amazonec2-zone a"

  docker_args="$aws_region $aws_zone"
  echo "creating the temporary machine"
  set -- $docker_args

  docker-machine create --driver amazonec2 --amazonec2-access-key $EC2_AKEY --amazonec2-secret-key $EC2_SKEY --amazonec2-vpc-id $EC2_VPCID $@ renewcert
fi

echo "binding to the machine"
eval "$(docker-machine env renewcert)"

echo "building the server to renew the certificates"
docker-compose build nginx_common && docker-compose up -d nginx_common

sleep 5 # give nginx a time to be up and running
echo ""
echo ""
echo ""

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
read -p "Did you change your DNS already (point your domains to `docker-machine ip renewcert`) and wait its TTL? (y/N) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]
then
  echo "boostraping dependencies to work with letsencrypt and acquiring the certificates"
  docker exec -it `docker ps|grep nginx|cut -d' ' -f1` bash -c 'cd /opt/letsencrypt/ && ./letsencrypt-auto --config /var/www/letsencrypt/site.conf certonly --agree-tos'

  print_domains
  echo ""
  echo "Type the FIRST (full) domain you set up at 'nginx/sites-enabled/site.conf', followed by [ENTER]:"
  read first_domain

  docker cp `docker ps|grep common|cut -d " " -f 1`:/etc/letsencrypt/archive/$first_domain/privkey1.pem .
  docker cp `docker ps|grep common|cut -d " " -f 1`:/etc/letsencrypt/archive/$first_domain/fullchain1.pem .
  echo ""
  echo ""
  echo "the files privkey1 and fullchain1 were saved locally."
fi

docker-machine stop renewcert
docker-machine rm renewcert -y

