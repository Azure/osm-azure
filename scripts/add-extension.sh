#!/bin/bash

export RESOURCEID=subscriptions/$SUBSCRIPTION/resourceGroups/$RESOURCEGROUP/providers/Microsoft.Kubernetes/connectedClusters/$CLUSTERNAME
export HELM_EXPERIMENTAL_OCI=1

# enable connected cluster
az connectedK8s connect -n  $CLUSTERNAME -g $RESOURCEGROUP -l eastus2euap

# upgrade arc extension agent to dev release, the latest will be pulled from arc chart repo
helm upgrade azure-arc ./azure-arc-k8sagents --install --set global.subscriptionId=$SUBSCRIPTION,global.resourceGroupName=$RESOURCEGROUP,global.resourceName=$CLUSTERNAME,global.tenantId=$TENANTID,global.clientId=$CLIENTID,global.clientSecret=$CLIENTSECRET,global.location=eastus2euap,systemDefaultValues.extensionoperator.enabled=true,systemDefaultValues.azureArcAgents.releaseTrain=dev
# confirm
helm ls --all --all-namespaces

az resource tag --tags logAnalyticsWorkspaceResourceId=/$RESOURCEID --ids /$RESOURCEID
# get extensions enabled on this cluster
az rest --method GET --uri "https://management.azure.com/$RESOURCEID/providers/Microsoft.KubernetesConfiguration/extensions?api-Version=2020-07-01-preview"
# enable the osm extension
az rest --method PUT --uri "https://management.azure.com/$RESOURCEID/providers/Microsoft.KubernetesConfiguration/extensions/osm?api-Version=2020-07-01-preview" --body @osmextension.json --debug
# wait few mins to see the osm resources created
helm ls --all --all-namespaces                                                                        
