# Monitoring Server Profile

Complete monitoring stack with Prometheus, Grafana, and ELK.

## Components

### Metrics
- **Prometheus** - Metrics collection
- **Grafana** - Visualization (admin/ChangeMe123!)
- **InfluxDB** - Time series database
- **Telegraf** - Metrics collector

### Logs
- **Elasticsearch** - Log storage
- **Logstash** - Log processing
- **Kibana** - Log visualization
- **Filebeat** - Log shipper

### Exporters
- Node Exporter (system metrics)
- Blackbox Exporter (endpoint monitoring)
- Database exporters (PostgreSQL, MySQL, Redis)

## Access Points

- **Grafana**: http://server-ip:3000
- **Prometheus**: http://server-ip:9090
- **Alertmanager**: http://server-ip:9093
- **Kibana**: http://server-ip:5601

## Post-Installation

1. Change Grafana admin password
2. Import dashboards from grafana.com
3. Configure alert notifications
4. Add monitoring targets
5. Set up SSL with certbot

## Adding Targets

Edit `/etc/prometheus/prometheus.yml`:
```yaml
- job_name: 'my-app'
  static_configs:
    - targets: ['app-server:9100']
```

Then reload: `sudo systemctl reload prometheus`
