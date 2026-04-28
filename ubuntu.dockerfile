# syntax=docker.io/docker/dockerfile:1
ARG PLAT=manylinux_2_39_riscv64
ARG IMAGE=quay.io/pypa/${PLAT}:2026.02.01-1
ARG MACHINE_GUEST_TOOLS_VERSION=0.17.2
ARG MACHINE_GUEST_TOOLS_SHA=4cabfd5cfd932367a5be35fa6c18a541f9044f04c48ffcb38bea3cebf88cc6a7
ARG MACHINE_ASSET_TOOLS_VERSION=0.1.0-alpha.7
ARG MACHINE_ASSET_TOOLS_DEV_TAR=https://github.com/Mugen-Builders/machine-asset-tools/releases/download/v${MACHINE_ASSET_TOOLS_VERSION}/machine-asset-tools_glibc_riscv64_dev_v${MACHINE_ASSET_TOOLS_VERSION}.tar.gz
ARG MACHINE_ASSET_TOOLS_DEV_TAR_CHECKSUM=sha256:8b3d55ceb148bd843e1210c3be5545fb0e9074fd5b02ecc32cf8bbddc32790f5

FROM --platform=linux/riscv64 ${IMAGE} AS base

# Install guest tools
ARG MACHINE_GUEST_TOOLS_VERSION
ARG MACHINE_GUEST_TOOLS_SHA
ADD --checksum=sha256:${MACHINE_GUEST_TOOLS_SHA} \
    https://github.com/cartesi/machine-guest-tools/releases/download/v${MACHINE_GUEST_TOOLS_VERSION}/machine-guest-tools_riscv64.tar.gz \
    /tmp/machine-guest-tools_riscv64.tar.gz

ARG DEBIAN_FRONTEND=noninteractive
RUN tar zxvf /tmp/machine-guest-tools_riscv64.tar.gz -C /

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
