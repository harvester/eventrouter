# syntax=docker/dockerfile:1
# check=skip=InvalidDefaultArgInFrom

FROM registry.suse.com/bci/golang:1.26.0 AS builder

ARG MK_HOST_ARCH
ENV ARCH=$MK_HOST_ARCH
ENV GOTOOLCHAIN=auto

RUN zypper -n rm container-suseconnect 2>/dev/null || true && \
    zypper -n install git curl gzip tar wget awk

# Copy golangci-lint binary from a multi-arch digest, zero-trust
COPY --from=golangci/golangci-lint:v2.12.2-alpine@sha256:91b27804074a0bacea298707f016911e60cf0cdbc6c7bf5ccacb5f0606d18d60 /usr/bin/golangci-lint /usr/local/bin/golangci-lint

ENV HOME=/go/src/github.com/heptiolabs/eventrouter


# ---- base ----
FROM builder AS base
WORKDIR /go/src/github.com/heptiolabs/eventrouter

# to exclude some files, add them in .dockerignore
COPY . .


# ---- build ----
FROM base AS build
ARG MK_REPO_ID

RUN --mount=type=cache,target=/go/pkg/mod,id=eventrouter-go-mod-${MK_REPO_ID} \
    --mount=type=cache,target=/go/src/github.com/heptiolabs/eventrouter/.cache/go-build,id=eventrouter-go-build-${MK_REPO_ID} \
    ./scripts/build

FROM scratch AS build-output
COPY --from=build /go/src/github.com/heptiolabs/eventrouter/bin/ /bin/


# ---- validate ----
FROM base AS validate
ARG MK_REPO_ID

RUN --mount=type=cache,target=/go/pkg/mod,id=eventrouter-go-mod-${MK_REPO_ID} \
    --mount=type=cache,target=/go/src/github.com/heptiolabs/eventrouter/.cache/go-build,id=eventrouter-go-build-${MK_REPO_ID} \
    ./scripts/validate


# ---- test ----
FROM base AS test
ARG MK_REPO_ID

RUN --mount=type=cache,target=/go/pkg/mod,id=eventrouter-go-mod-${MK_REPO_ID} \
    --mount=type=cache,target=/go/src/github.com/heptiolabs/eventrouter/.cache/go-build,id=eventrouter-go-build-${MK_REPO_ID} \
    ./scripts/test
