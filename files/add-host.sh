#! /bin/bash
# version: 1.2

# nginx 1.19.4+ required
# openssl 1.1.1+ required
# apt install openssl python3-certbot-nginx python3-certbot python3-acme python3-zope.interface -y

# examples:
# bash add-host.sh -h test.com
# bash add-host.sh -h test.com -t localhost:8080
# bash add-host.sh -h test.com -e www.test.com
# bash add-host.sh -h test.com -e www.test.com -t localhost:8080

set -o pipefail

while getopts "h:e:t:" option; do
    case "${option}" in
    h) HOSTNAME=${OPTARG} ;;
    e) EXTRA_HOSTNAME=${OPTARG} ;;
    t) TARGET=${OPTARG} ;;
    esac
done

CONF_DIR_PATH="/etc/nginx/conf.d"
CONF_FILE_PATH="$CONF_DIR_PATH/$HOSTNAME.conf"

SNIPPETS_DIR_PATH="/etc/nginx/snippets"
HTTPS_CONFIG_PATH="$SNIPPETS_DIR_PATH/https.conf"

function print_success() {
    printf '%s# %s%s\n' "$(printf '\033[32m')" "$*" "$(printf '\033[m')" >&2
}

function print_warning() {
    printf '%sWARNING: %s%s\n' "$(printf '\033[31m')" "$*" "$(printf '\033[m')" >&2
}

function print_error() {
    printf '%sERROR: %s%s\n' "$(printf '\033[31m')" "$*" "$(printf '\033[m')" >&2
    exit 1
}

function get_keypress() {
    local REPLY IFS=
    printf >/dev/tty '%s' "$*"
    [[ $ZSH_VERSION ]] && read -rk1
    [[ $BASH_VERSION ]] && read </dev/tty -rn1
    printf '%s' "$REPLY"
}

function confirm() {
    local prompt="${1:-Are you sure?} [y/n] "
    local enter_return=$2
    local REPLY
    while REPLY=$(get_keypress "$prompt"); do
        [[ $REPLY ]] && printf '\n'
        case "$REPLY" in
        Y | y) return 0 ;;
        N | n) return 1 ;;
        '') [[ $enter_return ]] && return "$enter_return" ;;
        esac
    done
}

function generate_https_config() {
    local CERTS_DIR_PATH="/etc/ssl/certs"
    local DH_PARAM_PATH="$CERTS_DIR_PATH/dhparam.pem"
    local DH_PARAM_SIZE="2048"

    mkdir -p $CERTS_DIR_PATH
    mkdir -p $SNIPPETS_DIR_PATH

    [ ! -r "$DH_PARAM_PATH" ] && openssl dhparam -out $DH_PARAM_PATH $DH_PARAM_SIZE

    echo "ssl_protocols TLSv1.3 TLSv1.2;
    ssl_dhparam $DH_PARAM_PATH;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_ecdh_curve secp384r1;
    ssl_session_cache shared:SSL:10m;
    ssl_session_tickets off;
    ssl_session_timeout 1d;
    ssl_stapling on;
    ssl_stapling_verify on;

    resolver 1.1.1.1 8.8.8.8 valid=300s;
    resolver_timeout 5s;
    " | sed 's/^[ \t]*//' >$HTTPS_CONFIG_PATH
}

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
    print_warning "File already exist: $CONF_FILE_PATH"
    confirm "Whether to replace file?" && rm -rf $CONF_FILE_PATH || print_error "exit"
fi

if [ ! -r "$HTTPS_CONFIG_PATH" ]; then
    print_warning "File does not exist: $HTTPS_CONFIG_PATH"
    confirm "Whether to generate HTTPS config?" && generate_https_config || print_error "exit"
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
    certbot --agree-tos --no-eff-email --authenticator nginx --installer null --keep-until-expiring \
        --register-unsafely-without-email -d $HOSTNAME
else
    certbot --agree-tos --no-eff-email --authenticator nginx --installer null --keep-until-expiring \
        --register-unsafely-without-email -d $HOSTNAME -d $EXTRA_HOSTNAME
fi

echo 'server {
    listen 80;

    server_name NGINX_HOSTNAME;

    return 301 https://$host$request_uri;

}

server {
    listen 443 ssl http2;

    server_name NGINX_HOSTNAME;

    include HTTPS_CONFIG_PATH;

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
sed -i "s,HTTPS_CONFIG_PATH,$HTTPS_CONFIG_PATH,g" $CONF_FILE_PATH

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
