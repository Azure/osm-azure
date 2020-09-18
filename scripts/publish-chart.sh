#!/bin/bash

export HELM_EXPERIMENTAL_OCI=1

./helm package --version $IMAGETAG --destination $IMAGEDIR $REPO --debug
oras push $REGISTRY/$CHARTNAME:$IMAGETAG ./$CHARTNAME-$IMAGETAG.tgz:application/tar+gzip --debug

az acr repository show-manifests --name $REGISTRY --repository $REPO
