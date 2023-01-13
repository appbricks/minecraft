FROM appbricks/mycs-node:latest

ARG mc_type
ARG mc_version
ARG mc_description

COPY scripts/prepare-image.sh /tmp

RUN /tmp/prepare-image.sh
