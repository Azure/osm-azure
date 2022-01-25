ARG base_image

FROM ${base_image}

ARG TARGETARCH
ARG TARGETOS

ENV helm_version 3.7.1

# upgrading libssl1.1, libgssapi-krb5-2, libk5crypto3 libkrb5-3, and libkrb5support0 due to CVE-2021-37750
# upgrading bsdutils due to CVE-2021-3995 and CVE-2021-3996
RUN clean-install jq curl ca-certificates libssl1.1 libgssapi-krb5-2 libk5crypto3 libkrb5-3 libkrb5support0 libgmp10 bsdutils

RUN curl https://get.helm.sh/helm-v${helm_version}-${TARGETOS}-${TARGETARCH}.tar.gz -o helm.tar.gz && \
    tar -xvf helm.tar.gz && \
    rm helm.tar.gz && \
    mv ${TARGETOS}-${TARGETARCH}/helm /usr/local/bin/helm && \
    chmod +x /usr/local/bin/helm
