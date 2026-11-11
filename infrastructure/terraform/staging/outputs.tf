output "staging_namespace" {
  description = "Kubernetes staging namespace"
  value       = kubernetes_namespace_v1.staging.metadata[0].name
}
