# syntax=docker.io/docker/dockerfile:1
ARG APT_UPDATE_SNAPSHOT=20260113T030400Z
ARG MACHINE_GUEST_TOOLS_VERSION=0.17.2-r1
ARG MACHINE_GUEST_TOOLS_SHA256SUM=c077573dbcf0cdc146adf14b480bfe454ca63aa4d3e8408c5487f550a5b77a41
ARG MACHINE_ASSET_TOOLS_VERSION=0.1.0-alpha.8
# ARG MACHINE_ASSET_TOOLS_TAR=https://github.com/Mugen-Builders/machine-asset-tools/releases/download/v${MACHINE_ASSET_TOOLS_VERSION}/machine-asset-tools_musl_riscv64_v${MACHINE_ASSET_TOOLS_VERSION}.tar.gz
# ARG MACHINE_ASSET_TOOLS_TAR_CHECKSUM=sha256:b1f124b29d560dc7e489af97f1d992596e936aff1550e7735672e0be79879253
ARG MACHINE_ASSET_TOOLS_DEV_TAR=https://github.com/Mugen-Builders/machine-asset-tools/releases/download/v${MACHINE_ASSET_TOOLS_VERSION}/machine-asset-tools_musl_riscv64_dev_v${MACHINE_ASSET_TOOLS_VERSION}.tar.gz
ARG MACHINE_ASSET_TOOLS_DEV_TAR_CHECKSUM=sha256:77af16a6fd7ba8fe0454701105a51dee5ce6f198036b6c0b8e7184982f9c0e06

ARG APP_DIR=.
ARG WALLET_APP_CONFIG=config.py
ARG INSTALL_STEP=install
ARG STATE_FILESIZE=67108864

# ARG IMAGE_VERSION=3.13.12-alpine3.22
ARG IMAGE_VERSION=3.12.13-alpine3.24
FROM --platform=linux/riscv64 riscv64/python:${IMAGE_VERSION} AS base

# Install tools
ARG MACHINE_GUEST_TOOLS_VERSION
ADD --chmod=644 https://cartesi.github.io/linux-packages/apk/keys/cartesi-apk-key.rsa.pub /etc/apk/keys/cartesi-apk-key.rsa.pub
RUN echo "https://cartesi.github.io/linux-packages/apk/stable" >> /etc/apk/repositories
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
    build-base=0.5-r4 \
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

### App
FROM --platform=linux/riscv64 app-scratch AS app
