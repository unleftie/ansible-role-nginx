#! /bin/bash
# version: 1.0

# examples:
# bash add-host.sh -h test.com
# bash add-host.sh -h test.com -t localhost:8080
# bash add-host.sh -h test.com -e www.test.com
# bash add-host.sh -h test.com -e www.test.com -t localhost:8080

set -o pipefail

print_success() {
    printf '%s# %s%s\n' "$(printf '\033[32m')" "$*" "$(printf '\033[m')" >&2
}

print_error() {
    printf '%sERROR: %s%s\n' "$(printf '\033[31m')" "$*" "$(printf '\033[m')" >&2
    exit 1
}

while getopts "h:e:t:" option; do
    case "${option}" in
    h) HOSTNAME=${OPTARG} ;;
    e) EXTRA_HOSTNAME=${OPTARG} ;;
    t) TARGET=${OPTARG} ;;
    esac
done

CONF_DIR_PATH="/etc/nginx/conf.d"
CONF_FILE_PATH="$CONF_DIR_PATH/$HOSTNAME.conf"
HTTPS_INCLUDE_PATH="/etc/nginx/includes/https.include"

if [ ! -d "$CONF_DIR_PATH" ]; then
    print_error "Directory for configs does not exist: $CONF_DIR_PATH"
fi

if [ -z "$HOSTNAME" ]; then
    print_error "Not enough arguments: [-h HOSTNAME]"
fi

if [[ $HOSTNAME == *"http://"* ]] || [[ $HOSTNAME == *"https://"* ]]; then
    print_error "Do not use 'http://' or 'https://' in variable: [-h HOSTNAME]"
fi

if [[ $EXTRA_HOSTNAME == *"http://"* ]] || [[ $EXTRA_HOSTNAME == *"https://"* ]]; then
    print_error "Do not use 'http://' or 'https://' in variable: [-e EXTRA_HOSTNAME]"
fi

if [[ $TARGET == *"http://"* ]] || [[ $TARGET == *"https://"* ]]; then
    print_error "Do not use 'http://' or 'https://' in variable: [-t TARGET]"
fi

if [ -r "$CONF_FILE_PATH" ]; then
    print_error "File already exist: $CONF_FILE_PATH"
fi

if [ ! -r "$HTTPS_INCLUDE_PATH" ]; then
    print_error "File does not exist: $HTTPS_INCLUDE_PATH"
fi

if [ -z "$EXTRA_HOSTNAME" ]; then
    NGINX_HOSTNAME="$HOSTNAME"
else
    NGINX_HOSTNAME="$HOSTNAME $EXTRA_HOSTNAME"
fi

echo 'server {
    listen 80;

    server_name NGINX_HOSTNAME;

    location / {
        try_files $uri $uri/ =403;
    }
}
' >$CONF_FILE_PATH

sed -i "s,NGINX_HOSTNAME,$NGINX_HOSTNAME,g" $CONF_FILE_PATH

if nginx -t 2>/dev/null; then
    nginx -s reload 2>/dev/null
else
    rm -rf $CONF_FILE_PATH
    nginx -s reload 2>/dev/null
    print_error "Something wrong with config"
fi

if [ -z "$EXTRA_HOSTNAME" ]; then
    certbot --agree-tos --no-eff-email --authenticator nginx --installer null --keep-until-expiring -d $HOSTNAME
else
    certbot --agree-tos --no-eff-email --authenticator nginx --installer null --keep-until-expiring -d $HOSTNAME -d $EXTRA_HOSTNAME
fi

echo 'server {
    listen 80;

    server_name NGINX_HOSTNAME;

    return 301 https://$host$request_uri;

}

server {
    listen 443 ssl http2;

    server_name NGINX_HOSTNAME;

    include HTTPS_INCLUDE_PATH;

    ssl_certificate /etc/letsencrypt/live/HOSTNAME/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/HOSTNAME/privkey.pem;

    location / {
        proxy_set_header Host $http_host;
        proxy_pass http://TARGET;
    }
}
' >$CONF_FILE_PATH

sed -i "s,NGINX_HOSTNAME,$NGINX_HOSTNAME,g" $CONF_FILE_PATH
sed -i "s,HOSTNAME,$HOSTNAME,g" $CONF_FILE_PATH
sed -i "s,HTTPS_INCLUDE_PATH,$HTTPS_INCLUDE_PATH,g" $CONF_FILE_PATH

if [ -z "$TARGET" ]; then
    sed -i "s,proxy_pass http://TARGET,return 403,g" $CONF_FILE_PATH
else
    sed -i "s,TARGET,$TARGET,g" $CONF_FILE_PATH
fi

if nginx -t 2>/dev/null; then
    nginx -s reload 2>/dev/null
else
    rm -rf $CONF_FILE_PATH
    nginx -s reload 2>/dev/null
    print_error "Something wrong with config"
fi

print_success "Config file path: $CONF_FILE_PATH"
print_success "Hostname: https://$HOSTNAME"

if [ ! -z "$EXTRA_HOSTNAME" ]; then
    print_success "Hostname: https://$EXTRA_HOSTNAME"
fi
