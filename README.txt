#In this container image,

#The liboqs provider that enables PQ crypto algorithm is activated by default. You can use this command to test it: openssl list -providers
#Check the script.sh file to see how openssl keys are generated.
#crypto policies is updated with the TEST-PQ sub policy. To check if, you can execute this command: update-crypto-policies --show
#nginx.conf file is updated to enable TLS settings on port 443. To test it, use the following command: openssl s_client -connect localhost:443 -tls1_3
#To test OpenSSL with curl, use the following command: curl --cacert root.crt https://localhost:443/⁠
#To test the PQ algorithm with the oqs test server, use the folowing command: openssl s_client -connect test.openquantumsafe.org:6041 -trace
#Useful podman commands:

podman image list
podman build -t post-quantum-container .
podman run -it --rm post-quantum-container
podman run -it -p 8080:80 --name test localhost/post-quantum-container
Copy of my Containerfile:

FROM fedora:40

##Install the required packages

RUN sudo dnf install vim openssl nginx curl oqsprovider crypto-policies-scripts tcpdump sed -y

##Update the TEST-PQ subpolicy

RUN update-crypto-policies --set DEFAULT:TEST-PQ

COPY script.sh .

COPY README.txt .

CMD ["/bin/bash"]

Copy of my script.sh:

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
