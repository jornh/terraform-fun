variable count_ {
  type    = number
  default = 0
}

variable location {
  type = string
}

variable resource_group_name {
  type = string
}

variable virtual_network_resource_group_name {
  type = string
}

variable virtual_network_name {
  type = string
}

variable subnet_name {
  type = string
}

variable vm_name {
  type = string
}

variable vm_os_windows {
  type = bool
}

variable vm_os_linux {
  type = bool
}

variable vm_os_image_spec {
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
}
