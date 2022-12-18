
resource "azurerm_ssh_public_key" "ssh-key" {
  name                = "Azssh-key"
  resource_group_name = var.res_grp_name
  location            = var.LOC
  public_key          = file(var.public_key_location)
}

resource "azurerm_network_security_group" "myapp-sg" {
  name                = "${var.env_prefix}-securityGroup"
  location            = var.res_grp_location
  resource_group_name = var.res_grp_name
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
  resource_group_name         = var.res_grp_name
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
  resource_group_name         = var.res_grp_name
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
  resource_group_name         = var.res_grp_name
  network_security_group_name = azurerm_network_security_group.myapp-sg.name
}

resource "azurerm_public_ip" "myapp-pubip" {
  name                = "${var.env_prefix}-pubip"
  resource_group_name = var.res_grp_name
  location            = var.res_grp_location
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "myapp-ntc" {
  name                = "${var.env_prefix}-ntc"
  location            = var.res_grp_location
  resource_group_name = var.res_grp_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_Id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.myapp-pubip.id
  }
}

resource "azurerm_linux_virtual_machine" "myapp-server" {
  name                  = "${var.env_prefix}-server"
  resource_group_name   = var.res_grp_name
  location              = var.res_grp_location
  size                  = "Standard_D2s_v3"
  admin_username        = "adminuser"
  network_interface_ids = [azurerm_network_interface.myapp-ntc.id]
  custom_data           = filebase64("azure-user-data.sh")

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
