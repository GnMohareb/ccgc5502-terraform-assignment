# CCGC 5502 — Terraform Assignment (assignment1-5877)

George Mohareb — N01275877

Root module `assignment1-5877` with eight child modules under `modules/`.

## Layout

```
assignment1-5877/
├── providers.tf, backend.tf, variables.tf, main.tf, outputs.tf
└── modules/
    ├── rgroup-5877/        resource group
    ├── network-5877/       vnet, subnet, NSG (22/3389/5985/80)
    ├── common-5877/        log analytics, recovery vault, storage account
    ├── vmlinux-5877/       3 × CentOS 8.2  (for_each)  + provisioner.tf
    ├── vmwindows-5877/     1 × Windows Server 2016 (count)
    ├── datadisk-5877/      4 × 10 GB disks + attachments
    ├── loadbalancer-5877/  public load balancer, 3 Linux VMs behind it
    └── database-5877/      Azure DB for PostgreSQL
```

## How to run

```bash
export ARM_SUBSCRIPTION_ID=78373394-4296-42cc-8084-dcd591256e4a
export TF_VAR_admin_password='<vm admin password>'
export TF_VAR_db_admin_password='<postgres admin password>'

terraform init
terraform validate
terraform apply --auto-approve
terraform state list | nl
terraform output
```

Passwords are supplied through `TF_VAR_*` environment variables and are never
written to a file, so nothing secret is committed to the repository.

## Deviations from the assignment specification

These three changes were forced by the Azure for Students subscription. Each is
documented here rather than silently worked around.

### 1. Region is East US 2, not Canada Central

The assignment recommends a region with availability zones and names Canada
Central. That region is blocked:

```
(RequestDisallowedByAzure) This policy maintains a set of best available
regions where your subscription can deploy resources.
```

Policy `Allowed resource deployment regions` restricts the subscription to
`eastus2`, `westus3`, `southcentralus`, `centralus`, `northcentralus`.
East US 2 was chosen: it has availability zones and zero vCPU consumption.
North Central US was unusable — its regional quota is fully consumed (6/6) by
the lab VMs from labs 06–10.

### 2. Load balancer and public IPs use Standard SKU, not Basic

The assignment specifies a *basic* load balancer. Basic SKU is retired on this
subscription:

```
(IPv4BasicSkuPublicIpCountLimitReached) Cannot create more than 0 IPv4 Basic
SKU public IP addresses for this subscription in this region.
```

A basic public load balancer requires a basic public IP, so it cannot be
created. Standard SKU is used for the load balancer frontend and for all VM
public IPs. Standard SKU denies inbound traffic by default, which makes the
NSG rules functionally required rather than cosmetic.

### 3. Operating systems are Rocky Linux 9 and Windows Server 2022

The assignment specifies CentOS 8.2 and Windows Server 2016. Every VM size this
subscription can use is NVMe-only, and both of those operating systems predate
NVMe support:

```
InvalidParameter: The VM size 'Standard_F1as_v7' cannot boot with OS image or
disk. Please check that disk controller types supported by the OS image or disk
is one of the supported disk controller types for the VM size.
```

Every SCSI-capable VM family returns `NotAvailableForSubscription`. Rocky Linux
9 is the direct community successor to CentOS, and Windows Server 2022 is the
earliest Windows Server with NVMe support.

### 4. VM size is Standard_F1as_v7, not Standard_B1ms

`Standard_B1ms` is `NotAvailableForSubscription`. `Standard_F1as_v7` is also a
1 vCPU size, satisfying the instruction to select a 1 CPU VM size.

### 5. Database is PostgreSQL Flexible Server, not Single Server

Single Server is retired and returns `InvalidElasticServerType` on create.

### 6. Names that must start with a letter are prefixed with `n`

The assignment says to prepend all resource names with the last four digits of
the Humber ID (`5877`). Azure rejects a leading digit for Recovery Services
vault names, PostgreSQL server names, and public IP DNS labels:

```
Recovery Service Vault name must be 2 - 50 characters long, start with a letter
domain_name_label ... must start with a letter
```

Those specific resources use `n5877-…` instead of `5877-…`, keeping the ID
digits while satisfying the Azure naming rule. Every other resource uses the
plain `5877-` prefix as specified.

## Quota note

East US 2 allows 4 vCPUs in the `Standard BS Family`. This deployment uses
four `Standard_B1ms` VMs — exactly 4 vCPUs, with no headroom. Any larger VM
size, or a fifth VM, will fail the apply.
