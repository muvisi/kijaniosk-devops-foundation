variable "name" {
  description = "Name of the Multipass virtual machine."
  type        = string
}

variable "image" {
  description = "Ubuntu image used to create the virtual machine."
  type        = string
}

variable "cpus" {
  description = "Number of virtual CPUs assigned to the server."
  type        = number
}

variable "memory" {
  description = "Amount of memory assigned to the server."
  type        = string
}

variable "disk" {
  description = "Disk size assigned to the server."
  type        = string
}
