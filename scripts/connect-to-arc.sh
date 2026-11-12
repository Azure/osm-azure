#!/bin/bash
az account set --subscription="$SUBSCRIPTION" 2>&1

# enable connected cluster
az connectedk8s connect -n "$CLUSTERNAME" -g "$RESOURCEGROUP" -l "$REGION" 2>&1
