KIND_VERSION ?= 0.8.1
# note: k8s version pinned since KIND image availability lags k8s releases
KUBERNETES_VERSION ?= v1.19.0
HELM_VERSION ?= 3.3.4

e2e-bootstrap:
	# Download and install kind
	curl -L https://github.com/kubernetes-sigs/kind/releases/download/v${KIND_VERSION}/kind-linux-amd64 --output ${GITHUB_WORKSPACE}/bin/kind && chmod +x ${GITHUB_WORKSPACE}/bin/kind
	# Download and install kubectl
	curl -L https://storage.googleapis.com/kubernetes-release/release/${KUBERNETES_VERSION}/bin/linux/amd64/kubectl -o ${GITHUB_WORKSPACE}/bin/kubectl && chmod +x ${GITHUB_WORKSPACE}/bin/kubectl
	# Download and install bats
	sudo apt-get -o Acquire::Retries=30 update && sudo apt-get -o Acquire::Retries=30 install -y bats
	# Check for existing kind cluster
	if [ $$(kind get clusters) ]; then kind delete cluster; fi
	# Create a new kind cluster
	TERM=dumb kind create cluster --image kindest/node:${KUBERNETES_VERSION}
	# Create namespaces to test openservicemesh.io/ignore label
	kubectl create namespace azure-arc
	kubectl create namespace arc-osm-system

e2e-helm-deploy:
	rm -rf .staging/helm
	mkdir -p .staging/helm
	curl https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz > .staging/helm/helmbin.tar.gz
	cd .staging/helm && tar -xvf helmbin.tar.gz
	./.staging/helm/linux-amd64/helm install osm ./charts/osm --namespace arc-osm-system

test-e2e:
	bats -t test/bats/test.bats

e2e-cleanup:
	rm test.json
	kind delete cluster
