#!/bin/bash

K8S_EXTENSION_VERSION="${K8S_EXTENSION_VERSION:-0.2.0}"

az account set --subscription="$SUBSCRIPTION" > /dev/null 2>&1

az extension remove --name k8s-extension

az extension add --source "$AZ_EXTENSION_LOCATION/k8s_extension-$K8S_EXTENSION_VERSION-py2.py3-none-any.whl" -y

az -v
