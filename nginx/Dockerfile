FROM nginx:stable
RUN apt-get update \
 && apt-get install -y -q --no-install-recommends \
    ca-certificates \
    wget \
    git \
    vim \
 && apt-get clean \
 && rm -r /var/lib/apt/lists/*
COPY sites-enabled/nginx.conf /etc/nginx/nginx.conf

# to renew certificates
RUN git clone --depth 1 https://github.com/letsencrypt/letsencrypt /opt/letsencrypt
RUN mkdir -p /var/www/letsencrypt
COPY sites-enabled/site.conf /var/www/letsencrypt/site.conf
