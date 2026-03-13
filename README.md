# DevSecOps GitHub Actions Pipeline

This project demonstrates how modern platform and DevOps teams build **secure CI/CD pipelines** that integrate security, infrastructure provisioning, and GitOps-based Kubernetes deployments.

The pipeline automates the full delivery workflow:

• Security scanning of the codebase  
• Infrastructure provisioning using Terraform  
• Kubernetes platform deployment on Amazon EKS  
• GitOps-based application delivery using ArgoCD  

The goal of this project is to simulate how **enterprise platform teams implement DevSecOps practices** to ensure that infrastructure and application deployments remain secure, automated, and repeatable.

---

# Architecture Overview

The pipeline integrates multiple components into a single automated workflow.

Developer Push → Security Scanning → Code Quality Analysis → Infrastructure Deployment → Kubernetes Platform Deployment → GitOps Synchronization

Key technologies used:

• GitHub Actions for CI/CD automation  
• Terraform for infrastructure provisioning  
• Amazon EKS for container orchestration  
• ArgoCD for GitOps application delivery  
• Prometheus and Grafana for observability  

---

# Pipeline Workflow

The pipeline is triggered automatically when:

• Code is pushed to the **main branch**
• A **pull request** is created

The workflow executes multiple stages to enforce security, quality, and deployment automation.

---

# Stage 1: Security Scanning

Security is embedded directly into the CI pipeline using multiple scanning tools.

### Trivy Filesystem Scan

Trivy scans the repository for:

• Infrastructure misconfigurations  
• Vulnerabilities in dependencies  
• Security risks within the codebase

Only **high and critical vulnerabilities** are flagged during scanning.

---

### OWASP Dependency Check

OWASP Dependency-Check analyzes project dependencies and detects known vulnerabilities.

Features:

• CVE database scanning  
• Automated vulnerability reporting  
• Pipeline failure if vulnerabilities exceed CVSS threshold

The generated security report is uploaded as a pipeline artifact.

---

# Stage 2: Code Quality Analysis

The pipeline integrates **SonarCloud** for automated code analysis.

SonarCloud provides:

• static code analysis  
• code quality metrics  
• technical debt analysis  
• maintainability scoring

This ensures that code quality standards are enforced before infrastructure or application deployment.

---

# Stage 3: Infrastructure Deployment

Infrastructure provisioning is handled using **Terraform**.

The pipeline automatically:

• initializes Terraform  
• validates infrastructure code  
• provisions AWS resources  
• deploys the Amazon EKS cluster

Resources provisioned include:

• Amazon EKS cluster  
• worker node groups  
• IAM roles and permissions  
• networking configuration

This ensures infrastructure can be deployed consistently across environments.

---

# Stage 4: Kubernetes Platform Initialization

After the EKS cluster is created, the pipeline configures Kubernetes access and verifies that platform services are operational.

Key tasks include:

• updating the Kubernetes kubeconfig  
• verifying ArgoCD deployment  
• waiting for platform services to become ready

This guarantees that the Kubernetes control plane and platform tools are functioning before application deployment begins.

---

# Stage 5: Load Balancer Provisioning

The pipeline waits for the **AWS Application Load Balancer** to be created through Kubernetes Ingress resources.

Once available, the ALB DNS endpoint is exported and stored as a pipeline artifact for later use.

---

# Stage 6: GitOps Deployment

Application deployment is managed through **ArgoCD GitOps synchronization**.

The pipeline automatically pushes updates to the GitOps repository.

ArgoCD then:

• detects the changes  
• synchronizes Kubernetes manifests  
• deploys applications to the cluster

This approach ensures:

• declarative deployments  
• automatic reconciliation  
• environment consistency

---

# DevSecOps Principles Implemented

This project demonstrates several key DevSecOps principles.

### Shift Security Left

Security scanning occurs early in the pipeline before infrastructure or application deployment.

### Infrastructure as Code

All infrastructure is defined using Terraform, ensuring repeatable and auditable deployments.

### GitOps Delivery

Kubernetes deployments are managed declaratively through Git using ArgoCD.

### Automated Platform Provisioning

The entire Kubernetes platform can be deployed automatically through the pipeline.

### Continuous Compliance

Security and quality checks run on every commit.

---

# Example Pipeline Flow

```
Developer Commit
        ↓
GitHub Actions Trigger
        ↓
Trivy Security Scan
        ↓
OWASP Dependency Check
        ↓
SonarCloud Code Analysis
        ↓
Terraform Infrastructure Deployment
        ↓
EKS Cluster Creation
        ↓
Kubernetes Platform Initialization
        ↓
ArgoCD GitOps Deployment
```

---

# Outcome

This pipeline demonstrates how organizations can implement **enterprise-grade DevSecOps automation** by combining security scanning, infrastructure provisioning, and GitOps delivery in a single workflow.

The result is a secure and repeatable deployment pipeline capable of provisioning infrastructure and deploying applications automatically.

---

# Technologies Used

GitHub Actions  
Terraform  
AWS EKS  
Kubernetes  
ArgoCD  
Trivy  
OWASP Dependency Check  
SonarCloud  
Prometheus  
Grafana