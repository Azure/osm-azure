#!/bin/bash

az account set --subscription="$SUBSCRIPTION" > /dev/null 2>&1

az extension remove --name k8s-extension

az extension add --name k8s-extension

az -v
