```
.
|-- README.md                        <- this file
|-- main.tf                          <- providers, VPC data source, SG, EC2,
|                                       S3 bucket, ECR repo, inline cloud-init
|                                       (installs k3s + ECR cred provider, clones
|                                       repo, applies manifests, helm-installs
|                                       kube-prometheus-stack, applies CRD objects)
|-- variables.tf                     <- all input variables
|-- outputs.tf                       <- public IP and SSH command outputs
|-- terraform.tfvars                 <- variable values  (!! should be .gitignored)
|-- manifests/                       <- core resources, auto-applied by k3s on boot
|   |-- configmap.yaml               <- Minecraft env (EULA, MOTD w/ name+ID,
|   |                                   VERSION, MEMORY, TYPE)
|   |-- pvc.yaml                     <- PersistentVolumeClaim, 5Gi, local-path
|   |-- deployment.yaml              <- Deployment: Recreate, probes, resources,
|   |                                   pinned ECR image, mc-monitor sidecar,
|   |                                   mounts PVC at /data
|   |-- service.yaml                 <- LoadBalancer Service, TCP 25565 (players)
|   |-- monitoring-port-service.yaml <- ClusterIP Service minecraft-metrics, :8080
|   |                                   -> mc-monitor /metrics (scrape target)
|   |-- monitoring-service.yaml      <- ServiceMonitor `minecraft`: scrapes the
|   |                                   minecraft-metrics Service (default ns via
|   |                                   namespaceSelector). CRD-dependent
|   |-- custom-dashboard.yaml        <- ConfigMap (label grafana_dashboard:1) with
|   |                                   the Grafana dashboard JSON, auto-provisioned
|   |                                   by the Grafana dashboard sidecar
|   |-- alerting-rules.yaml          <- PrometheusRule (cs312-alerts): 4 alerts.
|   |                                   CRD-dependent (see note below)
|   `-- cron-backup.yaml             <- CronJob every 10 min, syncs /data to S3
|-- monitoring/                      <- Helm config, applied during cloud-init
|   `-- values.yaml                  <- kube-prometheus-stack values: 30s scrape,
|                                       7d retention, serviceMonitor/rule selector
|                                       flags, Grafana ClusterIP + 1Gi + dashboard
|                                       sidecar
`-- .github/
    `-- workflows/                   <- CI/CD from Ops 3: build & push image to ECR
```
