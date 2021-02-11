variable "admin_username" {
    type = string
    description = "Administrator user name for virtual machine"
}

variable "admin_password" {
    type = string
    description = "Password must meet Azure complexity requirements"
}

variable "name_new_vm" {
  type = string
  description = "Setting the name for new machines"
}

variable "location" {
    type = string
    description = "Setting the server location"
}

variable "admin_login" {
  type = string
  description = "Setting the login for database connection"
}

variable "admin_login_password" {
  type = string
  description = "Setting the password for database connection"
}