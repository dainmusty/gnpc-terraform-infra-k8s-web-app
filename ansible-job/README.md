roles/
└── grafana/
    ├── tasks/
    │   ├── main.yml
    │   ├── install.yml
    │   ├── configure.yml
    │   └── dashboards.yml
    ├── files/
    │   └── dashboards/
    │       ├── ec2.json
    │       ├── rds.json
    │       └── app-metrics.json
    └── templates/
        └── grafana.repo.j2


# Ansible Job - grafana dashboards
# == FILE: ansible/playbooks/grafana.yml ==
- name: Configure Grafana with datasources and dashboards
  hosts: tag_Name_Grafana  # Assuming your EC2 instance is tagged Name=Grafana
  become: true
  vars:
    grafana_admin_password_ssm_param: "/grafana/admin/password"
    aws_region: "us-east-1"
  roles:
    - grafana

# == FILE: ansible/inventories/aws_ec2.yml ==
plugin: amazon.aws.aws_ec2
regions:
  - us-east-1
filters:
  tag:Name:
    - Grafana
keyed_groups:
  - key: tags.Name
    prefix: tag_Name
hostnames:
  - private-ip-address

# == FILE: ansible/roles/grafana/tasks/main.yml ==
- name: Include configuration tasks
  include_tasks: configure.yml

- name: Set admin password from SSM
  include_tasks: set_admin_password.yml

# == FILE: ansible/roles/grafana/tasks/configure.yml ==
- name: Ensure required Python packages are installed
  ansible.builtin.pip:
    name:
      - boto3
      - botocore
      - requests

- name: Install community.grafana collection
  ansible.builtin.ansible.builtin.include_role:
    name: community.grafana

- name: Add Prometheus datasource
  community.grafana.grafana_datasource:
    name: Prometheus
    ds_type: prometheus
    url: "http://{{ hostvars[groups['tag_Name_Prometheus'][0]]['ansible_host'] }}:9090"
    access: proxy
    state: present
    grafana_url: http://localhost:3000
    grafana_user: admin
    grafana_password: "{{ grafana_admin_password }}"

- name: Add CloudWatch datasource
  community.grafana.grafana_datasource:
    name: CloudWatch
    ds_type: cloudwatch
    access: proxy
    json_data:
      defaultRegion: "{{ aws_region }}"
    grafana_url: http://localhost:3000
    grafana_user: admin
    grafana_password: "{{ grafana_admin_password }}"

- name: Upload predefined dashboards
  community.grafana.grafana_dashboard:
    grafana_url: http://localhost:3000
    grafana_user: admin
    grafana_password: "{{ grafana_admin_password }}"
    dashboard_file: "{{ item }}"
    state: present
  loop:
    - "{{ role_path }}/files/dashboards/ec2-dashboard.json"
    - "{{ role_path }}/files/dashboards/rds-dashboard.json"
    - "{{ role_path }}/files/dashboards/vpc-dashboard.json"
    - "{{ role_path }}/files/dashboards/app-metrics.json"

# == FILE: ansible/roles/grafana/tasks/set_admin_password.yml ==
- name: Fetch Grafana admin password from AWS SSM
  amazon.aws.aws_ssm:
    name: "{{ grafana_admin_password_ssm_param }}"
    region: "{{ aws_region }}"
    decrypt: true
  register: ssm_password

- set_fact:
    grafana_admin_password: "{{ ssm_password.parameter.value }}"

# == EXAMPLE DASHBOARD FILE: ansible/roles/grafana/files/dashboards/ec2-dashboard.json ==
# (Use the existing JSON you already had in your user-data)
# You can export and reuse them from Grafana UI or script them here.

# == To Run ==
# ansible-playbook -i inventories/aws_ec2.yml playbooks/grafana.yml


✅ Recommended Flow
Terraform:

Provisions EC2 instances with correct AMIs and roles.

Adds minimal user-data to install Ansible (or agent like SSM).

Tags resources for Ansible dynamic inventory.

Ansible:

Installs Grafana, Prometheus, Node Exporter.

Adds service configuration, systemd overrides, etc.

Templatizes and pushes dashboards, Prometheus rules, etc.

ansible/
├── inventories/
│   └── aws_ec2.yml               # dynamic inventory
├── playbooks/
│   ├── prometheus.yml            # installs Prometheus and Node Exporter
│   └── grafana.yml               # installs Grafana and provisions dashboards
├── roles/
│   ├── prometheus/
│   │   ├── tasks/
│   │   │   └── main.yml
│   │   └── templates/
│   │       └── prometheus.yml.j2
│   ├── node_exporter/
│   │   └── tasks/
│   ├── grafana/
│   │   ├── tasks/
│   │   │   ├── install.yml
│   │   │   ├── configure_datasources.yml
│   │   │   ├── configure_dashboards.yml
│   │   │   └── main.yml
│   │   └── files/  # dashboards in JSON
└── requirements.yml
