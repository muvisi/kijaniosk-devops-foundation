module "app_server" {
  source   = "./modules/app_server"
  for_each = var.servers

  name   = each.value.name
  image  = each.value.image
  cpus   = each.value.cpus
  memory = each.value.memory
  disk   = each.value.disk
}
