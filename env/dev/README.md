# Source code management
git status
git add .
git commit -m "your msg"
git push origin dev


# Terraform essential commands and notes
terraform init

terraform plan

terraform apply --auto-approve

terraform destroy --auto-approve

terraform reconfigure

# Phase 1: Cluster only
1. terraform plan -target=module.eks.aws_cloudformation_stack.eks_cluster_stack

2. terraform apply -target=module.eks.aws_cloudformation_stack.eks_cluster_stack --auto-approve

3. aws eks update-kubeconfig --region us-east-1 --name effulgencetech-dev

AmazonEKSLoadBalancingPolicy
aws iam delete-instance-profile --instance-profile-name GNPC-dev-admin-instance-profile
GNPC-dev-admin-instance-profile

# Phase 2: Everything else
3. terraform apply --auto-approve

# Delete All
4. terraform destroy --auto-approve

5. terraform destroy -target=module.iam --auto-approve

# Testing
5. aws eks update-kubeconfig --region us-east-1 --name effulgencetech-dev

# argocd
# list all pods in argocd namespace
1. kubectl get pods -n argocd

# To check argocd on the web locally
2. kubectl port-forward svc/argocd-server -n argocd 8080:80

# run this to expose argo as an alb
2. kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
using Ingress + ALB Controller instead — which is more secure and scalable.
kubectl expose deployment argocd-server --type=LoadBalancer --name=argocd-server --port=80 --target-port=8080 -n argocd


# To check argocd on the web externally; copy and paste alb dns in browser
4. kubectl get ingress -n argocd


# to get argocd passwd
1. export ARGOCD_SERVER='kubectl get svc argocd-server -n argocd -o json | jq - raw-output '.status.loadBalancer.ingress[0].hostname''
admin
2. export ARGO_PWD='kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d' echo $ARGO_PWD

3. kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
a7VW0a29v8HRC5ky


# to access grafana locally
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

gfnpasswd$1234

# to access prometheus locally
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090

# Troubleshooting
5. aws eks describe-cluster --name effulgencetech-dev --region us-east-1

# troubleshoot grafana
1. kubectl get pods -n monitoring
2. kubectl get svc -n monitoring

1. kubectl get secret grafana-admin -n monitoring -o yaml
2. kubectl get storageclass
3. helm get all kube-prometheus-stack -n monitoring


kubectl annotate serviceaccount -n kube-system aws-load-balancer-controller eks.amazonaws.com/role-arn=arn:aws:iam::151706774:role/eks-alb-controller-irsa

{  "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Federated": "arn:aws:iam::151706774:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/var.oidc_provider_arn"
        },
        "Action": "sts:AssumeRoleWithWebIdentity",
        "Condition": {
          "StringEquals": {
            "oidc.eks.us-east-1.amazonaws.com/id/var.oidc_provider_arn:sub": "system:serviceaccount:kube-system:alb_controller",
            "oidc.eks.us-east-1.amazonaws.com/id/var.oidc_provider_arn:aud": "sts.amazonaws.com"
          }
        }
      }
    ]
  }


Supported Kubernetes versions¶
AWS Load Balancer Controller v2.0.0~v2.1.3 requires Kubernetes 1.15+
AWS Load Balancer Controller v2.2.0~v2.3.1 requires Kubernetes 1.16-1.21
AWS Load Balancer Controller v2.4.0+ requires Kubernetes 1.19+
AWS Load Balancer Controller v2.5.0+ requires Kubernetes 1.22+
4. Access ArgoCD Web UI
You deployed ArgoCD via Helm, which also exposes a LoadBalancer by default (unless overridden).

🔍 Check ArgoCD Service:
 
1. kubectl get svc -n argocd argocd-server
2. kubectl describe svc -n argocd argocd-server

✅ Output Example:
 NAME           TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)
argocd-server  LoadBalancer   10.0.45.108     54.91.180.20    80:30123/TCP
🌐 Open in Browser: http://<EXTERNAL-IP>:80
🔑 Login Credentials:
Username: admin

Initial Password: ArgoCD stores it as a secret named argocd-initial-admin-secret:

kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode
🧠 Tip:
If EXTERNAL-IP is <pending> for a while:
Your LoadBalancer (ELB) might not have been provisioned yet.
Make sure you're using a VPC/subnets that support AWS LoadBalancers (usually public subnets with mapPublicIpOnLaunch = true and proper tags).


# To check prometheus on the web locally
kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80

<!-- terraform apply --auto-approve -target=aws_cloudformation_stack.eks_cluster_stack
terraform destroy --auto-approve -target=aws_cloudformation_stack.eks_cluster_stack --> -->

To investigate why Helm release failed:
Use the helm CLI:

bash
Copy
Edit
helm list -n argocd
helm status argocd -n argocd
And for Prometheus:

bash
Copy
Edit
helm list -n monitoring
helm status kube-prometheus-stack -n monitoring
Also check the pods:

bash
Copy
Edit
kubectl get pods -n argocd
kubectl get pods -n monitoring
If some are stuck in CrashLoopBackOff or Pending, describe the pod:

bash
Copy
Edit
kubectl describe pod <pod-name> -n <namespace>
✅ Next steps:
1. Check ALB controller is working
bash
Copy
Edit
kubectl get pods -n kube-system | grep alb
Make sure it’s running. If not:

bash
Copy
Edit
kubectl logs -n kube-system <alb-pod-name>
2. Check Service Type
Make sure your Helm values for ArgoCD, Prometheus, and Grafana set the type to LoadBalancer:

hcl
Copy
Edit
set {
  name  = "server.service.type"
  value = "LoadBalancer"
}
For Prometheus and Grafana:

hcl
Copy
Edit
set {
  name  = "grafana.service.type"
  value = "LoadBalancer"
}
3. Check LoadBalancers
bash
Copy
Edit
kubectl get svc -A | grep LoadBalancer
See if any services have an external IP. If not, your ALB controller isn’t working right.

4. Confirm IAM role permissions
Ensure the IAM role associated with the ALB controller has the correct policy and that the service account is properly annotated.

TL;DR:
kubectl port-forward is temporary and local — it doesn’t mean the LoadBalancer is working.

Your ALB LoadBalancers aren’t being provisioned properly — check ALB controller, IAM, and Helm values.

Use kubectl get svc -A | grep grafana and port-forward Grafana if needed for now.

Use helm status and kubectl logs to diagnose Helm release failures.

Let me know what you get from kubectl get svc -A | grep LoadBalancer and I’ll help you sort out why the LoadBalancers aren’t coming up.

kubectl exec -n kube-system aws-load-balancer-controller-9546df94b-46fdj -- curl -I https://sts.us-east-1.amazonaws.com

 aws-load-balancer-controller-9546df94b-46fdj


terraform/
├── modules/
│   ├── rds/
│   ├── ssm/
│   └── ...
├── envs/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── data.tf      ← All data lookups (like SSM)
│   │   ├── variables.tf
│   │   └── outputs.tf


# Tflint
TFLint ruleset plugin for Terraform AWS Provider

This ruleset focus on possible errors and best practices about AWS resources. Many rules are enabled by default and warn against code that might fail when running terraform apply, or clearly unrecommened.

# Installation
You can install the plugin by adding a config to .tflint.hcl and running tflint --init:

# Installation
1. Run the command for your OS
Bash script (Linux):
curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash

Homebrew (macOS):
brew install tflint

Chocolatey (Windows):
choco install tflint

# Enable plugin
1. vi into a file and call it .tflint.hcl
2. paste the plugin details, save and quit
plugin "aws" {
    enabled = true
    version = "0.39.0"
    source  = "github.com/terraform-linters/tflint-ruleset-aws"
}
3. run tflint --init
It should return the output below
Installing "aws" plugin...
Installed "aws" (source: github.com/terraform-linters/tflint-ruleset-aws, version: 0.39.0) # the version will depend on the version you installed.


# iam principal variables
Value	Use Case
["ec2.amazonaws.com"]	Standard EKS worker nodes (EC2 instances)
["ssm.amazonaws.com"]	SSM-managed nodes or hybrid scenarios
["eks.amazonaws.com"]	Rare, for EKS service itself
["ec2.amazonaws.com", ...]	Multiple services (advanced use cases)


and the value for the permission boundary null means it is applied right?

GitHub Copilot
No, setting the permission boundary variable to null means no permission boundary will be applied to the IAM role.

How it works:

If you set permissions_boundary = null (or simply omit the argument), Terraform will not add a permissions boundary to the role.
If you set permissions_boundary = "arn:aws:iam::123456789012:policy/your-permission-boundary", then that boundary will be applied.
Summary:

null = No permission boundary is attached.
"arn:aws:iam::...:policy/..." = That permission boundary is attached.
If you want the permission boundary to be enforced, provide its ARN as the value. If you want no boundary, use null.


Now, the next error you're encountering:

vbnet
Copy
Edit
Error: failed to get shared config profile, default
means that Terraform is trying to use an AWS CLI profile named default, but it's either not configured or not available in the GitHub Actions runner environment.

🔍 Why This Happens
In your providers.tf, you likely have something like:

h
Copy
Edit
provider "aws" {
  profile = "default" # ⛔ This line causes the issue in CI
  region  = "us-east-1"
}
This profile = "default" assumes the presence of a shared AWS credentials profile named default in ~/.aws/credentials. That may work locally, but in GitHub Actions, AWS credentials are usually provided via environment variables like:

bash
Copy
Edit
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
✅ How to Fix It
✅ Option 1: Remove profile entirely (recommended for CI)
Update your providers.tf like this:

hcl
Copy
Edit
provider "aws" {
  region = "us-east-1"
}
When no profile is specified, the AWS provider will automatically use environment variables — which GitHub Actions sets from:

yaml
Copy
Edit
- name: Configure AWS Credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    aws-region: us-east-1
🛠 Option 2: Pass a profile (not recommended in CI)
If you insist on using profile, you'd need to also configure that profile manually in GitHub Actions — but it's not the standard practice in CI/CD.