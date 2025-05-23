#!/bin/bash

sudo apt-get update -y
sudo apt-get install -y prometheus

# Enable Prometheus
sudo systemctl enable prometheus
sudo systemctl start prometheus

# Add alerting rules
cat <<EOF | sudo tee /etc/prometheus/alert.rules.yml
groups:
  - name: instance-alerts
    rules:
      - alert: HighCPUUsage
        expr: rate(node_cpu_seconds_total{mode="user"}[2m]) > 0.9
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage detected"
          description: "Instance {{ \$labels.instance }} has high CPU usage for over 2 minutes."
EOF

# Restart to apply changes
sudo systemctl restart prometheus
sudo systemctl daemon-reload

