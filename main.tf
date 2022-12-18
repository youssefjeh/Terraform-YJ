terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}

variable "vnet_address" {}
variable "sbnet_address" {}
variable "LOC" {}
variable "env_prefix" {}
variable "my_ip" {}
variable "public_key_location" {}
variable "private_key_location" {}

# Create a resource group
resource "azurerm_resource_group" "rg" {
  name     = "${var.env_prefix}-rg"
  location = var.LOC
}

resource "azurerm_ssh_public_key" "ssh-key" {
  name                = "Azssh-key"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.LOC
  public_key          = file(var.public_key_location)
}

resource "azurerm_virtual_network" "myapp-vn" {
  name                = "${var.env_prefix}-vn"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = var.vnet_address

}

resource "azurerm_subnet" "myapp-subnet-1" {
  name                 = "${var.env_prefix}-subnet-1"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.myapp-vn.name
  address_prefixes     = var.sbnet_address

}

/*output "sb1_Output" {
  value = azurerm_subnet.sb1.id
}*/

resource "azurerm_route_table" "myapp-route-table" {
  name                          = "route-table"
  location                      = azurerm_resource_group.rg.location
  resource_group_name           = azurerm_resource_group.rg.name
  disable_bgp_route_propagation = false

  route {
    name           = "${var.env_prefix}-rt"
    address_prefix = "10.1.0.0/16"
    next_hop_type  = "VirtualNetworkGateway"
  }
  tags = {
    env = "Dev"
  }
}

resource "azurerm_nat_gateway" "myapp-internet-gatway" {
  name                    = "${var.env_prefix}-nat-Gateway"
  location                = azurerm_resource_group.rg.location
  resource_group_name     = azurerm_resource_group.rg.name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
}

resource "azurerm_subnet_route_table_association" "myapp-rt-sbnet" {
  subnet_id      = azurerm_subnet.myapp-subnet-1.id
  route_table_id = azurerm_route_table.myapp-route-table.id
}

resource "azurerm_network_security_group" "myapp-sg" {
  name                = "${var.env_prefix}-securityGroup"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}
resource "azurerm_network_security_rule" "sgr1" {
  name                        = "${var.env_prefix}-securityGroup-1"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "22"
  destination_port_range      = "22"
  source_address_prefix       = var.my_ip
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.myapp-sg.name
}

resource "azurerm_network_security_rule" "sgr2" {
  name                        = "${var.env_prefix}-securityGroup-2"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "8080"
  destination_port_range      = "8080"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.myapp-sg.name
}

resource "azurerm_network_security_rule" "sgr3" {
  name                        = "${var.env_prefix}-securityGroup3"
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "0"
  destination_port_range      = "0"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.myapp-sg.name
}

resource "azurerm_public_ip" "myapp-pubip" {
  name                = "${var.env_prefix}-pubip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "myapp-ntc" {
  name                = "${var.env_prefix}-ntc"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.myapp-subnet-1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.myapp-pubip.id
  }
}

resource "azurerm_linux_virtual_machine" "myapp-server" {
  name                  = "${var.env_prefix}-server"
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  size                  = "Standard_D2s_v3"
  admin_username        = "adminuser"
  network_interface_ids = [azurerm_network_interface.myapp-ntc.id]
  #custom_data           = filebase64("azure-user-data.sh")
    connection {
    type = "ssh"
    host = self.public_ip_address
    user = "adminuser"
    private_key = file(var.private_key_location)
  }

  provisioner "file" {
    source = "azure-user-data.sh"
    destination = "/home/adminuser/azureBash.sh"
  }

  provisioner "remote-exec" {
    /*inline = [
      "mkdir newdir"
    ]*/
    script = filebase64("azureBash.sh")
  }

  provisioner "local-exec" {
    command = "echo ${self.public_ip_address} > output.txt"
    
  }

  admin_ssh_key {
    username   = "adminuser"
    public_key = azurerm_ssh_public_key.ssh-key.public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }
}

