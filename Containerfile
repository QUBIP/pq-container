FROM fedora:41

COPY setup.sh .
RUN bash setup.sh

COPY test.sh .

CMD ["/bin/bash"]
