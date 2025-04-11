# Use fully qualified name for rpm-manager
FROM quay.io/fedora/fedora:43

COPY setup.sh .
RUN bash setup.sh

COPY test.sh .

CMD ["/bin/bash"]
