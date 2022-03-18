#!/bin/bash
# Register osm-arc extension with Arc Registration API

REGION_STAGING=${REGION_STAGING:-'"eastus2euap", "eastus", "westeurope"'}
RELEASE_TRAIN_STAGING=${RELEASE_TRAIN:-staging}

REGIONS_CANARY_PROD=${REGIONS_CANARY_LIST:-'"eastus2euap"'}
REGIONS_BATCH1_PROD=${REGIONS_BATCH1_LIST:-'"eastus","westeurope","australiaeast","eastus2","francecentral","northeurope","southcentralus","southeastasia","uksouth","westcentralus","westus2","centralus","northcentralus","westus","koreacentral","japaneast","eastasia","westus3","usgovvirginia"'}
RELEASE_TRAINS_PROD=${RELEASE_TRAINS_LIST:-"pilot preview stable"}

PACKAGE_CONFIG_NAME="${PACKAGE_CONFIG_NAME:-microsoft.openservicemesh20220214}"
API_VERSION="${API_VERSION:-2021-05-01}"
METHOD="${METHOD:-put}"

# Create JSON request body
cat <<EOF > "request.json"
{
    "artifactEndpoints": [
        {
            "Regions": [
                $REGION_STAGING
            ],
            "Releasetrains": [
                "$RELEASE_TRAIN_STAGING"
            ],
            "FullPathToHelmChart": "$REGISTRY_STAGING",
            "ExtensionUpdateFrequencyInMinutes": 60,
            "IsCustomerHidden": false,
            "ReadyforRollout": true,
            "RollbackVersion": null,
            "PackageConfigName": "$PACKAGE_CONFIG_NAME"
        },
EOF

RELEASE_TRAINS_PROD=($RELEASE_TRAINS_PROD)
REGISTRIES_PROD_CANARY=($REGISTRIES_PROD_CANARY)
REGISTRIES_PROD_BATCH1=($REGISTRIES_PROD_BATCH1)

for i in ${!RELEASE_TRAINS_PROD[@]}
do
cat <<EOF >> "request.json"
        {
            "Regions": [
                $REGIONS_CANARY_PROD
            ],
            "Releasetrains": [
                "${RELEASE_TRAINS_PROD[$i]}"
            ],
            "FullPathToHelmChart": "${REGISTRIES_PROD_CANARY[$i]}",
            "ExtensionUpdateFrequencyInMinutes": 60,
            "IsCustomerHidden": false,
            "ReadyforRollout": true,
            "RollbackVersion": null,
            "PackageConfigName": "$PACKAGE_CONFIG_NAME"
        },
        {
            "Regions": [
                $REGIONS_BATCH1_PROD
            ],
            "Releasetrains": [
                "${RELEASE_TRAINS_PROD[$i]}"
            ],
            "FullPathToHelmChart": "${REGISTRIES_PROD_BATCH1[$i]}",
            "ExtensionUpdateFrequencyInMinutes": 60,
            "IsCustomerHidden": false,
            "ReadyforRollout": true,
            "RollbackVersion": null,
            "PackageConfigName": "$PACKAGE_CONFIG_NAME"
        },
EOF
done

sed -i '$ s/.$//' request.json

cat <<EOF >> "request.json"
    ]
}
EOF

cat request.json | jq

# Send Request
az rest --method $METHOD --headers "{\"Authorization\": \"Bearer $ACCESS_TOKEN\", \"Content-Type\": \"application/json\"}" --body @request.json --uri $ARC_API_URL/subscriptions/$SUBSCRIPTION/extensionTypeRegistrations/microsoft.openservicemesh/versions/$VERSION?api-version=$API_VERSION
