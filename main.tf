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

# Create a resource group
resource "azurerm_resource_group" "rg" {
  name     = "${var.env_prefix}-rg"
  location = var.LOC
}


resource "azurerm_virtual_network" "myapp-vn" {
  name                = "${var.env_prefix}-vn"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = var.vnet_address

}

module "myapp-subnet" {
  source = "./modules/subnet" 
  sbnet_address = var.sbnet_address
  env_prefix = var.env_prefix
  res_grp_name = azurerm_resource_group.rg.name
  res_grp_location = azurerm_resource_group.rg.location
  vir_net_name = azurerm_virtual_network.myapp-vn.name
}

module "myapp-server" {
  source = "./modules/server"
  my_ip = var.my_ip
  env_prefix = var.env_prefix
  subnet_Id = module.myapp-subnet.subnetOp.id
  public_key_location = var.public_key_location
  LOC = var.LOC
  res_grp_name = azurerm_resource_group.rg.name
  res_grp_location = azurerm_resource_group.rg.location
  vir_net_name = azurerm_virtual_network.myapp-vn.name
}
