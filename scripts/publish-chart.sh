#!/bin/bash

export HELM_EXPERIMENTAL_OCI=1

helm package ./$CHARTNAME --app-version latest
oras push $REGISTRY/$CHARTNAME:$IMAGETAG ./$CHARTNAME-$IMAGETAG.tgz:application/tar+gzip --debug

az acr repository show-manifests --name $REGISTRY --repository $REPO
