<!--

Use the checklist below to ensure your release PR is complete before marking it ready for review.

-->

- [ ] I have ensured that required images are available in MCR:
	1. osm-controller, osm-injector and init images of the corresponding chart version
	2. envoy image of version listed in osm-arc/oss values.yaml
    3. grafana, grafana-image-renderer, prometheus, jaegertracing/all-in-one image of version listed in osm-arc/oss values.yaml

- [ ] I have updated the Helm chart:
    1. Updated the chart version, app version and dependency version in charts/osm-arc/Chart.yaml    
    2. Made applicable updates to the osm-arc values.yaml if any were made in the upstream OSM chart
    
    <!--
    In upstream, compare between the latest release and the previous release to check if anything has changed in the OSS values.yaml e.g: https://github.com/openservicemesh/osm/compare/v0.6.1...v0.7.0-rc.1
    Check for variable name changes, removed variables, variables that need to be overridden, etc. and make applicable changes in the osm-arc chart.    
    -->   
- [ ] I have received 3 approvals from maintainers. 
