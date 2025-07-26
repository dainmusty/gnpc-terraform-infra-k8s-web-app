#######################################################################
# Initial setup Prometheus and Grafana setup
#######################################################################
resource "aws_instance" "prometheus" {
  ami           = var.ami
  instance_type = var.instance_type
  subnet_id     = var.subnet_id
  vpc_security_group_ids = var.security_group_ids
  key_name = var.key_name
  iam_instance_profile = var.prometheus_instance_profile

  tags = merge(var.tags, {
    Name = "${var.ResourcePrefix}-Prometheus"
  })

  user_data = fileexists("${path.module}/scripts/prometheus_userdata.sh") ? templatefile("${path.module}/scripts/prometheus_userdata.sh", {
    region = var.aws_region
  }) : null
}

resource "aws_instance" "grafana" {
  ami                    = var.ami
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_ids
  key_name               = var.key_name
  iam_instance_profile   = var.grafana_instance_profile

  depends_on = [aws_instance.prometheus] # Ensures Prometheus comes first

  user_data = fileexists("${path.module}/scripts/grafana_userdata.sh") ? templatefile("${path.module}/scripts/grafana_userdata.sh", {
    prometheus_host = "http://${aws_instance.prometheus.private_ip}:9090", # Dynamic IP. Change to public if grafana and prometheus are in different VPCs
    region          = var.aws_region
  }) : null

  tags = merge(var.tags, {
    Name = "${var.ResourcePrefix}-Grafana"
  })
}

#######################################################################
#This goes into your prometheus config file (prometheus.yml.tmpl file)
#######################################################################

# If you are using ansible or packer; use the Jinja-like syntax below

global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'my_app'
    static_configs:
      - targets: [
          <% for ip in app_targets ~%>
            "${ip}:9100"<% if ip != app_targets[-1] %>, <% endif %>
          <% endfor %>
        ]

# If you are using terraform; use the Go template syntax below
{{- $targets := join "," targets }}  # This passes a list of strings (each wrapped in quotes), and join "," targets joins them into a comma-separated string that becomes: targets: ["10.0.1.5:9100","10.0.1.6:9100"]


global:
  scrape_interval: 15s

rule_files:
  - "/etc/prometheus/alert.rules.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'my_app'
    static_configs:
      - targets: [{{ $targets }}]




Thanks for sharing the detailed setup. Since Prometheus installs successfully but Grafana doesn’t when launched via Terraform, even though the script works manually, the issue likely boils down to missing context or environment when the script runs in EC2 user data.

✅ Key Areas to Check and Fix
🔹 1. User data timing and permissions
EC2 user data scripts:

run only once at instance launch

run as root

may run before instance is fully initialized (especially network or SSM)

🔹 2. Likely Causes in Your Script
Here's what's potentially breaking your Grafana install:

Issue	Explanation	Fix
aws ssm get-parameter fails	User data runs before IAM role and instance metadata is fully available	Add retry logic or wait for instance metadata
aws ec2 describe-instances returns no Prometheus IP	Prometheus not yet fully initialized	Add retry loop or delay
Grafana install silently fails	Repos may not be ready or network not up	Log dnf install output to file
curl calls fail	Grafana server not yet ready	Add retry with delay
User data logs not inspected	Failures are not visible unless logged	Use full logging to /var/log/user-data.log




###################################################################### 
######################################################################

Automatically configure Prometheus to scrape EC2 instances.

Set up Grafana to use Prometheus as a data source with a default dashboard.

1. Prometheus Scraping EC2 Instances
To make Prometheus scrape EC2 targets, we’ll:

Enable EC2 SD (Service Discovery)

Create a Prometheus config file (prometheus.yml)

Replace the default config during EC2 instance bootstrap
Create prometheus_config.tpl (template file for Prometheus config)

Note:
You must install Node Exporter on each EC2 instance for Prometheus to scrape metrics on port 9100.

global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'ec2'
    ec2_sd_configs:
      - region: ${region}
        access_key: ${access_key}
        secret_key: ${secret_key}
    relabel_configs:
      - source_labels: [__meta_ec2_private_ip]
        target_label: __address__
        replacement: "${1}:9100"


2. Update prometheus_user_data.sh
#!/bin/bash
# Install Prometheus
sudo apt-get update -y
sudo apt-get install -y prometheus unzip curl

# Create Prometheus config folder and replace config file
sudo mkdir -p /etc/prometheus
cat <<EOF | sudo tee /etc/prometheus/prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'node_exporters'
    static_configs:
      - targets: ['localhost:9100']
EOF

# Restart Prometheus with new config
sudo systemctl restart prometheus
sudo systemctl enable prometheus

# Install Node Exporter (optional if running on the same instance)
cd /tmp
curl -LO https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz
tar xvf node_exporter-1.6.1.linux-amd64.tar.gz
sudo cp node_exporter-1.6.1.linux-amd64/node_exporter /usr/local/bin
sudo useradd -rs /bin/false node_exporter
sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<EOL
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=default.target
EOL

sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl start node_exporter


3. Grafana: Auto-connect to Prometheus
✨ Update grafana_user_data.sh:
#!/bin/bash
# Install Grafana
sudo apt-get update -y
sudo apt-get install -y software-properties-common apt-transport-https wget

wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
echo "deb https://packages.grafana.com/oss/deb stable main" | sudo tee /etc/apt/sources.list.d/grafana.list

sudo apt-get update -y
sudo apt-get install -y grafana

# Start Grafana
sudo systemctl enable grafana-server
sudo systemctl start grafana-server

# Wait for Grafana to start
sleep 15

# Add Prometheus as default data source
curl -s -X POST http://admin:admin@localhost:3000/api/datasources \
-H "Content-Type: application/json" \
-d '{
  "name":"Prometheus",
  "type":"prometheus",
  "url":"http://<PROMETHEUS_PRIVATE_IP>:9090",
  "access":"proxy",
  "isDefault":true
}'

Replace <PROMETHEUS_PRIVATE_IP> with either:

A Terraform variable passed via user_data using templatefile

Or configure DNS/static IPs if both run on same machine (localhost works)


1. file() vs templatefile()
✅ file()
Reads a plain text file exactly as-is.

No interpolation or variable replacement.

Example:


user_data = file("${path.module}/grafana_user_data.sh")
✅ templatefile()
Reads a file and performs template interpolation using values you pass.

You can embed variables like ${prometheus_host} or ${region} directly in the file.

Example:


 Best Practice?
Use templatefile() when your user data script needs dynamic content (e.g., data source URLs, regions, custom tags).
Use file() only when the script is static.

✅ So in your case, since you're injecting Prometheus host and AWS region into the script — templatefile() is the way to go.


Tip: Replace APP_SERVER_PRIVATE_IP in the config
You can dynamically inject this in Terraform if needed, or use the localhost if your app exposes metrics locally.

you can also;

Install Node Exporter on instances for detailed OS-level metrics

Secure Prometheus with basic auth or firewall rules

Store Prometheus data in a custom directory with retention settings

# this checks if the userdata file exixts before executing
resource "aws_instance" "grafana" {
  ami                  = var.ami
  instance_type        = var.instance_type
  subnet_id            = var.subnet_id
  vpc_security_group_ids = var.security_group_ids
  key_name             = var.key_name
  iam_instance_profile = var.grafana_instance_profile

  tags = merge(var.tags, {
    Name = "${var.ResourcePrefix}-grafana"
  })

  user_data = fileexists("${path.module}/scripts/grafana_userdata.sh") ? templatefile("${path.module}/scripts/grafana_userdata.sh", {
    prometheus_host = var.prometheus_host
    region          = var.aws_region
  }) : null
}


this creates the prometheus instance first and makes it
dynamic so the grafana instance can use it

resource "aws_instance" "grafana" {
  ami                    = var.ami
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_ids
  key_name               = var.key_name
  iam_instance_profile   = var.grafana_instance_profile

  depends_on = [aws_instance.prometheus] # ✅ Ensure Prometheus comes first

  user_data = templatefile("${path.module}/scripts/grafana_userdata.sh", {
    prometheus_host = "http://${aws_instance.prometheus.private_ip}:9090", # ✅ Dynamic IP
    region          = var.aws_region
  })

  tags = merge(var.tags, {
    Name = "${var.ResourcePrefix}-Grafana"
  })
}

Optional Tip: Add a warning for missing script (if critical)
If you want to alert yourself during plan when the file is missing (instead of failing silently with null), you can do this:


locals {
  grafana_user_data = fileexists("${path.module}/scripts/grafana_userdata.sh")
    ? templatefile("${path.module}/scripts/grafana_userdata.sh", {
        prometheus_host = "http://${aws_instance.prometheus.private_ip}:9090",
        region          = var.aws_region
      })
    : (throw("Missing required grafana_userdata.sh script."))
}

resource "aws_instance" "grafana" {
  # ...
  user_data = local.grafana_user_data
}


#######################################################################
What to Do Before terraform apply
If using provisioners, you need to:
#######################################################################
1.Generate the prometheus.yml config using Terraform templatefile() + local_file.

2.Reference it in your file provisioner so it gets copied.

3.Restart Prometheus after it's copied.

# Directory structure:
# ├── monitoring/
# │   ├── prometheus.tf
# │   ├── grafana.tf
# │   ├── templates/
# │   │   └── prometheus.yml.tpl
# │   ├── generated/
# │   │   └── (this will be created by Terraform)
# │   ├── scripts/
# │   │   └── prometheus_userdata.sh

# Step 1: TEMPLATE (templates/prometheus.yml.tpl)
# This is your dynamic Prometheus config template:

/*
{{- $targets := join "," targets }}
global:
  scrape_interval: 15s

rule_files:
  - "/etc/prometheus/alert.rules.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'my_app'
    static_configs:
      - targets: [{{ $targets }}]
*/

# Step 2: TERRAFORM LOCALS (monitoring/prometheus.tf)
# this allows your config file to exist in generated/prometheus.yml ready to be copied
Generate the config as a Terraform local before launch
This can work if your Prometheus config only depends on other Terraform-managed instances. which step 3 takes care of.

locals {
  app_targets = [
    for instance in aws_instance.app_servers :
    "${instance.private_ip}:9100"
  ]

  prometheus_config = templatefile("${path.module}/templates/prometheus.yml.tpl", {
    targets = local.app_targets
  })
}

resource "local_file" "prometheus_config" {
  content  = local.prometheus_config
  filename = "${path.module}/generated/prometheus.yml"
}

# Step 3: EC2 + PROVISIONERS

resource "aws_instance" "prometheus" {
  ami                         = var.ami
  instance_type              = var.instance_type
  subnet_id                  = var.subnet_id
  vpc_security_group_ids     = var.security_group_ids
  key_name                   = var.key_name
  iam_instance_profile       = var.prometheus_instance_profile

  user_data = file("${path.module}/scripts/prometheus_userdata.sh")

  tags = merge(var.tags, {
    Name = "${var.ResourcePrefix}-Prometheus"
  })

  provisioner "file" {
    source      = "${path.module}/generated/prometheus.yml"
    destination = "/tmp/prometheus.yml"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.private_key_path)
      host        = self.public_ip
    }
  }

  provisioner "remote-exec" {       #so this will move the config file(prometheus.yml) from the templates directory to /etc/prometheus as shown on line 309
    inline = [
      "sudo mv /tmp/prometheus.yml /etc/prometheus/prometheus.yml",
      "sudo chown prometheus:prometheus /etc/prometheus/prometheus.yml",
      "sudo systemctl restart prometheus"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.private_key_path)
      host        = self.public_ip
    }
  }
}

# So once you combine steps 2 & 3, this sends the config file to your instance via provisioners.

# Step 4: USER DATA SCRIPT (scripts/prometheus_userdata.sh)

/*
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
*/

 # To secure your private_key_path and make sure your private keys or sensitive files don't accidentally get pushed to version control (like GitHub), follow these steps:

 Secure private_key_path in Terraform
🔹 1. Store it in terraform.tfvars or a secret file
Let’s say your variable is defined in variables.tf like this:

variable "private_key_path" {
  description = "Path to your private SSH key file"
  type        = string
}
Then in terraform.tfvars (or a custom .tfvars file), you’d store it like this:

private_key_path = "~/.ssh/my-private-key.pem"

 Add the file to .gitignore
In the root of your Terraform project, ensure your .gitignore file includes the following:

# Ignore Terraform variables file
terraform.tfvars
*.tfvars

# Optional: Ignore key files if stored in repo dir (not recommended!)
*.pem
*.key

# This ensures that:
Your SSH key path stays out of GitHub.
Even if the key file accidentally ends up in the same directory, it won't get committed.

# Use terraform.tfvars locally, not in CI/CD
Only use terraform.tfvars locally (never upload it to cloud-based storage or version control). In automation (like CI/CD), inject values via environment variables or secrets managers.

# Double-check Git
If you’ve ever added terraform.tfvars or a key file before creating the .gitignore, Git may still track it.

To stop tracking: 
git rm --cached terraform.tfvars
Then re-commit:
git commit -m "Stop tracking terraform.tfvars"


Step-by-step to add generated/ to .gitignore:
Open your project’s .gitignore file
If it doesn’t exist yet, create a file named .gitignore in the root of your Terraform project.

Add this line to the file:

bash
Copy
Edit
generated/
This tells Git to ignore the entire generated/ folder and everything inside it.

Remove any previously tracked files in generated/ (if applicable):

If prometheus.yml or the folder was already committed before, Git will continue tracking it even after updating .gitignore.

Run the following command to stop tracking it:

git rm -r --cached generated/
Commit the change:

git add .gitignore
git commit -m "Ignore generated Prometheus config files"

# Benefits of add generated/ to .gitignore
Keeps your Git repo clean.

Avoids accidentally committing runtime or environment-specific files.

Makes sure sensitive or machine-generated configs don’t clutter version history.


Suggestions to Improve or Clean It Up
1. Variable substitution:
You're using ${prometheus_host} and ${region} — make sure you're exporting them or passing them in:

bash
Copy
Edit
export prometheus_host="your.prometheus.ip.or.hostname"
export region="us-west-2"
Or pass them in as script arguments:

bash
Copy
Edit
#!/bin/bash
prometheus_host=$1
region=$2
Then call like:

bash
Copy
Edit
./setup_grafana.sh your-prometheus-host us-west-2
2. Avoid Duplicate EC2 Dashboard
You define the EC2 dashboard twice (once with -d inline, once with a <<EOF). Stick to one.

Just delete one of them — probably keep the EOF version for better readability.

3. Handle Grafana not being ready:
Instead of sleep 15 and sleep 20, consider checking if Grafana is ready with a loop:

bash
Copy
Edit
until curl -s http://localhost:3000/api/health | grep '"database": "ok"'; do
  echo "Waiting for Grafana..."
  sleep 5
done
4. Put dashboards in JSON files (optional best practice)
You could save each dashboard JSON to a dashboards/ folder and post them like this:

bash
Copy
Edit
curl -X POST http://admin:admin@localhost:3000/api/dashboards/db \
  -H "Content-Type: application/json" \
  -d @dashboards/ec2.json
That way:

You can reuse dashboards easily

Version-control them

And add dashboards/ to your .gitignore if generated

✅ .gitignore extension (as you asked earlier)
If you're generating dashboards from some automation and don’t want them in Git:

generated/
dashboards/
*.tmp
Add this to your .gitignore.



Item	Needed?	Why
Manually defining PROMETHEUS_HOST="localhost" in script	❌	Terraform injects the real IP dynamically
My suggested step to use a templatefile()	❌	You're already doing it properly
Placeholders in the script like ${prometheus_host}	✅	Required for dynamic substitution
Checking fileexists	✅	Great practice to avoid errors


 Here's why your setup works:
bash
Copy
Edit
curl -X POST http://admin:admin@localhost:3000/api/datasources \
  -H "Content-Type: application/json" \
  -d '{
        "name": "Prometheus",
        "type": "prometheus",
        "url": "http://${prometheus_host}:9090",
        "access": "proxy",
        "basicAuth": false
      }'
http://admin:admin@localhost:3000/api/datasources — authenticates using default Grafana credentials.

You’re dynamically injecting prometheus_host from Terraform — ✅

You're setting access: "proxy" — ✅ which is the right mode if Grafana should act as a proxy to Prometheus.

basicAuth: false — ✅ fine for local Prometheus without auth.

🔍 Just a couple of things to make sure of:
Grafana must be fully started before this curl runs — otherwise the API won’t be ready, and this call will fail.

You can add a retry/wait loop or delay like:

bash
Copy
Edit
until curl -s http://localhost:3000/api/health; do
  echo "Waiting for Grafana to start..."
  sleep 5
done
Only run this once, or make the script idempotent (e.g., check if the datasource already exists before trying to create it).

Security: Don’t leave the default admin:admin credentials in production. You can change it programmatically as well after setup.

✅ TL;DR
Your method of setting Prometheus as a data source using curl is totally fine — and even preferred in some automation workflows. Just make sure:

You inject prometheus_host dynamically (which you're doing) ✔️

Grafana is running when the command runs ✔️

You eventually change default credentials ✔️


Yes, that’s absolutely the right approach—and better than a fixed sleep 5!

Your loop:

bash
Copy
Edit
until curl -s http://localhost:3000/api/health; do
  echo "Waiting for Grafana to start..."
  sleep 5
done
💡 What it's doing:

Continuously checks Grafana’s health endpoint (/api/health)

Only proceeds once Grafana is fully up and ready to accept API requests

Prevents timing issues that can happen with a fixed sleep, especially in slower cloud-init or low-resource environments

🚀 Bonus Tip (optional): You can enhance it slightly by checking for a successful HTTP status code:

bash
Copy
Edit
until curl -s http://localhost:3000/api/health | grep -q '"database":"ok"'; do
  echo "Waiting for Grafana to be ready..."
  sleep 5
done

or this is fine too
until curl -s http://localhost:3000/api/health; do
  echo "Waiting for Grafana to start..."
  sleep 5
done


 Step 1: Store Values in SSM Parameter Store
🔹 Store prometheus_host
bash
Copy
Edit
aws ssm put-parameter \
  --name "/grafana/prometheus_host" \
  --type "String" \
  --value "http://localhost:9090" \
  --region us-west-2
🔹 Store region
Even though you could derive this from EC2 metadata, it can be handy to keep it consistent:

bash
Copy
Edit
aws ssm put-parameter \
  --name "/grafana/region" \
  --type "String" \
  --value "us-west-2" \
  --region us-west-2
✅ Step 2: Add IAM Permission to EC2 Role
Ensure your EC2 instance role has permission to read from SSM. Attach a policy like:

json
Copy
Edit
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameter"
      ],
      "Resource": [
        "arn:aws:ssm:us-west-2:<your-account-id>:parameter/grafana/*"
      ]
    }
  ]
}
📌 Replace <your-account-id> and us-west-2 with your actual values.

✅ Step 3: Fetch and Export in Your User Data Script
Put this in your Grafana User Data script:

bash
Copy
Edit
# Install jq and AWS CLI if not available (skip if already present)
yum install -y jq awscli

# Fetch values from SSM
region=$(aws ssm get-parameter --name "/grafana/region" --with-decryption --query "Parameter.Value" --output text --region us-west-2)
prometheus_host=$(aws ssm get-parameter --name "/grafana/prometheus_host" --with-decryption --query "Parameter.Value" --output text --region "$region")

# Export for script use
export region
export prometheus_host

# If using template.sh with envsubst
envsubst < /tmp/template.sh > /tmp/final.sh
chmod +x /tmp/final.sh
bash /tmp/final.sh



# final grafana copy

#!/bin/bash
set -e

# Install dependencies
yum install -y jq awscli gettext

# Fetch SSM parameters
region=$(aws ssm get-parameter --name "/grafana/region" --with-decryption --query "Parameter.Value" --output text --region us-east-1)
prometheus_host=$(aws ssm get-parameter --name "/grafana/prometheus_host" --with-decryption --query "Parameter.Value" --output text --region "$region")

export region
export prometheus_host

# Create final.sh from template
cat <<'EOF' > /tmp/template.sh
#!/bin/bash
echo "[INFO] Starting additional configuration..."
echo "Region: $region"
echo "Prometheus Host: $prometheus_host"

curl -s http://$prometheus_host:9090/api/v1/targets | jq '.'

echo "Setup run at $(date) with region $region and Prometheus host $prometheus_host" >> /var/log/grafana-init.log
echo "[INFO] Done running final.sh"
EOF

if [ -f /tmp/template.sh ]; then
  envsubst < /tmp/template.sh > /tmp/final.sh
  chmod +x /tmp/final.sh
  bash /tmp/final.sh
else
  echo "/tmp/template.sh not found!"
fi

# Fetch Grafana admin password from SSM
GRAFANA_ADMIN_PASSWORD=$(aws ssm get-parameter \
  --name "/grafana/admin_password" \
  --with-decryption \
  --query "Parameter.Value" \
  --output text)

# Install Grafana
amazon-linux-extras enable epel
yum install -y epel-release
yum install -y https://dl.grafana.com/oss/release/grafana-9.6.4-1.x86_64.rpm
systemctl daemon-reexec
systemctl enable grafana-server
systemctl start grafana-server

# Wait for Grafana to start
until curl -s http://localhost:3000/api/health | grep -q '"database":"ok"'; do
  echo "Waiting for Grafana to be ready..."
  sleep 15
done


# Add Prometheus as a data source
curl -X POST http://admin:admin:$GRAFANA_ADMIN_PASSWORD@localhost:3000/api/datasources \
  -H "Content-Type: application/json" \
  -d '{
        "name": "Prometheus",
        "type": "prometheus",
        "url": "http://${prometheus_host}:9090",
        "access": "proxy",
        "basicAuth": false
      }'

# Add CloudWatch as a data source
curl -X POST http://admin:admin:$GRAFANA_ADMIN_PASSWORD@localhost:3000/api/datasources \
  -H "Content-Type: application/json" \
  -d '{
        "name": "CloudWatch",
        "type": "cloudwatch",
        "access": "proxy",
        "jsonData": {
          "defaultRegion": "${region}"
        }
      }'


# ========== EC2 Dashboard ==========
curl -X POST http://admin:admin:$GRAFANA_ADMIN_PASSWORD@localhost:3000/api/dashboards/db \
  -H "Content-Type: application/json" \
  -d @- <<EOF
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
        "targets": [
          {
            "region": "${region}",
            "namespace": "AWS/EC2",
            "metricName": "CPUUtilization",
            "statistics": ["Average"],
            "period": 300,
            "refId": "A"
          }
        ],
        "gridPos": { "x": 0, "y": 0, "w": 24, "h": 8 }
      }
    ]
  },
  "overwrite": true
}
EOF

# ========== RDS Dashboard ==========
curl -X POST http://admin:admin:$GRAFANA_ADMIN_PASSWORD@localhost:3000/api/dashboards/db \
  -H "Content-Type: application/json" \
  -d @- <<EOF
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
        "targets": [
          {
            "region": "${region}",
            "namespace": "AWS/RDS",
            "metricName": "DatabaseConnections",
            "statistics": ["Average"],
            "period": 300,
            "refId": "A"
          }
        ],
        "gridPos": { "x": 0, "y": 0, "w": 24, "h": 8 }
      }
    ]
  },
  "overwrite": true
}
EOF

# ========== VPC Dashboard ==========
curl -X POST http://admin:admin:$GRAFANA_ADMIN_PASSWORD@localhost:3000/api/dashboards/db \
  -H "Content-Type: application/json" \
  -d @- <<EOF
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
        "targets": [
          {
            "region": "${region}",
            "namespace": "AWS/VPC",
            "metricName": "Bytes",
            "dimensions": {
              "TrafficType": "ACCEPT"
            },
            "statistics": ["Sum"],
            "period": 300,
            "refId": "A"
          }
        ],
        "gridPos": { "x": 0, "y": 0, "w": 12, "h": 8 }
      },
      {
        "type": "stat",
        "title": "VPC Rejected Bytes",
        "datasource": "CloudWatch",
        "targets": [
          {
            "region": "${region}",
            "namespace": "AWS/VPC",
            "metricName": "Bytes",
            "dimensions": {
              "TrafficType": "REJECT"
            },
            "statistics": ["Sum"],
            "period": 300,
            "refId": "B"
          }
        ],
        "gridPos": { "x": 12, "y": 0, "w": 12, "h": 8 }
      }
    ]
  },
  "overwrite": true
}
EOF

# ========== Prometheus App Metrics ==========
curl -X POST http://admin:admin:$GRAFANA_ADMIN_PASSWORD@localhost:3000/api/dashboards/db \
  -H "Content-Type: application/json" \
  -d @- <<EOF
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
        "targets": [
          {
            "expr": "rate(http_requests_total[1m])",
            "legendFormat": "req/sec",
            "refId": "A"
          }
        ],
        "gridPos": { "x": 0, "y": 0, "w": 24, "h": 8 }
      }
    ]
  },
  "overwrite": true
}
EOF


# Import Kubernetes EKS Cluster (Prometheus) Dashboard
curl -X POST http://admin:admin:$GRAFANA_ADMIN_PASSWORD@localhost:3000/api/dashboards/import \
  -H "Content-Type: application/json" \
  -d '{
    "dashboard": {
      "id": 17119,
      "uid": null,
      "title": "Kubernetes EKS Cluster (Prometheus)",
      "tags": [],
      "timezone": "browser",
      "schemaVersion": 16,
      "version": 0
    },
    "overwrite": true,
    "inputs": [
      {
        "name": "DS_PROMETHEUS",
        "type": "datasource",
        "pluginId": "prometheus",
        "value": "Prometheus"
      }
    ]
  }'


# Import Kubernetes EKS Cluster (CloudWatch) Dashboard
curl -X POST http://admin:admin:$GRAFANA_ADMIN_PASSWORD@localhost:3000/api/dashboards/import \
  -H "Content-Type: application/json" \
  -d '{
    "dashboard": {
      "id": 16028,
      "uid": null,
      "title": "Kubernetes EKS Cluster (CloudWatch)",
      "tags": [],
      "timezone": "browser",
      "schemaVersion": 16,
      "version": 0
    },
    "overwrite": true,
    "inputs": [
      {
        "name": "DS_CLOUDWATCH",
        "type": "datasource",
        "pluginId": "cloudwatch",
        "value": "CloudWatch"
      }
    ]
  }'
  


# earlier copy of locals
locals {
  app_targets = [
    for instance in aws_instance.app_servers : "${instance.private_ip}:9100"
  ]

  prometheus_config = templatefile("${path.module}/templates/prometheus.yml.tpl", {
    targets = local.app_targets
  })


  prometheus_user_data = fileexists("${path.module}/scripts/prometheus_userdata.sh") ?
    file("${path.module}/scripts/prometheus_userdata.sh") : null

  grafana_user_data = fileexists("${path.module}/scripts/grafana_userdata.sh") ?
    file("${path.module}/scripts/grafana_userdata.sh") : null


 provisioner_connection = {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(var.private_key_path)
  }
}

provisioner "file" {
    source      = "${path.module}/generated/prometheus.yml"
    destination = "/tmp/prometheus.yml"

    connection = merge(local.provisioner_connection, { host = self.private_ip })  # use public ip if prometheus and grafana are in different VPCs

  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/prometheus.yml /etc/prometheus/prometheus.yml",
      "sudo chown prometheus:prometheus /etc/prometheus/prometheus.yml",
      "sudo systemctl restart prometheus"
    ]

    connection = merge(local.provisioner_connection, { host = self.private_ip })

  }
}







Corrected references should be:
Locals:

hcl
Copy
Edit
locals {
  app_targets = [
    for ip in data.aws_instances.app_servers.private_ips : "${ip}:9100"
  ]
}
Prometheus depends_on:

hcl
Copy
Edit
depends_on = [data.aws_instances.app_servers]
Grafana depends_on: If you want Grafana to wait for Prometheus EC2 to be created, you already have the resource aws_instance.prometheus, so use:

hcl
Copy
Edit
depends_on = [aws_instance.prometheus]

Great question! After you push your Terraform code to GitHub without the .tfvars file, here’s how you (or others) can still run Terraform safely and flexibly:

🔁 Options for Supplying Sensitive Variables (like private_key_path)
✅ 1. Pass with -var flag (quick and explicit):
bash
Copy
Edit
terraform plan -var="private_key_path=/home/user/.ssh/my-key.pem"
This is ideal for ad-hoc runs or CI/CD systems where you don't want to rely on files.

✅ 2. Create a terraform.tfvars locally (but don’t commit it):
hcl
Copy
Edit
# terraform.tfvars (excluded via .gitignore)
private_key_path = "/home/user/.ssh/my-key.pem"
Terraform picks this up automatically when you run plan or apply.

✅ 3. Use environment variables (for automation or CI/CD):
Set the variable as:

bash
Copy
Edit
export TF_VAR_private_key_path="/home/user/.ssh/my-key.pem"
Then Terraform will automatically detect it:

bash
Copy
Edit
terraform plan
🧠 Best Practice Flow for GitHub Projects

Stage	What You Do
Development	Use terraform.tfvars locally for convenience
GitHub Push	Exclude sensitive files via .gitignore
Deployment	Pass vars via -var, -var-file, or environment vars
CI/CD	Use secret storage + env variables


prometheus config.yml.tpl (was stored in templates earlier)
{{- $quoted := list }}
{{- range $i, $t := .targets }}
  {{- $quoted = append $quoted (printf "\"%s\"" $t) }}
{{- end }}

global:
  scrape_interval: 15s

rule_files:
  - "/etc/prometheus/alert.rules.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'my_app'
    static_configs:
      - targets: [{{ join ", " $quoted }}]


# Another option is to use user_data to install Prometheus and Grafana using a script.
# Prometheus and Granfana Configuration setup will be done using ansible via user_data in the script directory.

 # user_data = templatefile("./tools-install.sh", {}) # will try this later

# Reasons to Separate Prometheus and Grafana in Production
# Resource Isolation:

# Prometheus is write-heavy (scraping, TSDB compaction).

# Grafana is read-heavy (dashboards, user traffic).

# Mixing both can cause performance issues.

# Security Separation:

# Grafana may be internet-facing or accessed by users.

# Prometheus should be protected (contains internal metrics, scraping logic).

# Scalability:

# Independent scaling: more Prometheus nodes for metrics, more Grafana nodes for queries.

# Easier to manage HA setups.

# Service Boundaries:

# Grafana can pull data from multiple Prometheus instances, CloudWatch, Loki, etc.

# Keeping services separate improves flexibility.

#  Examples
# 1. Development Setup
# 1 EC2 instance with:

# Prometheus

# Grafana

# Node Exporter

# Pros: fast, simple.

# Cons: not scalable.

# 2. Production Setup
# EC2-1: Prometheus + Node Exporter

# EC2-2: Grafana

# Optional:

# EC2-3: Alertmanager

# S3: remote TSDB storage (via Thanos)

# ALB: load-balanced Grafana frontend

# ✅ Recommendation for Your Case
# Given that:

# You’re on AWS EC2

# You’re handling production-grade monitoring

# You already have Terraform and Ansible in use

# I recommend:

# Component	Host
# Prometheus	Dedicated EC2 instance (with EBS volume for metrics)
# Grafana	Separate EC2 instance
# Node Exporter	Every monitored instance
# Alertmanager	Optional but separate EC2 or container
# Pushgateway	If needed for short-lived jobs (optional)