#!/bin/bash
az account set --subscription="$SUBSCRIPTION" > /dev/null 2>&1

# Needed temporarily to unblock connectedk8s connect step. 
python -m pip install install Crypto

# enable connected cluster
az connectedk8s connect -n  "$CLUSTERNAME" -g "$RESOURCEGROUP" -l "$REGION" > /dev/null 2>&1
