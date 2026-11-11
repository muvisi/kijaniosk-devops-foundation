resource "kubernetes_namespace_v1" "staging" {
  metadata {
    name = "kijani-staging"

    labels = {
      app         = "kijanikiosk"
      environment = "staging"
      managed-by  = "terraform"
    }
  }
}

resource "kubernetes_resource_quota_v1" "staging" {
  metadata {
    name      = "staging-quota"
    namespace = kubernetes_namespace_v1.staging.metadata[0].name
  }

  spec {
    hard = {
      "requests.cpu"    = "2"
      "requests.memory" = "4Gi"
      "limits.cpu"      = "4"
      "limits.memory"   = "8Gi"
      "pods"            = "10"
    }
  }
}
