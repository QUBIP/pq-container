# QUBIP Fedora Reference Container Image

This container image provides a reference environment based on Fedora rawhide
with the correct configuration changes to enable post-quantum cryptography.

## Using the containers

Pre-built versions of this container image are available from
[quay.io](https://quay.io/repository/qubip/pq-container?tab=info). To use
these, you will need a container runtime, e.g., `podman` on Linux or [Podman
Desktop](https://podman-desktop.io/).

To download the pre-built container image using `podman`, use

```sh
podman pull quay.io/qubip/pq-container:latest
```

To run the container, use

```sh
podman run \
	--rm \
	-it \
	quay.io/qubip/pq-container
```

## Things to test in the container

The following is a list of items to test inside the container to show that it
has been configured for post-quantum cryptography.

### Listing the enabled OpenSSL Providers

```sh
openssl list -providers
```

will list the OpenSSL OQS Provider, which uses liboqs to offer post-quantum
cryptography for OpenSSL.
Note: oqsprovider cannot be installed in Fedora versions that are greater than 42.
F43 (and rawhide) has OpenSSL 3.5 which supports native implementation of PQ algorithms.
Therefore oqsprovider is not needed anymore.
However, it doesn't yet support hybrid signatures.
Since QUBIP requires that we support hybrid signatures, we are still using F42.

### Showing the active system-wide cryptographic policy

Fedora provides a global configuration mechanism for all its cryptographic
libraries called `crypto-policies`. The `crypto-policies` package in Fedora has
a policy module that enables post-quantum cryptography called `TEST-PQ`.

It is already enabled in the container. You can verify this by running

```sh
update-crypto-policies --show
```

which will return `DEFAULT:TEST-PQ`. If the `TEST-PQ` policy module is not
enabled, it can be by running

```sh
update-crypto-policies --set DEFAULT:TEST-PQ
```

### Connecting using ML-KEM key exchange to openquantumsafe.org

To connect to openquantumsafe.org's test server using post-quantum cryptography
for the key exchange, use the `s_client` OpenSSL command:

```sh
openssl s_client \
	-connect test.openquantumsafe.org:6041 \
	-trace
```

### Connecting to PQC-enabled nginx webserver running in the container

An instance of the nginx webserver is configured to use post-quantum
cryptography key exchange in the container and will listen on port 443.

First, you need to start it by running

```sh
/usr/sbin/nginx
```

Next, you can use OpenSSL's `s_client` to connect to it:

```sh
openssl s_client \
	-CAfile root.crt \
	-tls1_3 \
	-trace \
	-connect localhost:443
```

To test OpenSSL with `curl`, use the following command:

```sh
curl \
	--cacert root.crt \
	https://localhost/
```

## Building the container

To build the container on your local system, you can use `podman build`. Make
sure that your current working directory contains the `Containerfile` when
running this.

```sh
podman build -t pq-container .
```

Podman prefixes the names of all locally built containers with `localhost/`, so
to run this container after building it, use

```sh
podman run \
	--rm \
	-it \
	localhost/pq-container
```

## Replicating the container's setup on Fedora rawhide

The setup inside of the container can also be replicated manually on any Fedora
rawhide installation by following the steps below:

1. Install the required packages:  
   ```sh
   sudo dnf install openssl curl oqsprovider crytpo-policies-scripts sed
   ```
2. Switch the system-wide cryptographic policy to include the `TEST-PQ` policy
   module, which enables post-quantum algorithms:  
   ```sh
   sudo update-crypto-policies --set DEFAULT:TEST-PQ
   ```
3. Enable the OpenSSL OQS Provider:  
   ```sh
	sudo sed -i '/default = default_sect/a oqsprovider = oqs_sect' /etc/pki/tls/openssl.cnf

	sudo sed -i '/activate = 1/ {
	a [oqs_sect]
	a activate = 1
	}' /etc/pki/tls/openssl.cnf
   ```

This enables key exchange with post-quantum cryptography in TLS in both clients
and servers that use OpenSSL.
