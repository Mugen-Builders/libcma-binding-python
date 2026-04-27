# syntax=docker.io/docker/dockerfile:1
ARG APT_UPDATE_SNAPSHOT=20260113T030400Z
ARG MACHINE_GUEST_TOOLS_VERSION=0.17.2
ARG MACHINE_GUEST_TOOLS_SHA256SUM=c077573dbcf0cdc146adf14b480bfe454ca63aa4d3e8408c5487f550a5b77a41
ARG MACHINE_ASSET_TOOLS_VERSION=0.1.0-alpha.7
ARG MACHINE_ASSET_TOOLS_TAR=https://github.com/Mugen-Builders/machine-asset-tools/releases/download/v${MACHINE_ASSET_TOOLS_VERSION}/machine-asset-tools_glibc_riscv64_v${MACHINE_ASSET_TOOLS_VERSION}.tar.gz
ARG MACHINE_ASSET_TOOLS_TAR_CHECKSUM=sha256:639fc0915b5551eab8c2e91b3216e248cd94e546eca9dd50ba230a431e9c4e85
ARG MACHINE_ASSET_TOOLS_DEV_TAR=https://github.com/Mugen-Builders/machine-asset-tools/releases/download/v${MACHINE_ASSET_TOOLS_VERSION}/machine-asset-tools_glibc_riscv64_dev_v${MACHINE_ASSET_TOOLS_VERSION}.tar.gz
ARG MACHINE_ASSET_TOOLS_DEV_TAR_CHECKSUM=sha256:8b3d55ceb148bd843e1210c3be5545fb0e9074fd5b02ecc32cf8bbddc32790f5

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
ARG MACHINE_GUEST_TOOLS_SHA256SUM
ADD --checksum=sha256:${MACHINE_GUEST_TOOLS_SHA256SUM} \
    https://github.com/cartesi/machine-guest-tools/releases/download/v${MACHINE_GUEST_TOOLS_VERSION}/machine-guest-tools_riscv64.deb \
    /tmp/machine-guest-tools_riscv64.deb

ARG DEBIAN_FRONTEND=noninteractive
RUN <<EOF
set -e
apt-get install -y --no-install-recommends \
  busybox-static \
  /tmp/machine-guest-tools_riscv64.deb

rm /tmp/machine-guest-tools_riscv64.deb
EOF

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

FROM base AS builder

RUN <<EOF
set -e
apt-get install -y --no-install-recommends \
    build-essential gcc libc6-dev
EOF

ARG MACHINE_ASSET_TOOLS_DEV_TAR
ARG MACHINE_ASSET_TOOLS_DEV_TAR_CHECKSUM
ADD --checksum=${MACHINE_ASSET_TOOLS_DEV_TAR_CHECKSUM} ${MACHINE_ASSET_TOOLS_DEV_TAR} /tmp/cma.tar.gz
RUN <<EOF
set -e
tar -xzf /tmp/cma.tar.gz -C /
rm /tmp/cma.tar.gz
EOF

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

### Rootfs
FROM ${INSTALL_STEP} AS rootfs

FROM --platform=linux/riscv64 scratch AS app-scratch

ARG APP_DIR
ARG WALLET_APP_CONFIG
COPY ${APP_DIR}/app.py .
COPY ${APP_DIR}/${WALLET_APP_CONFIG} .

### State
FROM --platform=linux/riscv64 rootfs AS state-builder

COPY --from=app-scratch / /opt/cartesi/app

WORKDIR /opt/cartesi/app/data

ARG STATE_FILESIZE
RUN dd if=/dev/zero of=/opt/cartesi/app/data/state.bin count=1 bs=1 seek=$((${STATE_FILESIZE} - 1))

RUN /usr/local/bin/python3 /opt/cartesi/app/app.py /opt/cartesi/app/data/state.bin 1

FROM --platform=linux/riscv64 scratch AS state

COPY --from=state-builder /opt/cartesi/app/data/state.bin /

### App
FROM --platform=linux/riscv64 app-scratch AS app
