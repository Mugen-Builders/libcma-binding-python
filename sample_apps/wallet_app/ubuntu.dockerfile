# syntax=docker.io/docker/dockerfile:1
ARG APT_UPDATE_SNAPSHOT=20260623T000000Z
ARG MACHINE_GUEST_TOOLS_VERSION=0.18.0
ARG MACHINE_GUEST_TOOLS_SHA=sha256:fec7fad82c21e5831f2f6871686f776b0e4981af9131dcb9620f2607a0084405
ARG MACHINE_ASSET_TOOLS_VERSION=0.1.0-alpha.10
# ARG MACHINE_ASSET_TOOLS_TAR=https://github.com/Mugen-Builders/machine-asset-tools/releases/download/v${MACHINE_ASSET_TOOLS_VERSION}/machine-asset-tools_glibc_riscv64_v${MACHINE_ASSET_TOOLS_VERSION}.tar.gz
# ARG MACHINE_ASSET_TOOLS_TAR_CHECKSUM=sha256:f8ef6e1ca785c30059e58d18a5a93df2098f9d73de4b4489f477475c74f96029
ARG MACHINE_ASSET_TOOLS_DEV_TAR=https://github.com/Mugen-Builders/machine-asset-tools/releases/download/v${MACHINE_ASSET_TOOLS_VERSION}/machine-asset-tools_glibc_riscv64_dev_v${MACHINE_ASSET_TOOLS_VERSION}.tar.gz
ARG MACHINE_ASSET_TOOLS_DEV_TAR_CHECKSUM=sha256:1b8aadca40286d7a10429f0a682547af8157b0e634b1134cebfdf14d3e3faed7

ARG APP_DIR=.
ARG WALLET_APP_CONFIG=config.py
ARG INSTALL_STEP=install
ARG STATE_FILESIZE=67108864

ARG IMAGE_VERSION=3.13.2-slim-noble
#ARG IMAGE_VERSION=3.12.9-slim-noble
FROM --platform=linux/riscv64 cartesi/python:${IMAGE_VERSION} AS base

ARG APT_UPDATE_SNAPSHOT
ARG DEBIAN_FRONTEND=noninteractive
RUN <<EOF
set -eu
apt-get update
apt-get install -y --no-install-recommends ca-certificates
apt-get update --snapshot=${APT_UPDATE_SNAPSHOT}
apt-get remove -y --purge ca-certificates
apt-get autoremove -y --purge
EOF

# Install guest tools
ARG MACHINE_GUEST_TOOLS_VERSION
ADD https://github.com/cartesi/machine-guest-tools/releases/download/v${MACHINE_GUEST_TOOLS_VERSION}/machine-guest-tools_riscv64.deb /tmp/
RUN apt-get install -y --no-install-recommends /tmp/machine-guest-tools_riscv64.deb
RUN rm /tmp/machine-guest-tools_riscv64.deb

# ARG MACHINE_ASSET_TOOLS_TAR
# ARG MACHINE_ASSET_TOOLS_TAR_CHECKSUM
# ADD --checksum=${MACHINE_ASSET_TOOLS_TAR_CHECKSUM} ${MACHINE_ASSET_TOOLS_TAR} /tmp/cma.tar.gz
# RUN <<EOF
# set -e
# tar -xzf /tmp/cma.tar.gz -C /
# rm /tmp/cma.tar.gz
# EOF


FROM base AS install

WORKDIR /opt/install

ARG APP_DIR
COPY ${APP_DIR}/requirements.txt .

RUN <<EOF
set -e
pip3 install -r requirements.txt
rm requirements.txt
EOF

RUN <<EOF
set -e
find /usr/local/lib -type d -name __pycache__ -exec rm -r {} +
find . -type d -name __pycache__ -exec rm -r {} +
rm -rf /var/lib/apt/lists/* /var/log/* /var/cache/* /tmp/* /opt/install
EOF

FROM base AS builder-env

# Install g++ 14
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    g++-14 build-essential

RUN <<EOF
set -e
apt-get remove -y g++-13
update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-14 100
update-alternatives --config g++
EOF

# Install guest tools
ARG MACHINE_GUEST_TOOLS_VERSION
ARG MACHINE_GUEST_TOOLS_SHA
ADD --checksum=${MACHINE_GUEST_TOOLS_SHA} \
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

FROM builder-env AS builder

# ARG CMAPY_PROJECT=.
ADD setup.py /opt/build/.
ADD libcmt.pxd /opt/build/.
ADD libcma.pxd /opt/build/.
ADD pycma.pyx /opt/build/.

WORKDIR /opt/build

RUN pip3 wheel . -v --no-deps -w wheels/ --find-links https://prototyp3-dev.github.io/pip-wheels-riscv/wheels/

FROM base AS build-local

WORKDIR /opt/install

ARG APP_DIR
COPY ${APP_DIR}/requirements.txt .

RUN <<EOF
set -e
sed -i '/pycma/d' ./requirements.txt
pip3 install -r requirements.txt
EOF

COPY --from=builder /opt/build/wheels/ /opt/install/wheels

RUN <<EOF
set -e
pip3 install pycma --find-links /opt/install/wheels
rm requirements.txt
EOF

RUN <<EOF
set -e
find /usr/local/lib -type d -name __pycache__ -exec rm -r {} +
find . -type d -name __pycache__ -exec rm -r {} +
rm -rf /var/lib/apt/lists/* /var/log/* /var/cache/* /tmp/* /opt/install
EOF

FROM base AS install-local

WORKDIR /opt/install

ARG APP_DIR
COPY ${APP_DIR}/requirements.txt .

RUN <<EOF
set -e
sed -i '/pycma/d' ./requirements.txt
pip3 install -r requirements.txt
EOF

COPY .wheels /opt/install/wheels

RUN <<EOF
set -e
pip3 install pycma --find-links /opt/install/wheels
rm requirements.txt
EOF

RUN <<EOF
set -e
find /usr/local/lib -type d -name __pycache__ -exec rm -r {} +
find . -type d -name __pycache__ -exec rm -r {} +
rm -rf /var/lib/apt/lists/* /var/log/* /var/cache/* /tmp/* /opt/install
EOF

### Rootfs
FROM ${INSTALL_STEP} AS rootfs

FROM --platform=linux/riscv64 scratch AS app-scratch

ARG APP_DIR
ARG WALLET_APP_CONFIG
COPY ${APP_DIR}/app.py .
COPY ${APP_DIR}/${WALLET_APP_CONFIG} .

### App
FROM --platform=linux/riscv64 app-scratch AS app
