#!/bin/bash

CONNECTEDK8S_VERSION="${CONNECTEDK8S_VERSION:-0.3.5}"

az account set --subscription="$SUBSCRIPTION" > /dev/null 2>&1

az extension remove --name connectedk8s

az extension add --source "$AZ_EXTENSION_LOCATION/connectedk8s-$CONNECTEDK8S_VERSION-py2.py3-none-any.whl" -y

az -v
