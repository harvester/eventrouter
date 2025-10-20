# syntax=docker/dockerfile:1.7.0

FROM registry.suse.com/bci/bci-minimal:15.7

ARG TARGETPLATFORM

RUN if [ "$TARGETPLATFORM" != "linux/amd64" ] && [ "$TARGETPLATFORM" != "linux/arm64" ]; then \
    echo "Error: Unsupported TARGETPLATFORM: $TARGETPLATFORM" && \
    exit 1; \
    fi

ENV ARCH=${TARGETPLATFORM#linux/}

COPY bin/eventrouter-${ARCH} /usr/bin/eventrouter

CMD ["eventrouter", "-v", "3", "-logtostderr"]
