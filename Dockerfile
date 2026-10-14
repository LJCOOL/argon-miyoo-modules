FROM --platform=linux/amd64 docker.io/library/ubuntu:22.04@sha256:5ec03bb3441e8b0bf3b4f9cd4629a1ae763010dc3035bb8da3ae6cf026486401
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential bc bison flex libssl-dev python2 python3 curl ca-certificates xz-utils file \
    && rm -rf /var/lib/apt/lists/* && ln -s /usr/bin/python2 /usr/local/bin/python
COPY inputs.json build-module.sh /module/
COPY modules/early/ /module/
ENTRYPOINT ["/bin/sh", "/module/build-module.sh"]
