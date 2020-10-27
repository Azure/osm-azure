# Observability

## Log Forwarding with Fluent Bit
Open Service Mesh (OSM) generates logs and uses Fluent Bit to process and forward them to Azure Monitor. 

[Fluent Bit](https://fluentbit.io/) is an open source log processor and forwarder which allows you to collect data/logs and send them to multiple destinations. OSM provides log forwarding by optionally deploying a Fluent Bit sidecar to the OSM controller. This can be disabled by changing `enableFluentbit` to false in `values.yaml` or by using a `--set OpenServiceMesh.enableFluentbit=false` flag with the `helm install` command. Logs are sent to a Log Analytics workspace that is consumed by an instance of Application Insights. 

