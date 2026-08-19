# One resource group to hold the whole assignment deployment.
resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-RG"
  location = var.location
  tags     = var.tags
}
