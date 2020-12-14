KIND_VERSION ?= 0.8.1
# note: k8s version pinned since KIND image availability lags k8s releases
KUBERNETES_VERSION ?= v1.19.0
BATS_VERSION ?= 1.2.1

package-osm-chart:
	helm dependency update osm-arc
	
install-prerequisites:
	# Setup kind if TEST_KIND is set to true
	if [ $(TEST_KIND) ]; then make setup-kind ; fi
	# Install kubectl if not installed
	kubectl version --short | grep -q $(KUBERNETES_VERSION) || (curl -L https://storage.googleapis.com/kubernetes-release/release/${KUBERNETES_VERSION}/bin/linux/amd64/kubectl -o ${HOME}/bin/kubectl && chmod +x ${HOME}/bin/kubectl)
	# Install helm if not installed
	helm version --short | grep -q v3 || (curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash)
	# Install bats if not installed
	bats --version | grep -q $(BATS_VERSION) || (sudo apt-get -o Acquire::Retries=30 update && sudo apt-get -o Acquire::Retries=30 install -y bats)

.PHONY: setup-kind
setup-kind:
	# Download and install kind if not installed
	kind --version | grep -q $(KIND_VERSION) || (curl -L https://github.com/kubernetes-sigs/kind/releases/download/v${KIND_VERSION}/kind-linux-amd64 --output ${HOME}/bin/kind && chmod +x ${HOME}/bin/kind)
	# Create kind cluster
	kind delete cluster || true
	kind create cluster --image kindest/node:$(KUBERNETES_VERSION)

e2e-bootstrap:
	# Create namespaces to test openservicemesh.io/ignore label
	# Create azure-arc ns only if it doesn't exist (eg: for non-arc clusters)
	kubectl get ns | grep -q azure-arc || kubectl create namespace azure-arc
	kubectl create namespace arc-osm-system

e2e-helm-deploy:
	helm dependency update ./charts/osm-arc
	helm install osm ./charts/osm-arc --namespace arc-osm-system --dependency-update

test-e2e:
	bats -t test/bats/test.bats

e2e-cleanup:
	helm uninstall osm -n arc-osm-system
	kubectl delete namespace arc-osm-system
	if [ $(TEST_KIND) ]; then kind delete cluster; fi
