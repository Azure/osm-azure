## OSM with Azure Policy

This document describes the steps you may need to take if you are enabling both the Azure Policy and the OSM extension in your arc-enabled cluster. 



### Envoy Sidecar Injection

Some policies may reject the injection of the envoy proxy container to your workload pod, so you should exclude your workload from these policies by adding the "admission.policy.azure.com/ignore" label to your workload namespace. 

```
labels: 
	admission.policy.azure.com/ignore: "true"
```

You can add this label to your namespace after your namespace has been created with the following command: 

```command
kubectl label namespace <namespace> admission.policy.azure.com/ignore=true
```

