# GitHub Actions Workflow Modules for Two Scenarios

This document outlines two CI/CD workflow modules suitable for different business sizes and infrastructure needs. The workflows utilize GitHub Actions to provision infrastructure and deploy monitoring and GitOps tooling.

---

## 🔹 Scenario 1: Startup on Budget (No EKS)

**Use case:** For startups that cannot afford managed Kubernetes (EKS), we use EC2 instances, Terraform for provisioning, and Ansible to configure Prometheus and Grafana.

### 🔧 Stack Overview

* **Infrastructure:** AWS EC2 (via Terraform)
* **Configuration Management:** Ansible (with dynamic AWS inventory)
* **Monitoring:** Prometheus + Grafana (installed on EC2)

### 📂 Project Structure

```
├── ansible/
│   ├── inventory/
│   │   └── aws_ec2.yml       # Dynamic EC2 inventory
│   ├── playbooks/
│   │   └── setup-prometheus.yml
│   └── roles/                # Optional: Reusable Ansible roles
├── terraform-infra/
│   └── environments/
│       └── dev/
│           └── main.tf
└── .github/workflows/
    └── terraform-ansible.yml  # Workflow definition
```

### 🛠️ terraform-ansible.yml

```yaml
name: Terraform + Ansible Deploy

on:
  push:
    branches:
      - dev

jobs:
  terraform:
    name: Deploy Infra with Terraform
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repo
        uses: actions/checkout@v4

      - name: Set up Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.6.6

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1

      - name: Terraform Init & Apply
        working-directory: env/dev
        run: |
          terraform init -input=false
          terraform apply -auto-approve -input=false

  ansible:
    name: Configure Prometheus with Ansible
    needs: terraform
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repo
        uses: actions/checkout@v4

      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y ansible python3-boto3 python3-botocore

      - name: Set up SSH private key
        run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.ANSIBLE_SSH_KEY }}" > ~/.ssh/id_rsa
          chmod 600 ~/.ssh/id_rsa

      - name: Create Ansible config
        run: |
          echo '[defaults]' > ansible.cfg
          echo 'inventory = ansible/inventory/aws_ec2.yml' >> ansible.cfg
          echo 'host_key_checking = False' >> ansible.cfg
          echo 'remote_user = ubuntu' >> ansible.cfg

      - name: Run Ansible Playbook
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        run: |
          ansible-playbook ansible/playbooks/setup-prometheus.yml
```

---

## 🔹 Scenario 2: Enterprise with EKS + GitOps

**Use case:** This pipeline is built for enterprises deploying full Kubernetes infrastructure using EKS and GitOps via ArgoCD.

### 🔧 Stack Overview

* **Infrastructure:** EKS (via Terraform)
* **GitOps Tool:** ArgoCD
* **Monitoring:** kube-prometheus-stack (Prometheus + Grafana via Helm)
* **Security Scans:** Trivy, OWASP, SonarCloud

### 🛠️ GitHub Actions Workflow: `main` branch

```yaml
name: Full CI/CD Pipeline

on:
  push:
    branches:
      - main
  pull_request:

env:
  AWS_REGION: us-east-1
  CLUSTER_NAME: effulgencetech-dev
  SONAR_PROJECT_KEY: dainmusty_gnpc-terraform-infra-k8s-web-app
  SONAR_ORGANIZATION: effulgencetech

jobs:
  security-scan:
    name: Run Security Scans (Trivy + OWASP + SonarCloud)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Trivy Filesystem Scan
        uses: aquasecurity/trivy-action@0.28.0
        with:
          scan-type: fs
          scan-ref: .
          ignore-unfixed: true
          severity: CRITICAL,HIGH

      - name: OWASP Dependency-Check
        uses: dependency-check/Dependency-Check_Action@main
        with:
          project: 'effulgencetech'
          path: '.'
          format: 'HTML'
          out: 'reports'
          args: >
            --failOnCVSS 7
            --enableRetired

      - name: Upload OWASP Report
        uses: actions/upload-artifact@v4
        with:
          name: OWASP Depcheck Report
          path: reports

  sonarcloud:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install SonarCloud Scanner
        run: |
          curl -sSLo sonar-scanner.zip https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-5.0.1.3006-linux.zip
          unzip -q sonar-scanner.zip
          echo "$PWD/sonar-scanner-5.0.1.3006-linux/bin" >> $GITHUB_PATH

      - name: SonarCloud Scan
        env:
          SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
        run: |
          sonar-scanner \
            -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
            -Dsonar.organization=${SONAR_ORGANIZATION} \
            -Dsonar.branch.name=${GITHUB_REF_NAME} \
            -Dsonar.sources=. \
            -Dsonar.host.url=https://sonarcloud.io \
            -Dsonar.login=$SONAR_TOKEN

  terraform:
    name: Deploy Infra with Terraform
    runs-on: ubuntu-latest
    needs: security-scan
    steps:
      - uses: actions/checkout@v4

      - name: Set up Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.6.6

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Terraform Init
        working-directory: env/dev
        run: terraform init -input=false

      - name: Create EKS Cluster Stack
        working-directory: env/dev
        run: |
          terraform apply \
            --auto-approve \
            -target=module.eks.aws_cloudformation_stack.eks_cluster_stack

      - name: Update kubeconfig
        run: |
          aws eks update-kubeconfig --region ${{ env.AWS_REGION }} --name ${{ env.CLUSTER_NAME }}

      - name: Terraform Full Apply
        working-directory: env/dev
        run: terraform apply --auto-approve

      - name: Check ArgoCD Status
        run: |
          echo "Checking ArgoCD pods..."
          kubectl get pods -n argocd
          kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=120s

  deploy-k8s:
    name: ArgoCD Sync
    runs-on: ubuntu-latest
    needs: terraform
    steps:
      - uses: actions/checkout@v4

      - name: Set Git user
        run: |
          git config user.name github-actions[bot]
          git config user.email github-actions[bot]@users.noreply.github.com

      - name: Pull & Push to Trigger ArgoCD Sync
        env:
          GH_PAT: ${{ secrets.GH_PAT }}
        run: |
          git pull --rebase origin main
          git remote set-url origin https://x-access-token:${GH_PAT}@github.com/dainmusty/gnpc-terraform-infra-k8s-web-app.git
          git push origin main

      - name: Optional: Trigger Sync
        run: |
          git commit --allow-empty -m "Trigger ArgoCD sync" || echo "No changes to commit"
```

---

### 🔐 Notes on GitHub Token Errors

If you encounter:

```
remote: Permission denied to github-actions[bot]
```

**Fix:**

* Go to `Repo → Settings → Actions → Workflow Permissions`
* Choose: "Read and Write"

Alternatively, use a **personal access token (PAT)** via `GH_PAT` secret.

---

# Manual Destroy
🔥 Manual Terraform Destroy Workflow
This GitHub Actions workflow allows a developer or DevOps engineer to manually trigger the destruction of Terraform-managed infrastructure via the GitHub Actions UI. It uses the workflow_dispatch trigger, making it suitable for controlled teardown operations in non-production environments (like dev or test).

📜 Workflow Summary

name: Terraform Init and Destroy by Manual Trigger
on:
  workflow_dispatch: # Manual trigger for Terraform destroy
✅ Purpose
Safely destroy infrastructure using terraform destroy in environments like env/dev

Run only on manual invocation to prevent accidental teardown during CI/CD runs

Useful during cleanup, cost control, or environment resets

⚙️ Key Components
Terraform Setup: Uses HashiCorp’s setup action to install the required version.

AWS Credentials: Injected via GitHub secrets to authorize infrastructure operations.

Terraform Init: Initializes the backend and prepares the working directory.

Terraform Destroy: Tears down all infrastructure in the targeted environment.

📌 Best Practices
Keep this workflow disabled or scoped to non-prod branches unless you're explicitly managing test environments.

Consider adding confirmation prompts or approvals using environment protection rules in GitHub if this is exposed to multiple users.

You can customize the working-directory (currently set to env/dev) to destroy other environments like staging or sandbox.

