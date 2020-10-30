#!/bin/bash

source .env

export HELM_EXPERIMENTAL_OCI=1

az account set --subscription=$SUBSCRIPTION

./helm package --version $IMAGETAG --destination $IMAGEDIR $REPO --debug
oras push $REGISTRY/$CHARTNAME:$IMAGETAG ./$CHARTNAME-$IMAGETAG.tgz:application/tar+gzip --debug

az acr repository show-manifests --name $REGISTRY --repository $REPO
