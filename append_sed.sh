#!/bin/sh
sed -i '/activate = 1/ {
a [oqs_sect]
a activate = 1
}' /etc/pki/tls/openssl.cnf

