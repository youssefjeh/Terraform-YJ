resource "azurerm_subnet" "myapp-subnet-1" {
  name                 = "${var.env_prefix}-subnet-1"
  resource_group_name  = var.res_grp_name
  virtual_network_name = var.vir_net_name
  address_prefixes     = var.sbnet_address

}

resource "azurerm_route_table" "myapp-route-table" {
  name                          = "route-table"
  location                      = var.res_grp_location
  resource_group_name           = var.res_grp_name
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
  location                = var.res_grp_location
  resource_group_name     = var.res_grp_name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
}

resource "azurerm_subnet_route_table_association" "myapp-rt-sbnet" {
  subnet_id      = azurerm_subnet.myapp-subnet-1.id
  route_table_id = azurerm_route_table.myapp-route-table.id
}