# OSM Arc Troubleshooting

This guide will help you troubleshoot the OSM Arc extension by providing steps to inspect logs and resources to learn how to mitigate common issues.

## Log Inspection

The first step in debugging the extension is to look at the logs. Since the extension is comprised of various components, it's important to check each set of logs carefully.

### Helm
Check the status of the Helm installation
`kubectl -n arc-osm-system get ExtensionConfig osm -oyaml`
The output of the osm ExtensionConfig object can help provide clues to what failed. The output should include something that looks like:
```
spec:
  correlationId: 25509732-9b48-49a8-bd6e-e517dbfb992c
  extensionType: microsoft.openservicemesh
  lastModifiedTime: "2021-01-20T22:34:27Z"
  parameter:
    scope: cluster
  releaseTrain: pilot
  repoUrl: https://mcr.microsoft.com/oss/openservicemesh/canary/pilot/osm-arc
  version: 0.6.1
status:
  configAppliedTime: "2021-01-20T22:35:19.509Z"
  message: ""
  operatorPropertiesHashed: ""
  status: Successfully installed the extension
```

### Azure Arc
1. Get Azure Arc pods to see if they are healthy
`kubectl get pod -n azure-arc`
    - If any of the pods are crashing, get logs for the `manager` container. 
e.g. `kubectl logs extension-manager-856df596c-twkpx manager -n azure-arc`

### OSM
1. Get OSM pods to see if they are healthy
`kubectl get pod -n arc-osm-system`
    - If any of the pods are crashing, get logs for the `osm-controller` container. 
e.g. `kubectl logs osm-controller-7b4ddc7dfb-hdfhd osm-controller -n arc-osm-system`

## Troubleshooting Resources
1. [OSM Arc docs](https://github.com/Azure/osm-azure/tree/main/docs)
    - These docs will detail the correct way to manage your OSM Arc installation. 
1. [OSM Troubleshooting docs](https://github.com/openservicemesh/osm/tree/main/docs/troubleshooting)
    - These docs include common OSM errors, how to mitigate them, and how to prevent them in the future.

## File an issue
If the logs and troubleshooting resources above do not help mitigate your issue, please [file an issue on GitHub](https://github.com/Azure/osm-azure/issues/new).