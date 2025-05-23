output "prometheus_public_ip" {
  value = aws_instance.prometheus.public_ip
}

output "grafana_public_ip" {
  value = aws_instance.grafana.public_ip
}

output "grafana_instance_id" {
  value = aws_instance.grafana.id
}

output "prometheus_instance_id" {
  value = aws_instance.prometheus.id
}

output "prometheus_url" {
  value = "http://${aws_instance.prometheus.public_ip}:9090"
}

output "grafana_url" {
  value = "http://${aws_instance.grafana.public_ip}:3000"
}
