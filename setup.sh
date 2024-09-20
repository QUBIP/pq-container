#!/usr/bin/env bash

set -exo pipefail

dnf -y install --no-allow-downgrade vim nginx curl openssl oqsprovider crypto-policies-scripts tcpdump sed

update-crypto-policies --set DEFAULT:TEST-PQ

sed -i '/default = default_sect/a oqsprovider = oqs_sect' /etc/pki/tls/openssl.cnf

sed -i '/activate = 1/ {
a [oqs_sect]
a activate = 1
}' /etc/pki/tls/openssl.cnf

#OpenSSL key and certificates generation

openssl ecparam -out p256.pem -name P-256

openssl req -x509 -newkey ec:p256.pem -keyout root.key -out root.crt -subj /CN=localhost -batch -nodes -days 36500 -sha256

#nginx configuration

mkdir /etc/pki/nginx

mkdir /etc/pki/nginx/private

cp root.crt /etc/pki/nginx/server.crt

cp root.key /etc/pki/nginx/private/server.key

getent passwd nginx

chown -R nginx: /etc/pki/nginx
