# EC2 for Prometheus # you can one instance for both Prometheus and Grafana for test or dev evironments.
resource "aws_instance" "prometheus" {
  ami                    = var.ami
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.monitoring_sg_id]
  key_name               = var.key_name
  iam_instance_profile   = var.prometheus_profile_name
  # user_data = file("${path.module}/../../scripts/prometheus_user_data.sh")   # Uncomment if you want to use userdata to install prometheus

  
  tags = var.prometheus_tags
}



# EC2 for Grafana.
resource "aws_instance" "grafana" {
  ami                    = var.ami
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_ids
  key_name               = var.key_name
  iam_instance_profile   = var.grafana_profile_name
  # user_data = file("${path.module}/../../scripts/grafana_user_data.sh")  # # Uncomment if you want to use userdata to install grafana otherwise ansible is the best tool for installation and configuration. Refer to the script directory to update the grafana admin password variables

  tags = var.grafana_tags

  depends_on = [ aws_instance.prometheus ]  # Ensures Prometheus is created before Grafana
}

