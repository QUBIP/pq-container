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
