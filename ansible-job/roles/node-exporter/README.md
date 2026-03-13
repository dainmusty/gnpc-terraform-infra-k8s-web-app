# Follow the commands below to create the role

# cd to the main the ansible directory
# Run to create role grafana
ansible-galaxy init roles/node-exporter




 Is Prometheus scraping Node Exporter successfully?
In Prometheus UI (/targets), you should see:

The app_servers job listed

Each target showing UP

If not, double-check:

Security Groups: port 9100 open to Prometheus

Correct EC2 tags: Only instances with tag:Name = app_servers will be picked up

IAM permissions: Prometheus EC2 instance must have permission to call DescribeInstances