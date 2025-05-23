#!/bin/bash
set -euo pipefail

LOG_FILE="/var/log/grafana-init.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "[INFO] Starting Grafana installation and configuration..."

# Install dependencies
yum install -y jq awscli gettext curl

# Fetch SSM parameters (fail early if any are missing)
echo "[INFO] Fetching SSM parameters..."
region=$(aws ssm get-parameter --name "/grafana/region" --with-decryption --query "Parameter.Value" --output text --region us-east-1) || { echo "[ERROR] Failed to get region"; exit 1; }
prometheus_host=$(aws ssm get-parameter --name "/grafana/prometheus_host" --with-decryption --query "Parameter.Value" --output text --region "$region") || { echo "[ERROR] Failed to get Prometheus host"; exit 1; }

export region
export prometheus_host

# Create a temporary template
cat <<'EOF' > /tmp/template.sh
#!/bin/bash
echo "[INFO] Starting additional configuration..."
echo "Region: $region"
echo "Prometheus Host: $prometheus_host"

curl -s http://$prometheus_host:9090/api/v1/targets | jq '.' || echo "[WARNING] Could not query Prometheus targets."

echo "Setup run at $(date) with region $region and Prometheus host $prometheus_host" >> /var/log/grafana-init.log
echo "[INFO] Done running final.sh"
EOF

# Generate final.sh with envsubst
if [ -f /tmp/template.sh ]; then
  envsubst < /tmp/template.sh > /tmp/final.sh
  chmod +x /tmp/final.sh
  bash /tmp/final.sh
else
  echo "[ERROR] /tmp/template.sh not found!"
  exit 1
fi

# Fetch Grafana admin password securely
GRAFANA_ADMIN_PASSWORD=$(aws ssm get-parameter \
  --name "/grafana/admin_password" \
  --with-decryption \
  --query "Parameter.Value" \
  --output text) || { echo "[ERROR] Failed to fetch Grafana admin password"; exit 1; }

# Install Grafana
echo "[INFO] Installing Grafana..."
amazon-linux-extras enable epel
yum install -y epel-release
yum install -y https://dl.grafana.com/oss/release/grafana-9.6.4-1.x86_64.rpm
systemctl daemon-reexec
systemctl enable grafana-server
systemctl start grafana-server

# Wait for Grafana to be ready
until curl -s http://localhost:3000/api/health | grep -q '"database":"ok"'; do
  echo "[INFO] Waiting for Grafana to be ready..."
  sleep 10
done

# Configure datasources
echo "[INFO] Adding Prometheus and CloudWatch datasources..."
curl -s -X POST "http://admin:${GRAFANA_ADMIN_PASSWORD}@localhost:3000/api/datasources" \
  -H "Content-Type: application/json" \
  -d '{
        "name": "Prometheus",
        "type": "prometheus",
        "url": "http://'"$prometheus_host"':9090",
        "access": "proxy",
        "basicAuth": false
      }'

curl -s -X POST "http://admin:${GRAFANA_ADMIN_PASSWORD}@localhost:3000/api/datasources" \
  -H "Content-Type: application/json" \
  -d '{
        "name": "CloudWatch",
        "type": "cloudwatch",
        "access": "proxy",
        "jsonData": {
          "defaultRegion": "'"${region}"'"
        }
      }'

# Function to POST dashboards
post_dashboard() {
  local json="$1"
  echo "$json" | curl -s -X POST "http://admin:admin:${GRAFANA_ADMIN_PASSWORD}@localhost:3000/api/dashboards/db" \
    -H "Content-Type: application/json" \
    -d @-
}

# EC2 Dashboard
post_dashboard "$(cat <<EOF
{
  "dashboard": {
    "id": null,
    "uid": "ec2-dashboard",
    "title": "EC2 Monitoring",
    "timezone": "browser",
    "schemaVersion": 18,
    "version": 1,
    "panels": [
      {
        "type": "graph",
        "title": "CPU Utilization",
        "datasource": "CloudWatch",
        "targets": [{
          "region": "${region}",
          "namespace": "AWS/EC2",
          "metricName": "CPUUtilization",
          "statistics": ["Average"],
          "period": 300,
          "refId": "A"
        }],
        "gridPos": { "x": 0, "y": 0, "w": 24, "h": 8 }
      }
    ]
  },
  "overwrite": true
}
EOF
)"

# RDS Dashboard
post_dashboard "$(cat <<EOF
{
  "dashboard": {
    "id": null,
    "uid": "rds-dashboard",
    "title": "RDS Monitoring",
    "timezone": "browser",
    "schemaVersion": 18,
    "version": 1,
    "panels": [
      {
        "type": "graph",
        "title": "Database Connections",
        "datasource": "CloudWatch",
        "targets": [{
          "region": "${region}",
          "namespace": "AWS/RDS",
          "metricName": "DatabaseConnections",
          "statistics": ["Average"],
          "period": 300,
          "refId": "A"
        }],
        "gridPos": { "x": 0, "y": 0, "w": 24, "h": 8 }
      }
    ]
  },
  "overwrite": true
}
EOF
)"

# VPC Dashboard
post_dashboard "$(cat <<EOF
{
  "dashboard": {
    "id": null,
    "uid": "vpc-dashboard",
    "title": "VPC Flow Logs",
    "timezone": "browser",
    "schemaVersion": 18,
    "version": 1,
    "panels": [
      {
        "type": "stat",
        "title": "VPC Accepted Bytes",
        "datasource": "CloudWatch",
        "targets": [{
          "region": "${region}",
          "namespace": "AWS/VPC",
          "metricName": "Bytes",
          "dimensions": { "TrafficType": "ACCEPT" },
          "statistics": ["Sum"],
          "period": 300,
          "refId": "A"
        }],
        "gridPos": { "x": 0, "y": 0, "w": 12, "h": 8 }
      },
      {
        "type": "stat",
        "title": "VPC Rejected Bytes",
        "datasource": "CloudWatch",
        "targets": [{
          "region": "${region}",
          "namespace": "AWS/VPC",
          "metricName": "Bytes",
          "dimensions": { "TrafficType": "REJECT" },
          "statistics": ["Sum"],
          "period": 300,
          "refId": "B"
        }],
        "gridPos": { "x": 12, "y": 0, "w": 12, "h": 8 }
      }
    ]
  },
  "overwrite": true
}
EOF
)"

# App Metrics Dashboard
post_dashboard "$(cat <<EOF
{
  "dashboard": {
    "id": null,
    "uid": "app-metrics",
    "title": "App Metrics (Prometheus)",
    "timezone": "browser",
    "schemaVersion": 18,
    "version": 1,
    "panels": [
      {
        "type": "graph",
        "title": "HTTP Requests Per Second",
        "datasource": "Prometheus",
        "targets": [{
          "expr": "rate(http_requests_total[1m])",
          "legendFormat": "req/sec",
          "refId": "A"
        }],
        "gridPos": { "x": 0, "y": 0, "w": 24, "h": 8 }
      }
    ]
  },
  "overwrite": true
}
EOF
)"

# Import EKS Dashboards
echo "[INFO] Importing Kubernetes Dashboards..."
curl -s -X POST "http://admin:admin:${GRAFANA_ADMIN_PASSWORD}@localhost:3000/api/dashboards/import" \
  -H "Content-Type: application/json" \
  -d '{
    "dashboard": { "id": 17119, "uid": null, "title": "Kubernetes EKS Cluster (Prometheus)", "tags": [], "timezone": "browser", "schemaVersion": 16, "version": 0 },
    "overwrite": true,
    "inputs": [{ "name": "DS_PROMETHEUS", "type": "datasource", "pluginId": "prometheus", "value": "Prometheus" }]
  }'

curl -s -X POST "http://admin:admin:${GRAFANA_ADMIN_PASSWORD}@localhost:3000/api/dashboards/import" \
  -H "Content-Type: application/json" \
  -d '{
    "dashboard": { "id": 16028, "uid": null, "title": "Kubernetes EKS Cluster (CloudWatch)", "tags": [], "timezone": "browser", "schemaVersion": 16, "version": 0 },
    "overwrite": true,
    "inputs": [{ "name": "DS_CLOUDWATCH", "type": "datasource", "pluginId": "cloudwatch", "value": "CloudWatch" }]
  }'

echo "[INFO] Grafana setup completed successfully."
