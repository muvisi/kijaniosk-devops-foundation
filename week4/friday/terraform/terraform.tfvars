region        = "local"
instance_type = "standard"
key_name      = "id_rsa"

servers = {
  api = {
    name   = "kijanikiosk-api"
    image  = "22.04"
    cpus   = 1
    memory = "1G"
    disk   = "5G"
  }

  payments = {
    name   = "kijanikiosk-payments"
    image  = "22.04"
    cpus   = 1
    memory = "1G"
    disk   = "5G"
  }

  logs = {
    name   = "kijanikiosk-logs"
    image  = "22.04"
    cpus   = 1
    memory = "1G"
    disk   = "5G"
  }
}
