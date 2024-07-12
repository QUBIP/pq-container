FROM fedora:rawhide
# Install the required packages
RUN sudo dnf install vim openssl nginx curl oqsprovider crypto-policies-scripts tcpdump sed -y
# Update the TEST-PQ subpolicy
RUN update-crypto-policies --set DEFAULT:TEST-PQ
# Patch crypto-policies to not support KYBER768
#RUN sed -i 's/KYBER768//' /etc/crypto-policies/state/CURRENT.pol
# Activate the oqsprovider
RUN sed -i '/default = default_sect/a oqsprovider = oqs_sect' /etc/pki/tls/openssl.cnf
COPY append_sed.sh /tmp/append_sed.sh
RUN chmod +x /tmp/append_sed.sh
RUN /tmp/append_sed.sh
# Copy useful commmands
COPY script.sh .
# Copy README into the container
COPY README.txt .
# Run bash in the container
CMD ["/bin/bash"]

