# ---------------------------------------------------------------------------
# Global
# ---------------------------------------------------------------------------
variable "prefix" {
  description = "Last 4 digits of the Humber ID, prepended to every resource name."
  type        = string
  default     = "5877"
}

variable "location" {
  description = "Azure region. The assignment recommends a region with availability zones."
  type        = string
  default     = "eastus2"
}

variable "name_suffix" {
  description = <<-EOT
    Short suffix appended to names that live in a GLOBAL Azure namespace - the
    shared storage account and every public-IP DNS label. Azure reserves such
    names for a period after deletion, so a redeploy that reuses them fails with
    StorageAccountAlreadyTaken or DnsRecordIsReserved. Bump this value to get a
    clean set of names instead of waiting out the reservation.
  EOT
  type        = string
  default     = "x1"
}

variable "tags" {
  description = "Tags applied to every resource in the deployment."
  type        = map(string)
  default = {
    Assignment     = "CCGC 5502 Automation Assignment"
    Name           = "george.mohareb"
    ExpirationDate = "2024-12-31"
    Environment    = "Learning"
  }
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------
variable "vnet_address_space" {
  description = "Address space of the virtual network."
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "subnet_address_prefixes" {
  description = "Address prefixes of the subnet."
  type        = list(string)
  default     = ["10.0.1.0/24"]
}

variable "allowed_ports" {
  description = "Inbound TCP ports opened on the network security group."
  type        = list(string)
  default     = ["22", "3389", "5985", "80"]
}

# ---------------------------------------------------------------------------
# Compute
# ---------------------------------------------------------------------------
variable "vm_size" {
  description = <<-EOT
    Size used for every virtual machine. The assignment specifies a 1 CPU size
    (B1ms). Standard_B1ms is NotAvailableForSubscription, so Standard_F1as_v7 is
    used - also 1 vCPU, and available. It is a Generation 2 only SKU, which is
    why the VM modules reference the -gen2 image variants.
  EOT
  type        = string
  default     = "Standard_F1as_v7"
}

variable "public_ip_sku" {
  description = <<-EOT
    SKU for every public IP and for the load balancer. The assignment specifies
    a *basic* load balancer, which requires Basic here. Some subscriptions
    disallow Basic SKU public IPs entirely - run scripts/preflight.sh to find
    out, and set this to "Standard" if Basic is blocked.
  EOT
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Basic", "Standard"], var.public_ip_sku)
    error_message = "public_ip_sku must be either Basic or Standard."
  }
}

variable "linux_vm_names" {
  description = "Logical names of the Linux VMs. for_each iterates this set."
  type        = set(string)
  default     = ["lvm1", "lvm2", "lvm3"]
}

variable "windows_vm_count" {
  description = "Number of Windows VMs. count iterates this value."
  type        = number
  default     = 1
}

variable "admin_username" {
  description = "Local administrator account created on every VM."
  type        = string
  default     = "azureadmin"
}

variable "admin_password" {
  description = "Local administrator password. Supply via TF_VAR_admin_password."
  type        = string
  sensitive   = true
}

# ---------------------------------------------------------------------------
# Data disks
# ---------------------------------------------------------------------------
variable "data_disk_size_gb" {
  description = "Size in GB of each data disk attached to a VM."
  type        = number
  default     = 10
}

# ---------------------------------------------------------------------------
# Database
# ---------------------------------------------------------------------------
variable "db_admin_username" {
  description = "PostgreSQL administrator login."
  type        = string
  default     = "pgadmin5877"
}

variable "db_admin_password" {
  description = "PostgreSQL administrator password. Supply via TF_VAR_db_admin_password."
  type        = string
  sensitive   = true
}
