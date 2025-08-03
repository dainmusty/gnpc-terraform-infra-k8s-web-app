name: Terraform Plan and Apply

on:
  pull_request:
    branches:
      - dev
      - staging
  push:
    branches:
      - dev
      - staging

env:
  AWS_REGION: us-east-1
  TERRAFORM_VERSION: '1.6.6'

jobs:
  set-env:
    runs-on: ubuntu-latest
    outputs:
      env: ${{ steps.set_env.outputs.env }}
    steps:
      - name: Determine environment
        id: set_env
        run: |
          if [[ "${GITHUB_REF##*/}" == "dev" ]]; then
            echo "env=dev" >> $GITHUB_OUTPUT
          else
            echo "env=staging" >> $GITHUB_OUTPUT
          fi

  terraform:
    needs: set-env
    runs-on: ubuntu-latest
    defaults:
      run:
        shell: bash

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TERRAFORM_VERSION }}

      - name: Install TFLint
        run: |
          curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash

      - name: Run TFLint
        working-directory: terraform-infra/environments/${{ needs.set-env.outputs.env }}
        run: |
          tflint --init
          tflint --enable-rule=aws_instance_invalid_type

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Terraform Init
        working-directory: terraform-infra/environments/${{ needs.set-env.outputs.env }}
        run: terraform init -input=false

      - name: Terraform Plan or Apply
        working-directory: terraform-infra/environments/${{ needs.set-env.outputs.env }}
        run: |
          if [[ "${{ github.event_name }}" == "push" ]]; then
            terraform apply -auto-approve
          else
            terraform plan



.
├── ansible/
│   ├── inventory/
│   │   └── aws_ec2.yml       # Your dynamic inventory file
│   ├── playbooks/
│   │   └── setup-prometheus.yml
│   └── roles/                # Optional: for reusable tasks
├── terraform-infra/
│   └── environments/
│       └── dev/
│           └── main.tf
└── .github/workflows/
    └── terraform-ansible.yml  # This workflow file


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


For a production-grade, fully automated CI/CD pipeline, it is generally best to install and configure ArgoCD as part of your infrastructure provisioning, not as part of your pipeline runner (GitHub Actions job). Thus, use Ansible (or Terraform) to install ArgoCD during infra setup, rather than installing it in the pipeline runner.

Why?
Declarative, Repeatable, Auditable:
Managing ArgoCD installation via Ansible or Terraform ensures the install is idempotent, versioned, and reproducible across environments.
Separation of Concerns:
Your CI/CD pipeline should trigger GitOps syncs, not manage cluster software installs directly. The cluster should already have all needed tools (including ArgoCD) before application deployments run.
Security:
Installing cluster software from a pipeline runner (with cluster-admin permissions) increases risk. Infra-as-code tools can manage permissions more securely.


Your Pipeline (Recommended Flow):
Terraform: Provisions EKS and core infrastructure.
Ansible: Configures infra and installs software like ArgoCD (and Prometheus) onto EKS.
GitHub Actions: Builds, tests, pushes images, and commits changes to trigger ArgoCD sync.
ArgoCD: Detects changes in the Git repo and deploys to EKS.
Summary Table
Tool	What it Should Handle
Terraform	Cluster, networking, IAM, storage, etc.
Ansible	Cluster software install (ArgoCD, Prometheus, etc)
GitHub Actions	App build, push, infra trigger, ArgoCD sync trigger
ArgoCD	App deployment to cluster (GitOps)

ArgoCD is designed to be installed and run inside a Kubernetes cluster, not on a standalone EC2 instance.

Details:
Intended Architecture:
ArgoCD is a Kubernetes-native GitOps tool. It manages Kubernetes manifests and resources by running controllers and APIs inside a Kubernetes cluster.
Installation Target:
EKS cluster: ✅ Yes, ArgoCD is meant to run as a set of Pods (Deployments, Services, etc.) inside your EKS (or any Kubernetes) cluster.
Regular EC2 instance: 🚫 Not recommended, not supported.
You cannot (and should not) install ArgoCD as a systemd service or standalone binary on a raw EC2 Linux host; it expects Kubernetes APIs and objects.
How does ArgoCD work?
It runs as a Kubernetes Deployment in your cluster.
It watches your Git repositories for changes.
It applies changes to the cluster it is running in (or to other clusters, if configured for multi-cluster).
What if you only have EC2 (no Kubernetes)?
You cannot use ArgoCD unless you have a Kubernetes cluster running (EKS, self-managed k8s, etc.).
If you need GitOps for non-Kubernetes workloads (e.g., EC2-only infra), consider other tools (like Ansible, Terraform, or Spacelift).
Summary:

ArgoCD must be installed on a Kubernetes cluster (like EKS), not directly on a regular EC2 instance.
You can use an EC2 instance as a Kubernetes node, but ArgoCD itself is always a set of Kubernetes resources.


Step 2 – Prepare the Terraform creation workflow
You can find the workflow file here.

This workflow will run on pull requests, and main branch merges whenever there are changes to the Terraform directory in the repository. For pull requests, it will also show the plan as a PR comment.

The workflow does the following:

Checks out the code
Sets up Terraform
Sets up the AWS credentials
Runs terraform init
Runs terraform validate to ensure the configuration is valid
Runs terraform fmt to check if the code is formatted correctly
Runs a terraform plan and comments on the plan on a PR only on pull requests
Runs a terraform apply on a master branch push

# old plan - terraform with ansible to install grafana and prometheus
name: Full CI/CD Pipeline

on:
  push:
    branches:
      - dev

env:
  AWS_REGION: us-east-1
  CLUSTER_NAME: effulgencetech-dev
  SONAR_PROJECT_KEY: gnpc-terraform-infra-k8s-web-app
  SONAR_HOST_URL: https://sonarcloud.io/project/overview?id=dainmusty_gnpc-terraform-infra-k8s-web-app

jobs:
  security-scan:
    name: Run Security Scans (Trivy + OWASP + SonarQube)
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Trivy Scan for filesystem & Dockerfile
        uses: aquasecurity/trivy-action@v0.16.1
        with:
          scan-type: fs
          scan-ref: .
          ignore-unfixed: true
          severity: CRITICAL,HIGH

      - name: OWASP Dependency-Check
        uses: dependency-check/Dependency-Check_Action@main
        with:
          format: "HTML"
          failOnCVSS: 7

      - name: SonarQube Scan
        uses: SonarSource/sonarcloud-github-action@v2
        with:
          projectKey: ${{ env.SONAR_PROJECT_KEY }}
          organization: my-org
          token: ${{ secrets.SONAR_TOKEN }}
          args: >
            -Dsonar.projectKey=${{ env.SONAR_PROJECT_KEY }}
            -Dsonar.organization=my-org
            -Dsonar.host.url=${{ env.SONAR_HOST_URL }}

  docker-build-push:
    name: Build & Push Docker Image
    runs-on: ubuntu-latest
    needs: security-scan
    steps:
      - uses: actions/checkout@v4

      - name: Login to Docker Hub
        run: |
          echo "${{ secrets.DOCKER_PASSWORD }}" | docker login -u "${{ secrets.DOCKER_USERNAME }}" --password-stdin

      - name: Build and Push Docker image
        run: |
          docker build -t dainmusty/effulgencetech-nodejs-img:${{ github.sha }} .
          docker push dainmusty/effulgencetech-nodejs-img:${{ github.sha }}

  terraform:
    name: Deploy Infra with Terraform
    runs-on: ubuntu-latest
    needs: docker-build-push
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

      - name: Terraform Init & Apply
        working-directory: env/dev
        run: |
          terraform init -input=false
          terraform apply --auto-approve -target=aws_cloudformation_stack.eks_cluster_stack -input=false
          terraform apply --auto-approve

  ansible:
    name: Configure Infra with Ansible
    runs-on: ubuntu-latest
    needs: terraform
    steps:
      - uses: actions/checkout@v4

      - name: Ensure Python 3.9+ and pip are installed
        run: |
          sudo apt-get update
          sudo apt-get install -y software-properties-common
          sudo add-apt-repository ppa:deadsnakes/ppa -y
          sudo apt-get update
          sudo apt-get install -y python3.9 python3.9-venv python3.9-distutils
          curl -sS https://bootstrap.pypa.io/get-pip.py | sudo python3.9

      - name: Install Ansible, boto3, and botocore using Python 3.9
        run: |
          python3.9 -m pip install --upgrade pip
          python3.9 -m pip install ansible boto3 botocore

      - name: Set up SSH private key
        run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.ANSIBLE_SSH_KEY }}" > ~/.ssh/id_rsa
          chmod 600 ~/.ssh/id_rsa

      - name: Configure remote_user for Ansible (Amazon Linux 2023)
        run: echo 'remote_user = ec2-user' >> ansible.cfg

      - name: Run Ansible Playbook
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        run: |
          ansible-playbook ansible/playbooks/setup-prometheus.yml

  deploy-k8s:
    name: ArgoCD Sync
    runs-on: ubuntu-latest
    needs: ansible
    steps:
      - uses: actions/checkout@v4

      - name: Commit and push changes to trigger ArgoCD
        run: |
          git config user.name "github-actions"
          git config user.email "actions@github.com"
          git commit --allow-empty -m "Trigger ArgoCD sync"
          git push origin dev

# security-scan → docker-build-push → terraform → deploy-k8s.

# to update the sonarqube project key
go to sonarcloud,go to your project, go to admin and then update key

# to run the CI, you need to put off automatic analysis in sonarcloud otherwise there is a conflict


# use this workflow if you want to trigger argo automatically

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
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Trivy Filesystem Scan
        uses: aquasecurity/trivy-action@0.28.0
        with:
          scan-type: fs
          scan-ref: .
          ignore-unfixed: true
          severity: CRITICAL,HIGH

      - name: OWASP Dependency-Check
        uses: dependency-check/Dependency-Check_Action@main
        id: Depcheck
        with:
          project: 'effulgencetech'
          path: '.'
          format: 'HTML'
          out: 'reports'
          args: >
            --failOnCVSS 7
            --enableRetired

      - name: Upload OWASP Dependency-Check Report
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

      - name: Create EKS Cluster Stack (Targeted)
        working-directory: env/dev
        run: |
          terraform apply \
            --auto-approve \
            -target=module.eks.aws_cloudformation_stack.eks_cluster_stack

      - name: Update kubeconfig for EKS
        run: |
          aws eks update-kubeconfig --region ${{ env.AWS_REGION }} --name ${{ env.CLUSTER_NAME }}

      - name: Terraform Full Apply (Post Cluster)
        working-directory: env/dev
        run: terraform apply --auto-approve

      - name: Check ArgoCD Status
        run: |
          echo "Checking ArgoCD pods status..."
          kubectl get pods -n argocd
          echo "Waiting for ArgoCD server pod to be ready..."
          kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=120s

  deploy-k8s:
    name: ArgoCD Sync
    runs-on: ubuntu-latest
    needs: terraform

    steps:
      - uses: actions/checkout@v4

      - name: Set up Git user
        run: |
          git config user.name github-actions[bot]
          git config user.email github-actions[bot]@users.noreply.github.com

      - name: Pull latest before pushing
        run: |
          git pull --rebase origin main

      - name: Push changes
        env:
          GH_PAT: ${{ secrets.GH_PAT }}
        run: |
          git remote set-url origin https://x-access-token:${GH_PAT}@github.com/dainmusty/gnpc-terraform-infra-k8s-web-app.git
          git push origin main


🔚 Conclusion
✅ Best Practice: Use Git push to trigger changes, and let ArgoCD apply everything. No kubectl apply needed in GitHub Actions.

You're on the right track — if you need help setting up validation steps in CI or Helm templating next, just say the word.








You said:
so i don't need anything to the workflow right? and once the workflow is complete, my job is to manually run kubectl apply -f k8s/dev/fonapp-argocd-app.yaml -n argocd right and then that's it?


ChatGPT said:
You're 99% correct — let's break it down clearly:

✅ Once You’re Using ArgoCD, Your Workflow Should Be:
1. Your GitHub Actions Workflow (CI)
✅ Run linting, testing, scanning, etc.

✅ Push any changes (infra or manifests) to GitHub repo.

❌ No kubectl apply in the workflow for app manifests.

✅ This triggers ArgoCD via the Application you created.

🔁 ArgoCD automatically syncs the manifests from the Git repo to your cluster.

❗️One-Time Manual Step (Bootstrap)
Yes — this is the only time you manually run:

bash
Copy
Edit
kubectl apply -f k8s/dev/fonapp-argocd-app.yaml -n argocd
This creates the ArgoCD Application resource (like a “watcher”) that monitors the k8s/fonapp/ path in GitHub and syncs everything there to the fonapp namespace.

✅ After that, no more kubectl apply ever needed — just update the repo.

🚀 So in summary:
Task	How Often?	Who/What Does It?
Create ArgoCD Application	Once	Manually (kubectl apply -f fonapp-argocd-app.yaml)
Push manifest changes to Git	Often	You / GitHub Actions
Apply manifests to cluster	Auto	ArgoCD syncs Git to cluster
Add validation/scans/tests	Optional	GitHub Actions

🟢 You're Done
You’re in a proper GitOps loop now:

Change YAML in Git

GitHub Actions pushes to main

ArgoCD sees it and syncs automatically

You monitor status in ArgoCD UI or CLI

Let me know if you want to:

 To directly answer your question:
Your current GitHub Actions workflow does not yet include ArgoCD webhook integration. However, it’s mostly following best practices, and I’ll explain exactly what’s covered and what’s missing.

✅ What You're Doing Right
✅ 1. Security Scanning Early
Trivy + OWASP + SonarCloud — excellent for security and quality gates.

✅ 2. Terraform Infrastructure Automation
terraform apply --target=... → good approach for building infra incrementally.

Cluster provisioning + kubeconfig update is handled properly.

✅ 3. Syncing K8s via ArgoCD (Manually or Declaratively)
You’ve chosen to register applications using declarative manifests (fonapp-argocd-app.yaml) — this is best practice.

You did not include kubectl apply in the pipeline, which is fine if you do it once manually and let ArgoCD auto-sync afterward.

⚠️ What’s Missing or Could Be Improved
⚠️ 1. ArgoCD Sync Triggering Is Not Automatic Yet
You currently don’t force sync ArgoCD after new commits. You rely on ArgoCD polling the repo. That’s okay but slow (default is 3 min interval).

Better alternatives:

ArgoCD Webhook integration: Instant sync on push (recommended).

Or, add a job using the argocd app sync CLI.

Verdict: ✅ Best to add a GitHub → ArgoCD webhook.

⚠️ 2. Manual kubectl apply for ArgoCD Application
You currently have to run:

bash
Copy
Edit
kubectl apply -f k8s/dev/fonapp-argocd-app.yaml -n argocd
That’s fine if you do it once and the file lives in Git. But for fully automated GitOps, many teams:

Use App of Apps pattern (bootstrap a root app).

Or commit the Application manifest in a bootstrap repo ArgoCD already tracks.

Verdict: Fine as-is, but could be more automated.

✅ Final Verdict: Is Your Workflow Aligned with Best Practices?
Feature	Status	Comment
ArgoCD auto-sync	✅	Declared in fonapp-argocd-app.yaml
GitOps (manifests in Git)	✅	All k8s files are Git-tracked
Manual kubectl apply of Application	⚠️	OK for bootstrap, but could be automated
ArgoCD webhook integration	❌	Not yet added
argocd app sync via CLI	❌	Not used
Empty commit workaround	✅ Removed	✅ Good

✅ What You Can Add to Improve
🔁 Option 1: Add ArgoCD Webhook
In your GitHub repo settings:

Go to Settings > Webhooks > Add Webhook

Payload URL: https://argocd.<your-domain>/api/webhook

Content type: application/json

Secret: Optional

Trigger: Just push events

💡 You must expose ArgoCD (argocd-server) via Ingress and use TLS.

🔁 Option 2: Add CLI Sync Step to Workflow
If webhook isn’t feasible yet, you can do:

yaml
Copy
Edit
- name: Sync ArgoCD App
  run: |
    argocd login argocd.example.com --username admin --password ${{ secrets.ARGOCD_PASSWORD }} --insecure
    argocd app sync fonapp
✅ Summary
Task	Done?	Recommendation
CI/CD pipeline for scan + infra + deployment	✅	Well implemented
Empty commit workaround removed	✅	👍
ArgoCD auto-sync enabled	✅	👍
Application manifest manually applied	✅	Acceptable (optional to automate)
ArgoCD webhook or sync trigger	❌	Add for real-time automation

k8s/
├── bootstrap/
│   ├── root-app-dev.yaml     # Bootstraps all dev ArgoCD apps
│   └── root-app-prod.yaml    # Bootstraps all prod ArgoCD apps
├── apps/
│   ├── dev/
│   │   ├── web-app.yaml
│   │   ├── payment-app.yaml
│   │   └── token-app.yaml
│   └── prod/
│       ├── web-app.yaml
│       ├── payment-app.yaml
│       └── token-app.yaml
├── web-app/
│   ├── dev/
│   │   ├── deployment.yaml/nmmn  /
│   │   ├── service.yaml
│   │   └── ingress.yaml
│   └── prod/
│       ├── deployment.yaml
│       ├── service.yaml
│       └── ingress.yaml
├── payment-app/
│   ├── dev/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── ingress.yaml
│   └── prod/
│       ├── deployment.yaml
│       ├── service.yaml
│       └── ingress.yaml
└── token-app/
    ├── dev/
    │   ├── deployment.yaml
    │   ├── service.yaml
    │   └── ingress.yaml
    └── prod/
        ├── deployment.yaml
        ├── service.yaml
        └── ingress.yaml
