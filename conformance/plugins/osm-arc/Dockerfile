FROM golang:1.16

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y git

RUN apt-get update && apt-get -y upgrade && \
    apt-get -f -y install curl apt-transport-https lsb-release gnupg python3-pip && \
    curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /etc/apt/trusted.gpg.d/microsoft.asc.gpg && \
    CLI_REPO=$(lsb_release -cs) && \
    echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ ${CLI_REPO} main" \
    > /etc/apt/sources.list.d/azure-cli.list && \
    apt-get update && \
    apt-get install -y azure-cli && \
    rm -rf /var/lib/apt/lists/*

RUN python3 -m pip install junit_xml

RUN go get -u github.com/jstemmer/go-junit-report

# upgrading libgssapi-krb5-2, libk5crypto3, libkrb5-3, and libkrb5support0 due to CVE-2021-37750
# upgrading linux-libc-dev due to CVE-2020-16119, CVE-2021-22543, CVE-2021-3444, and more
RUN apt-get update && apt-get -y upgrade && \ 
    apt-get install libgssapi-krb5-2 && \
    apt-get install libk5crypto3 && \
    apt-get install libkrb5-3 && \
    apt-get install libkrb5support0 && \
    apt-get install linux-libc-dev

COPY --from=lachlanevenson/k8s-kubectl:v1.20.5 /usr/local/bin/kubectl /usr/local/bin/kubectl

COPY ./osm_arc_conformance.sh /
COPY ./setup_failure_handler.py ./

RUN ["chmod", "+x", "/osm_arc_conformance.sh"]
ENTRYPOINT ["/osm_arc_conformance.sh"]
