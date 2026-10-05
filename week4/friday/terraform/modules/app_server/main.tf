resource "terraform_data" "server" {
  triggers_replace = [
    var.name,
    var.image,
    tostring(var.cpus),
    var.memory,
    var.disk
  ]

  provisioner "local-exec" {
    command = <<-EOT
      if multipass info "${var.name}" >/dev/null 2>&1; then
        echo "Multipass instance ${var.name} already exists."
      else
        echo "Creating Multipass instance ${var.name}..."
        multipass launch "${var.image}" \
          --name "${var.name}" \
          --cpus "${var.cpus}" \
          --memory "${var.memory}" \
          --disk "${var.disk}"
      fi
    EOT
  }

  provisioner "local-exec" {
    when = destroy

    command = <<-EOT
      if multipass info "${self.triggers_replace[0]}" >/dev/null 2>&1; then
        multipass delete "${self.triggers_replace[0]}"
        multipass purge
      else
        echo "Multipass instance ${self.triggers_replace[0]} already absent."
      fi
    EOT
  }
}
