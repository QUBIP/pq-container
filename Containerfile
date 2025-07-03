# Use fully qualified name for rpm-manager
FROM quay.io/fedora/fedora:rawhide

COPY setup.sh .
RUN bash setup.sh

COPY client.expect test.sh .

CMD ["/bin/bash"]
