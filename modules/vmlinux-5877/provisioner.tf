# The assignment requires a remote-exec null provisioner that displays the
# hostnames of all three Linux VMs.
#
# A single null_resource carries one remote-exec block per VM, each with its
# own SSH connection. Every VM is genuinely logged into and prints its own
# hostname, FQDN and private address - while contributing a single entry to
# terraform state rather than three.

locals {
  # Deterministic ordering so the three provisioner blocks below always map to
  # the same VMs across runs.
  vm_list = sort(tolist(var.vm_names))
}

resource "null_resource" "show_hostnames" {
  # Re-run whenever any of the VMs it targets is replaced.
  triggers = {
    vm_ids = join(",", [for k in local.vm_list : azurerm_linux_virtual_machine.linux_vm[k].id])
  }

  provisioner "remote-exec" {
    connection {
      type     = "ssh"
      host     = azurerm_public_ip.linux_pip[local.vm_list[0]].ip_address
      user     = var.admin_username
      password = var.admin_password
      timeout  = "5m"
    }
    inline = [
      "echo '===== Linux VM 1 ====='",
      "echo \"hostname    : $(hostname)\"",
      "echo \"fqdn        : $(hostname -f)\"",
      "echo \"private ip  : $(hostname -I)\"",
    ]
  }

  provisioner "remote-exec" {
    connection {
      type     = "ssh"
      host     = azurerm_public_ip.linux_pip[local.vm_list[1]].ip_address
      user     = var.admin_username
      password = var.admin_password
      timeout  = "5m"
    }
    inline = [
      "echo '===== Linux VM 2 ====='",
      "echo \"hostname    : $(hostname)\"",
      "echo \"fqdn        : $(hostname -f)\"",
      "echo \"private ip  : $(hostname -I)\"",
    ]
  }

  provisioner "remote-exec" {
    connection {
      type     = "ssh"
      host     = azurerm_public_ip.linux_pip[local.vm_list[2]].ip_address
      user     = var.admin_username
      password = var.admin_password
      timeout  = "5m"
    }
    inline = [
      "echo '===== Linux VM 3 ====='",
      "echo \"hostname    : $(hostname)\"",
      "echo \"fqdn        : $(hostname -f)\"",
      "echo \"private ip  : $(hostname -I)\"",
    ]
  }

  depends_on = [
    azurerm_virtual_machine_extension.netwatcher,
    azurerm_virtual_machine_extension.monitor,
  ]
}
