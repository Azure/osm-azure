#!/bin/bash
# Register osm-arc extension with Arc Registration API

REGION=${REGION:-'"eastus2euap", "eastus", "westeurope"'}
RELEASE_TRAINS="${RELEASE_TRAINS:-staging}"
PACKAGE_CONFIG_NAME="${PACKAGE_CONFIG_NAME:-microsoft.openservicemesh20220214}"
API_VERSION="${API_VERSION:-2021-05-01}"
METHOD="${METHOD:-put}"

# Create JSON request body
cat <<EOF > "request.json"
{
  "artifactEndpoints": [
    {
      "Regions": [
          $REGION
      ],
      "Releasetrains": [
          "$RELEASE_TRAINS"
      ],
      "FullPathToHelmChart": "$REGISTRY_PATH",
      "ExtensionUpdateFrequencyInMinutes": 60,
      "IsCustomerHidden": false,
      "ReadyforRollout": true,
      "RollbackVersion": null,
      "PackageConfigName": "$PACKAGE_CONFIG_NAME"
    }
  ]
}
EOF

# Send Request
az rest --method $METHOD --headers "{\"Authorization\": \"Bearer $ACCESS_TOKEN\", \"Content-Type\": \"application/json\"}" --body @request.json --uri $ARC_API_URL/subscriptions/$SUBSCRIPTION/extensionTypeRegistrations/microsoft.openservicemesh/versions/$VERSION?api-version=$API_VERSION
