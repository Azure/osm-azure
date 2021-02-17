#!/bin/bash
az account set --subscription=$SUBSCRIPTION > /dev/null 2>&1

az -v 

# enable connected cluster
az connectedk8s connect -n  $CLUSTERNAME -g $RESOURCEGROUP -l $REGION > /dev/null 2>&1
