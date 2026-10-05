output "server_names" {
  description = "Names of all KijaniKiosk Multipass servers."
  value = {
    for key, server in module.app_server :
    key => server.name
  }
}

output "ssh_key_name" {
  description = "SSH key name configured for Ansible access."
  value       = var.key_name
}
