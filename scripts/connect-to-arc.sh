#!/bin/bash
az account set --subscription="$SUBSCRIPTION" > /dev/null 2>&1

kubectl get pods -A
# enable connected cluster
az connectedk8s connect -n  "$CLUSTERNAME" -g "$RESOURCEGROUP" -l "$REGION" --debug
