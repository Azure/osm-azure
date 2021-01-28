# Update OSM Arc extension

## Supported Upgrades
The OSM Arc extension can be upgraded up to the next minor version. Downgrades and major version upgrades are not supported at this time.

## CRD Upgrades
The OSM Arc extension cannot be upgraded to a new version if that version contains CRD updates without deleting the existing CRDs first. 

Please refer to the [OSM CRD Upgrades documentation](https://github.com/openservicemesh/osm/blob/main/docs/upgrade_guide.md#crd-upgrades) to prep your cluster for such an upgrade. After deleting your CRDs per the OSM documentation, please follow the upgrade [instructions](#instructions) in this guide instead of using Helm or the OSM CLI.

## OSM ConfigMap upgrades
When upgrading, any custom edits to the osm-config ConfigMap may be reverted to the default. 

To ensure that these values are not overwritten, create a copy of the following JSON object and save it as `osm_extension.json`.

```
{
  "properties": {
    "extensionType": "Microsoft.openservicemesh",
    "autoUpgradeMinorVersion": "false",
    "version": "0.5.0",
    "releaseTrain": "Pilot",
    "scope": {
      "cluster": {
        "releaseNamespace": "arc-osm-system"
      }
    },
    "configurationSettings": {
        "osm.OpenServiceMesh.envoyLogLevel" : "info"
    }
  }
}
```
Now edit the following fields:

1. Set `properties.version` to the [release](https://github.com/Azure/osm-azure/tags) you are going to upgrade to (omit the 'v').
1. Update `properties.configurationSettings` field to include the ConfigMap values you have edited. 
    - To find the corresponding chart values for the ConfigMap settings, view the [OSM ConfigMap documentation](https://github.com/openservicemesh/osm/blob/main/docs/content/docs/osm_config_map.md). Make sure to prepend those values with `osm.` as shown in the example above.
    - The above example will ensure that the `envoy_log_level` field in the ConfigMap is set to `info`. 

## Instructions
1. [Set environment variables in .env file](./get-started#SetEnvVars)
    - The checkout tag should be the chart version for the upgrade.
1. Run `./scripts/update-extension.sh osm_extension.json`
    - Omit the JSON file location to use default upgrade settings.
