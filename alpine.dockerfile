# syntax=docker.io/docker/dockerfile:1
ARG PLAT=musllinux_1_2_riscv64
ARG IMAGE=quay.io/pypa/${PLAT}:2026.02.01-1
ARG MACHINE_GUEST_TOOLS_VERSION=0.17.1-r1
ARG MACHINE_ASSET_TOOLS_VERSION=0.1.0-alpha.7
ARG MACHINE_ASSET_TOOLS_DEV_TAR=https://github.com/Mugen-Builders/machine-asset-tools/releases/download/v${MACHINE_ASSET_TOOLS_VERSION}/machine-asset-tools_musl_riscv64_dev_v${MACHINE_ASSET_TOOLS_VERSION}.tar.gz
ARG MACHINE_ASSET_TOOLS_DEV_TAR_CHECKSUM=sha256:63a7de3880e5695f86c6598bc53e4ee4924902436f90252d78b7798a5501ded5

FROM --platform=linux/riscv64 ${IMAGE} AS base

# Install guest tools
ARG MACHINE_GUEST_TOOLS_VERSION
ADD --chmod=644 https://edubart.github.io/linux-packages/apk/keys/cartesi-apk-key.rsa.pub /etc/apk/keys/cartesi-apk-key.rsa.pub
RUN echo "https://edubart.github.io/linux-packages/apk/stable" >> /etc/apk/repositories
RUN apk update && \
    apk add cartesi-machine-guest-tools=${MACHINE_GUEST_TOOLS_VERSION} \
    cartesi-machine-guest-libcmt-dev=${MACHINE_GUEST_TOOLS_VERSION} \
    build-base=0.5-r3

ARG MACHINE_ASSET_TOOLS_DEV_TAR
ARG MACHINE_ASSET_TOOLS_DEV_TAR_CHECKSUM
ADD --checksum=${MACHINE_ASSET_TOOLS_DEV_TAR_CHECKSUM} ${MACHINE_ASSET_TOOLS_DEV_TAR} /tmp/cma.tar.gz
RUN <<EOF
set -e
tar -xzf /tmp/cma.tar.gz -C /
rm /tmp/cma.tar.gz
EOF

FROM base AS builder

ADD setup.py /opt/build/.
ADD libcmt.pxd /opt/build/.
ADD libcma.pxd /opt/build/.
ADD pycma.pyx /opt/build/.

RUN sed -i 's#pycmt>=#pycmt@git+https://github.com/Mugen-Builders/libcmt-binding-python@v#' /opt/build/setup.py

ARG PLAT
ENV PLAT=${PLAT}

WORKDIR /opt/build

# RUN /opt/build/build_wheels.sh
