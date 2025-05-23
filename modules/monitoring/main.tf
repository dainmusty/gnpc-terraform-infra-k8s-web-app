# EC2 for Prometheus 
resource "aws_instance" "prometheus" {
  ami                    = var.ami
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.monitoring_sg_id]
  key_name               = var.key_name
  iam_instance_profile   = var.prometheus_profile_name
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
  tags = var.grafana_tags
}


# Prometheus and Granfana Configuration setup will be done using ansible via user_data in the script directory.

