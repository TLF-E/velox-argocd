provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = var.namespace
}

resource "kubernetes_manifest" "velox_api" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name = "velox-api"
    }
    spec = {
      project = "default"
      source = {
        repoURL        = "https://github.com/velox-helm"
        path           = "charts/api"
        targetRevision = "HEAD"
      }
      destination = {
        namespace = "velox"
        server    = "https://kubernetes.default.svc"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
      }
      helm = {
        releaseName = "velox-api"
        values = [
          "values-${var.namespace}-${var.stage}.yaml"
        ]
      }
    }
  }
}

resource "kubernetes_manifest" "velox_front" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name = "velox-front"
    }
    spec = {
      project = "default"
      source = {
        repoURL        = "https://github.com/velox-helm"
        path           = "charts/front"
        targetRevision = "HEAD"
      }
      destination = {
        namespace = "velox"
        server    = "https://kubernetes.default.svc"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
      }
      helm = {
        releaseName = "velox-front"
        values = [
          "values-velox-stage-1.yaml",
          "values-velox-prod-1.yaml"
        ]
      }
    }
  }
}
