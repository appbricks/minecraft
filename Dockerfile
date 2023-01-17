ARG base_image
ARG mc_type
ARG mc_version
ARG mc_description

FROM $base_image
COPY scripts/prepare-image.sh /tmp
RUN /tmp/prepare-image.sh
