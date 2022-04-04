ARG base_image

FROM ${base_image}

ARG TARGETARCH
ARG TARGETOS

ENV helm_version 3.7.1

# upgrading libssl1.1 due to CVE-2021-37750
# upgrading bsdutils due to CVE-2021-3995 and CVE-2021-3996
# upgrading libc-bin due to CVE-2021-33574, CVE-2022-23218, CVE-2022-23219 and CVE-2021-43396
# upgrading libc6 due to CVE-2021-33574, CVE-2022-23218, CVE-2022-23219, and CVE-2021-43396
# upgrading libsystemd0 and libudev1 due to CVE-2021-3997
# upgrading zlib1g due to CVE-2018-25032

RUN clean-install jq curl ca-certificates libssl1.1 libgmp10 bsdutils libc-bin libc6 libsystemd0 libudev1 zlib1g

RUN curl https://get.helm.sh/helm-v${helm_version}-${TARGETOS}-${TARGETARCH}.tar.gz -o helm.tar.gz && \
    tar -xvf helm.tar.gz && \
    rm helm.tar.gz && \
    mv ${TARGETOS}-${TARGETARCH}/helm /usr/local/bin/helm && \
    chmod +x /usr/local/bin/helm
