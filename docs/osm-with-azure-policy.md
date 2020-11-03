## OSM with Azure Policy

Adding OSM to an arc-enabled AKS cluster that has the Azure Policy addon installed can present some complications. The built-in Azure policy initiatives for kubernetes encompass several policies, some of which conflict with the OSM extension. For instance, without making any chances to the osm-controller or osm-label, the following policy violations blocked the OSM extension from being added. 


- AllowedUsersGroups: 
	- Need securityContext/runAsUser: Allowed runAsUser: {"ranges": [], "rule": "MustRunAsNonRoot"}
	- securityContext/runAsGroup: Allowed runAsGroup: {"ranges": [{"max": 65535, "min": 1}], "rule": "MustRunAs"}
	- securityContext/supplementalGroups: Allowed supplementalGroups: {"ranges": [{"max": 65535, "min": 1}], "rule": "MustRunAs"}
	- securityContext/fsGroup: Allowed fsGroup: {"ranges": [{"max": 65535, "min": 1}], "rule": "MustRunAs"}
- AllowedSeccompProfiles:
	- Allowed profiles: ["runtime/default", "docker/default"]
- NoPrivilegeEscalation

Modifying the osm-controller and osm-label containers to meet these security requirements, and adding the "admission.policy.azure.com/ignore" label to the arc-osm-system namespace, will allow the OSM installation to proceed without being interrupted.

### Envoy Sidecar Injection

You may need to add the "admission.policy.azure.com/ignore" label to your workload namespace if you have AZ policy running to ensure that envoy proxy container can be injected. 


