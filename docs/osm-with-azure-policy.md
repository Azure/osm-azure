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

Modifying the osm-controller and osm-label containers to meet these security requirements will allow the OSM installation to proceed without being interrupted. However, if you examine the events in the arc-osm-system namespace by doing "kubectl get events --namespace arc-osm-system," you will see that there are still policy violations caused by the fluentbit-logger container mounting host volumes. The only way to circumvent this is by whitelisting the arc-osm-system namespace in the azure-policy. 

### Envoy Sidecar Injection

One of the features offered by the OSM extension is service to service communication via sidecar proxy injection. After a namespace is added to the mesh and is annotated to enable sideacr injection, OSM will add the Envoy container to new pods created in that namespace. However, the osm-init and envoy containers used in the sidecar injection violate some of the built-in azure policies, such as the "no privilege escalation" policy. Thus, the new namespace must also be whitelisted from the azure policy in order for sidecar injection to work within that namespace. 


