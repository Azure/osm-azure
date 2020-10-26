# Observability

## Log Forwarding with Fluent Bit
Open Service Mesh (OSM) generates logs and uses Fluent Bit to process and forward them to Azure Monitor. 

[Fluent Bit](https://fluentbit.io/) is an open source log processor and forwarder which allows you to collect data/logs and send them to multiple destinations. OSM provides log forwarding by optionally deploying a Fluent Bit sidecar to the OSM controller. This can be disabled by changing `enableFluentbit` to false in `values.yaml` or by using a `--set OpenServiceMesh.enableFluentbit=false` flag with the `helm install` command. Logs are sent to a Log Analytics workspace that is consumed by an instance of Application Insights. 

### Customizing the Fluent Bit Configuration
You may configure log forwarding to a different output by following these steps _before_ you install OSM.

1. Define the output plugin you would like to forward your logs to in the existing `fluentbit-configmap.yaml` file by replacing the `[OUTPUT]` section with your chosen output as described by Fluent Bit documentation [here](https://docs.fluentbit.io/manual/v/1.4/pipeline/outputs).

2. The default configuration uses CRI log format parsing. If you are using a kubernetes distribution that causes your logs to be formatted differently, you may need to update the `[PARSER]` section and the `parser` name in the `[INPUT]` section to one of the parsers defined [here](https://github.com/fluent/fluent-bit/blob/master/conf/parsers.conf).

3. To view all logs irrespective of log level, you may remove the `[FILTER]` section. To change the log level being filtered on, you can update the "error" value below to "debug", "info", "warn", "fatal", "panic" or "trace":
   ```    
   [FILTER]
         name       grep
         match      *
         regex      message /"level":"error"/
   ```

4. Once you have updated the Fluent Bit configmap, you must install OSM again for it to be deployed.

