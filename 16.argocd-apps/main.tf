provider "aws" {
  region  = var.region
  profile = "${var.namespace}-${var.stage}"
}

variable "namespace" {}
variable "namespace_argocd" { default = "argocd" }
variable "kube_context" {}
variable "argocd_enabled" {}
variable "region" {}
variable "stage" {}

module "argo_label_password" {
  source = "git@github.com:tlf-e/brands-terraform-modules.git//terraform-aws-null-label"
  enabled = var.argocd_enabled
  attributes = ["argocd-password"]
}

resource "random_password" "argo_password" {
  count = var.argocd_enabled ? 1 : 0
  length = 16
  special = true
  override_special = "_-"
}

resource "aws_ssm_parameter" "argo_password" {
  count = var.argocd_enabled ? 1 : 0
  name = "${var.namespace}-${var.stage}-argocd-password"
  type  = "SecureString"
  value = random_password.argo_password[0].result
  tags  = module.argo_label_password.tags
  overwrite = true
}



data "aws_ssm_parameter" "argocd_ssh_key" {
  name             = "${var.namespace}-${var.stage}-argocd-git-ssh-private"
  with_decryption  = true
}
resource "kubernetes_secret" "argocd_repo_ssh_key" {
  metadata {
    name      = "repo-ssh-key"
    namespace = "argocd"
  }
  data = {
    "sshPrivateKey" = data.aws_ssm_parameter.argocd_ssh_key.value
  }
}

# create namespace if not exists:
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.namespace_argocd
  }
}
resource "helm_release" "argocd" {
  depends_on = [kubernetes_namespace.argocd]
  repository      = "https://argoproj.github.io/argo-helm"
  chart           = "argo-cd"
  version         = "7.3.11"

  name            = var.namespace_argocd
  namespace       = var.namespace_argocd

  create_namespace = true
  force_update     = true
  recreate_pods    = true
  max_history      = 3
  timeout          = 300

#  set {
#     name  = "configs.repositories[0].name"
#     value = "${var.namespace}-argocd"
#   }
#   set {
#     name  = "configs.repositories[0].url"
#     value = "git@github.com:TLF-E/${var.namespace}-argocd.git"
#   }
#   set {
#     name  = "configs.repositories[0].type"
#     value = "git"
  # }

  ## REPO ssh key
  # set {
  #   name  = "configs.repositories[0].sshPrivateKeySecret.name"
  #   value = "repo-ssh-key"
  # }
  # set {
  #   name  = "configs.repositories[0].sshPrivateKeySecret.key"
  #   value = "sshPrivateKey"
  # }
  # set_sensitive {
  #   name  = "configs.credentialTemplates.ssh-creds.sshPrivateKey"
  #   value = data.aws_ssm_parameter.argocd_ssh_key.value
  # }


  # values = [
  #   <<EOF
  #   configs:
  #     secret:
  #       argocdServerAdminPassword: ${base64encode(random_password.argo_password[0].result)}
  #   EOF
  # ]
}
resource "helm_release" "argo_rollouts" {
  name       = "argo-rollouts"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-rollouts"
  version    = "2.37.3"

  namespace  = "default"  # You can specify the namespace here if it's different from "default"
  create_namespace = true
  depends_on = [ helm_release.argocd ]
}

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "v1.7.1"

  namespace  = "cert-manager"
  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }
}


# To debug the helm_release resource
# helm upgrade --install argocd argo-cd \
#   --repo https://argoproj.github.io/argo-helm \
#   --version 7.3.11 \
#   --namespace argocd \
#   --create-namespace \
#   --set forceUpdate=true \
#   --set recreatePods=true \
#   --set maxHistory=3 \
#   --timeout 300s

# resource "helm_release" "argo_cd" {
#   count = var.argocd_enabled ? 1 : 0
#   name  = "argocd"
#   repository       = "https://argoproj.github.io/argo-helm"
#   chart            = "argo-cd"
#   version          = "7.3.11"  # https://artifacthub.io/packages/helm/argo/argo-cd?modal=changelog
#   # version          = "6.9.2"  # https://artifacthub.io/packages/helm/argo/argo-cd?modal=changelog
#   namespace        = "argocd"
#   create_namespace = true
#   force_update     = true
#   recreate_pods    = true
#   max_history      = 3
#   timeout          = 300

#   # set {
#   #   name  = "configs.secret.argocdServerAdminPassword"
#   #   value = base64encode(random_password.argo_password[0].result)
#   # }

#   # set {
#   #   name  = "configs.repositories[0].name"
#   #   value = "sakuraslots-argocd"
#   # }

#   # set {
#   #   name  = "configs.repositories[0].url"
#   #   value = "git@github.com:TLF-E/sakuraslots-argocd.git"
#   # }

#   # set {
#   #   name  = "configs.repositories[0].type"
#   #   value = "git"
#   # }

#   ### REPO ssh key
#   # set {
#   #   name  = "configs.repositories[0].sshPrivateKeySecret.name"
#   #   value = "repo-ssh-key"
#   # }

#   # set {
#   #   name  = "configs.repositories[0].sshPrivateKeySecret.key"
#   #   value = "sshPrivateKey"
#   # }

#   # set_sensitive {
#   #   name  = "configs.credentialTemplates.ssh-creds.sshPrivateKey"
#   #   value = data.aws_ssm_parameter.argocd_ssh_key.value
#   # }

#   depends_on = [aws_ssm_parameter.argo_password, kubernetes_secret.argocd_repo_ssh_key]
# }

###################################

output "argo_password_ssm_name" {
  description = "The name of the SSM parameter storing the ArgoCD password"
  value       = aws_ssm_parameter.argo_password[0].name
}

output "argo_password" {
  description = "The generated ArgoCD password"
  value       = random_password.argo_password[0].result
  sensitive   = true
}

