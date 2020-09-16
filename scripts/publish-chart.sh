#!/bin/bash

export HELM_EXPERIMENTAL_OCI=1

helm chart save $CHARTPATH $REPO:$RELEASE
helm registry login $REGISTRY
helm chart push $REPO:$RELEASE
az acr repository show-manifests --name $REGISTRY --repository $REPO
