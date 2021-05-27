#!/bin/bash

az account set --subscription="$SUBSCRIPTION" > /dev/null 2>&1

az extension remove --name connectedk8s

az extension add --name connectedk8s

az -v
