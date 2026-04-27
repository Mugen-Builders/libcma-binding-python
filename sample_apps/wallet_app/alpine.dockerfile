# syntax=docker.io/docker/dockerfile:1
ARG APT_UPDATE_SNAPSHOT=20260113T030400Z
ARG MACHINE_GUEST_TOOLS_VERSION=0.17.1-r1
ARG MACHINE_GUEST_TOOLS_SHA256SUM=c077573dbcf0cdc146adf14b480bfe454ca63aa4d3e8408c5487f550a5b77a41
ARG MACHINE_ASSET_TOOLS_VERSION=0.1.0-alpha.7
ARG MACHINE_ASSET_TOOLS_TAR=https://github.com/Mugen-Builders/machine-asset-tools/releases/download/v${MACHINE_ASSET_TOOLS_VERSION}/machine-asset-tools_musl_riscv64_v${MACHINE_ASSET_TOOLS_VERSION}.tar.gz
ARG MACHINE_ASSET_TOOLS_TAR_CHECKSUM=sha256:8c8b228c07fa822e63743c58307e28fe84adcfaff75663b6d341a44e6f797e54
ARG MACHINE_ASSET_TOOLS_DEV_TAR=https://github.com/Mugen-Builders/machine-asset-tools/releases/download/v${MACHINE_ASSET_TOOLS_VERSION}/machine-asset-tools_musl_riscv64_dev_v${MACHINE_ASSET_TOOLS_VERSION}.tar.gz
ARG MACHINE_ASSET_TOOLS_DEV_TAR_CHECKSUM=sha256:63a7de3880e5695f86c6598bc53e4ee4924902436f90252d78b7798a5501ded5

ARG APP_DIR=.
ARG WALLET_APP_CONFIG=config.py
ARG INSTALL_STEP=install
ARG STATE_FILESIZE=67108864

# ARG IMAGE_VERSION=3.13.12-alpine3.22
ARG IMAGE_VERSION=3.12.12-alpine3.22
FROM --platform=linux/riscv64 riscv64/python:${IMAGE_VERSION} AS base

# Install tools
ARG MACHINE_GUEST_TOOLS_VERSION
ADD --chmod=644 https://edubart.github.io/linux-packages/apk/keys/cartesi-apk-key.rsa.pub /etc/apk/keys/cartesi-apk-key.rsa.pub
RUN echo "https://edubart.github.io/linux-packages/apk/stable" >> /etc/apk/repositories
RUN apk update && apk add cartesi-machine-guest-tools=$MACHINE_GUEST_TOOLS_VERSION

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

ARG MACHINE_GUEST_TOOLS_VERSION
RUN <<EOF
set -e
apk update
apk add \
    build-base=0.5-r3 \
    cartesi-machine-guest-libcmt-dev=${MACHINE_GUEST_TOOLS_VERSION}
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
