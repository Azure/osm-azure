#!/bin/bash

set -x
set -e

results_dir="${RESULTS_DIR:-/tmp/sonobuoy/results}"

function waitForResources {
    available=false
    max_retries=60
    sleep_seconds=10
    RESOURCE=$1
    NAMESPACE=$2
    for i in $(seq 1 $max_retries)
    do
    if [[ ! $(kubectl wait --for=condition=available ${RESOURCE} --all --namespace ${NAMESPACE}) ]]; then
        sleep ${sleep_seconds}
    else
        available=true
        break
    fi
    done
    
    echo "$available"
}

# saveResults prepares the results for handoff to the Sonobuoy worker.
# See: https://github.com/vmware-tanzu/sonobuoy/blob/master/docs/plugins.md
saveResults() {
  cd ${results_dir}

    # Sonobuoy worker expects a tar file.
	tar czf results.tar.gz *

	# Signal to the worker that we are done and where to find the results.
	printf ${results_dir}/results.tar.gz > ${results_dir}/done
}

# Ensure that we tell the Sonobuoy worker we are done regardless of results.
trap saveResults EXIT

if [[ -z "${TENANT_ID}" ]]; then
  echo "ERROR: parameter TENANT_ID is required." > ${results_dir}/error
  python3 setup_failure_handler.py
fi

if [[ -z "${SUBSCRIPTION_ID}" ]]; then
  echo "ERROR: parameter SUBSCRIPTION_ID is required." > ${results_dir}/error
  python3 setup_failure_handler.py
fi

if [[ -z "${RESOURCE_GROUP}" ]]; then
  echo "ERROR: parameter RESOURCE_GROUP is required." > ${results_dir}/error
  python3 setup_failure_handler.py
fi

if [[ -z "${CLUSTER_NAME}" ]]; then
  echo "ERROR: parameter CLUSTER_NAME is required." > ${results_dir}/error
  python3 setup_failure_handler.py
fi

if [[ -z "${CLIENT_ID}" ]]; then
  echo "ERROR: parameter CLIENT_ID is required." > ${results_dir}/error
  python3 setup_failure_handler.py
fi

if [[ -z "${CLIENT_SECRET}" ]]; then
  echo "ERROR: parameter CLIENT_SECRET is required." > ${results_dir}/error
  python3 setup_failure_handler.py
fi

if [[ -z "${OSM_ARC_RELEASE_TRAIN}" ]]; then
  echo "ERROR: parameter OSM_ARC_RELEASE_TRAIN is required." > ${results_dir}/error
  python3 setup_failure_handler.py
fi

if [[ -z "${OSM_ARC_RELEASE_NAMESPACE}" ]]; then
  echo "ERROR: parameter OSM_ARC_RELEASE_NAMESPACE is required." > ${results_dir}/error
  python3 setup_failure_handler.py
fi

if [[ -z "${OSM_ARC_VERSION}" ]]; then
  echo "ERROR: parameter OSM_ARC_VERSION is required." > ${results_dir}/error
  python3 setup_failure_handler.py
fi

if [[ -z "${OSM_TEST_BRANCH}" ]]; then
  echo "ERROR: parameter OSM_TEST_BRANCH is required." > ${results_dir}/error
  python3 setup_failure_handler.py
fi

# Login with service principal
az login --service-principal \
  -u ${CLIENT_ID} \
  -p ${CLIENT_SECRET} \
  --tenant ${TENANT_ID} 2> ${results_dir}/error || python3 setup_failure_handler.py

# Wait for resources in ARC ns
waitSuccessArc="$(waitForResources deployment azure-arc)"
if [ "${waitSuccessArc}" == false ]; then
    echo "deployment is not avilable in namespace - azure-arc"
    exit 1
fi

az extension add --name k8s-extension 2> ${results_dir}/error || python3 setup_failure_handler.py

az k8s-extension create \
    --cluster-name $CLUSTER_NAME \
    --resource-group $RESOURCE_GROUP \
    --cluster-type connectedClusters \
    --extension-type Microsoft.openservicemesh \
    --subscription $SUBSCRIPTION_ID \
    --scope cluster \
    --release-train $OSM_ARC_RELEASE_TRAIN \
    --name osm \
    --release-namespace $OSM_ARC_RELEASE_NAMESPACE \
    --version $OSM_ARC_VERSION 2> ${results_dir}/error || python3 setup_failure_handler.py

# Wait for resources in osm-arc release ns
waitSuccessArc="$(waitForResources deployment $OSM_ARC_RELEASE_NAMESPACE)"
if [ "${waitSuccessArc}" == false ]; then
    echo "deployment is not avilable in namespace - $OSM_ARC_RELEASE_NAMESPACE"
    exit 1
fi

export UPSTREAM_REPO="https://github.com/openservicemesh/osm"
export MUTATING_WEBHOOK_CONFIG_NAME="arc-osm-webhook-osm"

git clone -b $OSM_TEST_BRANCH $UPSTREAM_REPO
cd osm

export CTR_REGISTRY="openservicemesh"

if [[ "$OSM_ARC_VERSION" == *"-"* && "$OSM_ARC_VERSION" != *"rc"* ]]; then
  trimmed_tag=$(echo $OSM_ARC_VERSION | cut -d'-' -f 1)
  export CTR_TAG=v$trimmed_tag
else
  export CTR_TAG=v$OSM_ARC_VERSION
fi

go env -w GO111MODULE=on
make build-osm

if [[ "$KUBERNETES_DISTRIBUTION" == "openshift" ]]; then
  gotestsum --junitfile ../..$results_dir/results.xml ./tests/e2e -test.v -ginkgo.v -ginkgo.skip="\bHTTP ingress\b" -ginkgo.skip="\bTest reinstalling OSM in the same namespace with the same mesh name\b" -test.timeout 180m -installType=NoInstall -deployOnOpenShift=true -OsmNamespace=$OSM_ARC_RELEASE_NAMESPACE -v 2>&1
elif [[ "$KUBERNETES_DISTRIBUTION" == "RKE" ]]; then
  gotestsum --junitfile ../..$results_dir/results.xml ./tests/e2e -test.v -ginkgo.v -ginkgo.skip="\bHTTP ingress\b" -ginkgo.skip="\bTest reinstalling OSM in the same namespace with the same mesh name\b" -ginkgo.skip="\bTCP server-first traffic\b" -test.timeout 60m -installType=NoInstall -OsmNamespace=$OSM_ARC_RELEASE_NAMESPACE -v 2>&1
else
  gotestsum --junitfile ../..$results_dir/results.xml ./tests/e2e -test.v -ginkgo.v -ginkgo.skip="\bHTTP ingress\b" -ginkgo.skip="\bTest reinstalling OSM in the same namespace with the same mesh name\b" -test.timeout 60m -installType=NoInstall -OsmNamespace=$OSM_ARC_RELEASE_NAMESPACE -v 2>&1
fi

sleep 120

kubectl delete ns $OSM_ARC_RELEASE_NAMESPACE
kubectl delete mutatingwebhookconfiguration $MUTATING_WEBHOOK_CONFIG_NAME
