terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "2.46.1"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "resourceGroup" {
  name = "ResourceGroup"
  location = "West US"
}

resource "random_string" "fqdn" {
 length  = 6
 special = false
 upper   = false
 number  = false
}

resource "azurerm_virtual_network" "vnet" {
    name                = "VirtualNetwork"
    address_space       = ["10.0.0.0/16"]
    location            = var.location
    resource_group_name = azurerm_resource_group.resourceGroup.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "Subnet"
  resource_group_name  = azurerm_resource_group.resourceGroup.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "publicIP" {
  name                 = "PublicIP"
  location             = var.location
  resource_group_name  = azurerm_resource_group.resourceGroup.name
  allocation_method    = "Static"
  domain_name_label    = random_string.fqdn.result
 }

resource "azurerm_lb" "loadBalancer" {
  name = "LoadBalancer"
  location = var.location
  resource_group_name = azurerm_resource_group.resourceGroup.name

  frontend_ip_configuration {
    name = "AdressIpPublicLoadBalancer"
    public_ip_address_id = azurerm_public_ip.publicIP.id
  }
}

resource "azurerm_lb_backend_address_pool" "backendAdressLoadBalancer" {
  resource_group_name = azurerm_resource_group.resourceGroup.name
  loadbalancer_id = azurerm_lb.loadBalancer.id
  name = "BackEndAdressPool" 
}

resource "azurerm_lb_probe" "vmss" {
  resource_group_name              = azurerm_resource_group.resourceGroup.name
  loadbalancer_id                  = azurerm_lb.loadBalancer.id
  name                             = "ssh_running-probe"
  port                             = 80
}

resource "azurerm_lb_rule" "ruleLoadBalancer" {
  resource_group_name              = azurerm_resource_group.resourceGroup.name
  loadbalancer_id                  = azurerm_lb.loadBalancer.id
  name                             = "http"
  protocol                         = "Tcp"
  frontend_port                    = 80
  backend_port                     = 80
  backend_address_pool_id          = azurerm_lb_backend_address_pool.backendAdressLoadBalancer.id
  frontend_ip_configuration_name   = "AdressIpPublicLoadBalancer"
  probe_id                         = azurerm_lb_probe.vmss.id
}

# Create a Linux virtual machine
resource "azurerm_virtual_machine_scale_set" "autoScalingGroup" {         
  name                    = var.name_new_vm
  location                = var.location
  resource_group_name     = azurerm_resource_group.resourceGroup.name
  upgrade_policy_mode     = "Manual"

  sku {
   name     = "Standard_DS1_v2"
   tier     = "Standard"
   capacity = 2
 }

  storage_profile_image_reference {
    publisher             = "Canonical"
    offer                 = "UbuntuServer"
    sku                   = "16.04.0-LTS"
    version               = "latest"
  }

   storage_profile_os_disk {
    name                  = ""
    caching               = "ReadWrite"
    create_option         = "FromImage"
    managed_disk_type     = "Premium_LRS"
  }

  storage_profile_data_disk {
   lun          = 0
   caching        = "ReadWrite"
   create_option  = "Empty"
   disk_size_gb   = 10
 }

  os_profile {
    computer_name_prefix = "vmlab"
    admin_username        = var.admin_username
    admin_password        = var.admin_password
    custom_data          = file("web.conf")
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  network_profile {
    name                  = "network"
    primary               = true

    ip_configuration {
      name                = "IPConfiguration"
      subnet_id           = azurerm_subnet.subnet.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.backendAdressLoadBalancer.id]
      primary             = true
    }     
  }
}

resource "azurerm_mysql_server" "MysqlServer" {
  name                = "mysql-server-infrastructure-as-code"
  location            = var.location
  resource_group_name = azurerm_resource_group.resourceGroup.name

  administrator_login          = var.admin_login
  administrator_login_password = var.admin_login_password

  sku_name   = "B_Gen5_2"
  storage_mb = 5120
  version    = "5.7"

  auto_grow_enabled                 = false
  backup_retention_days             = 7
  geo_redundant_backup_enabled      = false
  infrastructure_encryption_enabled = false
  public_network_access_enabled     = true
  ssl_enforcement_enabled           = false
}

resource "azurerm_mysql_database" "WordpressDBIC" {
  name                = "wordpress-DB-IC"
  resource_group_name = azurerm_resource_group.resourceGroup.name
  server_name         = azurerm_mysql_server.MysqlServer.name
  charset             = "utf8"
  collation           = "utf8_unicode_ci"
}

resource "azurerm_mysql_firewall_rule" "MysqlRuleNetwork" {
  name                = "mysql-Rule-Network"
  resource_group_name = azurerm_resource_group.resourceGroup.name
  server_name         = azurerm_mysql_server.MysqlServer.name
  start_ip_address    = azurerm_public_ip.publicIP.ip_address
  end_ip_address      = azurerm_public_ip.publicIP.ip_address
}