variable "region" {
  description = "Logical deployment region for the KijaniKiosk environment."
  type        = string
  default     = "local"
}

variable "instance_type" {
  description = "Logical instance type used for the local Multipass environment."
  type        = string
  default     = "standard"
}

variable "key_name" {
  description = "SSH key name used by Ansible to access provisioned servers."
  type        = string
  default     = "id_rsa"
}

variable "servers" {
  description = "Definitions of the KijaniKiosk application servers."
  type = map(object({
    name   = string
    image  = string
    cpus   = number
    memory = string
    disk   = string
  }))
}
