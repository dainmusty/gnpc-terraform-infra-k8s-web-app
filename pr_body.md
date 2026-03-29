## Terraform Plan Summary
```
module.ssm.data.aws_ssm_parameter.db_access_parameter_name: Reading...
module.addons.data.aws_secretsmanager_secret_version.grafana_admin: Reading...
module.iam_core.data.aws_region.current: Reading...
module.iam_irsa.data.aws_secretsmanager_secret.grafana: Reading...
module.s3.data.aws_caller_identity.current: Reading...
module.iam_core.data.aws_iam_policy_document.s3_rw_assume: Reading...
module.ssm.data.aws_ssm_parameter.db_secret_parameter_name: Reading...
module.iam_core.data.aws_iam_policy_document.s3_rw_assume: Read complete after 0s [id=2851119427]
module.iam_core.data.aws_region.current: Read complete after 0s [id=us-east-1]
module.ssm.data.aws_ssm_parameter.key_path_parameter_name: Reading...
module.iam_core.data.aws_iam_policy_document.admin_assume: Reading...
module.iam_core.data.aws_iam_policy_document.s3_full_access_assume: Reading...
module.iam_core.data.aws_iam_policy_document.s3_full_access_assume: Read complete after 0s [id=2851119427]
module.iam_core.data.aws_caller_identity.current: Reading...
module.iam_core.data.aws_iam_policy_document.admin_assume: Read complete after 0s [id=3960366575]
module.addons.data.aws_secretsmanager_secret_version.slack_webhook: Reading...
module.iam_core.data.aws_iam_policy_document.grafana_assume: Reading...
module.iam_core.data.aws_iam_policy_document.grafana_assume: Read complete after 0s [id=2851119427]
module.ssm.data.aws_ssm_parameter.key_name_parameter_name: Reading...
module.s3.data.aws_caller_identity.current: Read complete after 0s [id=651706774390]
module.iam_core.data.aws_iam_policy_document.config_assume: Reading...
module.iam_core.data.aws_iam_policy_document.prometheus_assume: Reading...
module.iam_core.data.aws_iam_policy_document.config_assume: Read complete after 0s [id=607352202]
module.iam_irsa.data.aws_caller_identity.current: Reading...
module.iam_core.data.aws_iam_policy_document.prometheus_assume: Read complete after 0s [id=2851119427]
module.iam_core.data.aws_caller_identity.current: Read complete after 0s [id=651706774390]
module.iam_irsa.data.aws_caller_identity.current: Read complete after 0s [id=651706774390]
module.addons.data.aws_secretsmanager_secret_version.grafana_admin: Read complete after 0s [id=grafana-user-passwd|AWSCURRENT]
module.ssm.data.aws_ssm_parameter.key_path_parameter_name: Read complete after 0s [id=/kp/path]
module.ssm.data.aws_ssm_parameter.db_secret_parameter_name: Read complete after 0s [id=/db/secure/access]
module.addons.data.aws_secretsmanager_secret_version.slack_webhook: Read complete after 0s [id=slack-webhook-alertmanager|AWSCURRENT]
module.ssm.data.aws_ssm_parameter.db_access_parameter_name: Read complete after 0s [id=/db/access]
module.iam_irsa.data.aws_secretsmanager_secret.grafana: Read complete after 0s [id=arn:aws:secretsmanager:us-east-1:651706774390:secret:grafana-user-passwd-h2uIZ4]
module.ssm.data.aws_ssm_parameter.key_name_parameter_name: Read complete after 0s [id=/kp/name]

Terraform used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
  + create
 <= read (data resources)

Terraform will perform the following actions:

  # module.addons.aws_eks_addon.addons["coredns"] will be created
  + resource "aws_eks_addon" "addons" {
      + addon_name               = "coredns"
      + addon_version            = "v1.12.3-eksbuild.1"
      + arn                      = (known after apply)
      + cluster_name             = "dev-gnpc-eks-cluster"
      + configuration_values     = (known after apply)
      + created_at               = (known after apply)
      + id                       = (known after apply)
      + modified_at              = (known after apply)
      + service_account_role_arn = (known after apply)
      + tags_all                 = (known after apply)
    }

  # module.addons.aws_eks_addon.addons["kube-proxy"] will be created
  + resource "aws_eks_addon" "addons" {
      + addon_name               = "kube-proxy"
      + addon_version            = "v1.34.0-eksbuild.2"
      + arn                      = (known after apply)
      + cluster_name             = "dev-gnpc-eks-cluster"
      + configuration_values     = (known after apply)
      + created_at               = (known after apply)
      + id                       = (known after apply)
      + modified_at              = (known after apply)
      + service_account_role_arn = (known after apply)
      + tags_all                 = (known after apply)
    }

  # module.addons.aws_eks_addon.addons["vpc-cni"] will be created
  + resource "aws_eks_addon" "addons" {
      + addon_name               = "vpc-cni"
      + addon_version            = "v1.20.1-eksbuild.3"
      + arn                      = (known after apply)
      + cluster_name             = "dev-gnpc-eks-cluster"
      + configuration_values     = (known after apply)
      + created_at               = (known after apply)
      + id                       = (known after apply)
      + modified_at              = (known after apply)
      + service_account_role_arn = (known after apply)
      + tags_all                 = (known after apply)
    }

  # module.addons.helm_release.argocd will be created
  + resource "helm_release" "argocd" {
      + atomic                     = false
      + chart                      = "argo-cd"
      + cleanup_on_fail            = false
      + create_namespace           = false
      + dependency_update          = false
      + disable_crd_hooks          = false
      + disable_openapi_validation = false
      + disable_webhooks           = false
      + force_update               = false
      + id                         = (known after apply)
      + lint                       = false
      + manifest                   = (known after apply)
      + max_history                = 0
      + metadata                   = (known after apply)
      + name                       = "argocd"
      + namespace                  = "argocd"
      + pass_credentials           = false
      + recreate_pods              = false
      + render_subchart_notes      = true
      + replace                    = false
      + repository                 = "https://argoproj.github.io/argo-helm"
      + reset_values               = false
      + reuse_values               = false
      + skip_crds                  = false
      + status                     = "deployed"
      + timeout                    = 300
      + values                     = [
          + <<-EOT
                server:
                  service:
                    ports:
                      http: 8080
                  ingress:
                    enabled: true
                    ingressClassName: alb
                    annotations:
                      alb.ingress.kubernetes.io/scheme: internet-facing
                      alb.ingress.kubernetes.io/target-type: ip
                      alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
                      alb.ingress.kubernetes.io/backend-protocol: HTTP
                    hosts:
                      - argocd.example.com
                    paths:
                      - path: /
                        pathType: Prefix
                        port:
                          number: 8080  # ✅ explicitly tell ingress to use port 8080
            EOT,
        ]
      + verify                     = false
      + version                    = "8.6.3"
      + wait                       = true
      + wait_for_jobs              = false

      + set {
          + name  = "server.serviceAccount.create"
          + value = "false"
        }
      + set {
          + name  = "server.serviceAccount.name"
          + value = "argocd-server"
        }
    }

  # module.addons.helm_release.aws_load_balancer_controller will be created
  + resource "helm_release" "aws_load_balancer_controller" {
      + atomic                     = false
      + chart                      = "aws-load-balancer-controller"
      + cleanup_on_fail            = false
      + create_namespace           = false
      + dependency_update          = false
      + disable_crd_hooks          = false
      + disable_openapi_validation = false
      + disable_webhooks           = false
      + force_update               = false
      + id                         = (known after apply)
      + lint                       = false
      + manifest                   = (known after apply)
      + max_history                = 0
      + metadata                   = (known after apply)
      + name                       = "aws-load-balancer-controller"
      + namespace                  = "kube-system"
      + pass_credentials           = false
      + recreate_pods              = false
      + render_subchart_notes      = true
      + replace                    = false
      + repository                 = "https://aws.github.io/eks-charts"
      + reset_values               = false
      + reuse_values               = false
      + skip_crds                  = false
      + status                     = "deployed"
      + timeout                    = 300
      + verify                     = false
      + version                    = "1.14.0"
      + wait                       = true
      + wait_for_jobs              = false

      + set {
          + name  = "clusterName"
          + value = "dev-gnpc-eks-cluster"
        }
      + set {
          + name  = "serviceAccount.create"
          + value = "true"
        }
      + set {
          + name  = "serviceAccount.name"
          + value = "aws-load-balancer-controller"
        }
    }

  # module.addons.helm_release.ebs_csi_driver will be created
  + resource "helm_release" "ebs_csi_driver" {
      + atomic                     = false
```
