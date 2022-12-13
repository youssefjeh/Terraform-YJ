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

variable "NetAddress" {
  description = "les adress des networks virt/subnet"
  type = list(object({
    address=list(string)
    name=string
  }))
}

variable LOC {}
# Create a resource group
resource "azurerm_resource_group" "rg" {
  name     = "YsfTer"
  location = var.LOC
}

resource "azurerm_virtual_network" "vn1" {
  name = "VNysfTer"
  resource_group_name = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location
  address_space       = var.NetAddress[0].address
  
}

resource "azurerm_subnet" "sb1" {
  name = "SBysfTer"
  resource_group_name = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vn1.name
  address_prefixes = var.NetAddress[1].address
  
}

output "sb1_Output" {
  value = azurerm_subnet.sb1.id
}
  