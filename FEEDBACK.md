# Assignment Feedback — CCGC 5502 Terraform Assignment

George Mohareb — N01275877

Requested feedback on assignment flow, errors encountered, and the fixes
applied.

---

## Assignment flow

The modular structure works well. Building each child module in isolation and
only then wiring them into the root module meant that when something failed it
was always clear which module owned the problem. Developing the resource group,
network and common-services modules first also meant the VM modules had real
dependencies to consume rather than placeholders.

Running `terraform plan` after each module was added — rather than writing all
eight and planning once — caught naming and reference errors early, when there
was only one new thing that could have caused them.

The one part of the specification that constrained the design rather than
guiding it is the requirement for exactly 48 lines in `terraform state list`.
That number is a property of one particular reference implementation, and it
forces structural choices that are otherwise arbitrary. My first working plan
produced 53 resources with an entirely reasonable layout; reaching 48 meant
restructuring code that was already correct.

---

## Errors encountered, and the fixes applied

### 1. Canada Central is blocked by subscription policy

```
RequestDisallowedByAzure: This policy maintains a set of best available regions
where your subscription can deploy resources.
```

The assignment recommends a region with availability zones and names Canada
Central. A policy called `Allowed resource deployment regions` restricted the
student subscription to `eastus2`, `westus3`, `southcentralus`, `centralus` and
`northcentralus`.

**Fix:** deployed to East US 2, which also has availability zones.

### 2. Names beginning with a digit are rejected

```
Recovery Service Vault name must be 2 - 50 characters long, start with a letter
domain_name_label ... must start with a letter
```

The instruction to prepend the last four digits of the Humber ID produces
`5877-`, which begins with a digit. Azure rejects that for Recovery Services
vaults, PostgreSQL servers, VM backup policies and public IP DNS labels.

This is worth flagging because every student in the course will hit it — student
IDs are numeric, so the naming instruction conflicts with Azure's validator for
those specific resource types.

**Fix:** a local `alpha_prefix = "n${var.prefix}"` gives `n5877` for exactly
those resources. Everything else keeps the plain `5877-` prefix specified.

### 3. The student subscription cannot host the deployment

Two independent caps:

```
PublicIPCountLimitReached: Cannot create more than 3 public IP addresses
```

The deployment needs five — three Linux VMs, one Windows VM, one load balancer.
The regional vCPU limit of 6 was also insufficient once the only available VM
sizes turned out to be 2 vCPU each.

I attempted a workaround: allocate a `/30` public IP prefix and carve individual
addresses out of it. Azure rejected that as well — addresses from a prefix count
against the same cap.

**Fix:** moved to a pay-as-you-go subscription, which the assignment lists as the
preferred account type. Its limits are 10 vCPU and 20 public IPs.

### 4. Basic SKU load balancer cannot be created

```
IPv4BasicSkuPublicIpCountLimitReached: Cannot create more than 0 IPv4 Basic SKU
public IP addresses for this subscription in this region.
```

A public-facing basic load balancer requires a basic public IP. I tested this on
both the student and the pay-as-you-go subscription with identical results,
which establishes it as global product retirement rather than an account limit.

**Fix:** Standard SKU for the load balancer and for all VM public IPs. One
consequence worth noting: Standard SKU denies inbound traffic by default, so the
NSG rules became functionally load-bearing rather than merely present.

### 5. PostgreSQL Single Server is retired

```
InvalidElasticServerType: The provided server type value
'Azure Database for PostgreSQL - Single Server' is invalid.
```

**Fix:** switched to `azurerm_postgresql_flexible_server`. The retired
configuration is preserved in the repository as
`modules/database-5877/main-single-server.tf.disabled`.

### 6. No VM size could boot the specified operating systems

The most involved problem in the assignment. `Standard_B1ms` is
`NotAvailableForSubscription`, so I selected `Standard_F1as_v7` — also 1 vCPU.
The VMs then failed to boot:

```
InvalidParameter: The VM size 'Standard_F1as_v7' cannot boot with OS image or
disk. Please check that disk controller types supported by the OS image or disk
is one of the supported disk controller types for the VM size.
```

Joining `az vm list-skus` against `az vm list-usage` on the family name showed
that every VM size available to the subscription is **NVMe-only**, while every
SCSI-capable family is `NotAvailableForSubscription`. CentOS 8.2 (2020) and
Windows Server 2016 predate NVMe support and cannot boot on an NVMe controller.
I verified this across three regions before concluding it was a subscription
gate rather than a regional shortage.

**Fix:** Rocky Linux 9 for the Linux VMs — the direct community successor to
CentOS, founded by a CentOS co-founder and binary-compatible with RHEL — and
Windows Server 2022, the earliest Windows Server with NVMe support. Both keep
`dnf`, `httpd`, `firewalld`, `wheel` and SELinux identical to what CentOS would
have provided, so nothing structural changed.

### 7. Marketplace image required a plan block

```
VMMarketplaceInvalidInput: Creating a virtual machine from Marketplace image
requires Plan information in the request.
```

**Fix:** accepted the image terms once per subscription with
`az vm image terms accept --publisher resf --offer rockylinux-x86_64 --plan 9-lvm`
and added a matching `plan` block to the Linux VM resource.

### 8. Recovery Services vault rejected disabling soft delete

```
BMSUserErrorDisablingSoftDeleteStateNotAllowed: Disabling soft delete or
enhanced security state is not allowed for this vault.
```

**Fix:** removed `soft_delete_enabled = false` and left the setting at its
default of enabled.

### 9. Deleted names remain reserved

After deleting a failed deployment, redeploying with the same names failed:

```
StorageAccountAlreadyTaken
DnsRecordIsReserved
```

Azure holds globally unique names — storage accounts and public IP DNS labels —
for a period after deletion.

**Fix:** rather than wait out the reservation, I added a `name_suffix` variable
applied to exactly those two classes of name. Bumping it produces a clean set on
any future redeploy.

### 10. Interrupted applies leave untracked resources

Twice, an apply was interrupted after Azure had created resources but before
Terraform recorded them in state. The next apply then reported
`A resource with the ID ... already exists - to be managed via Terraform this
resource needs to be imported`.

**Fix:** `terraform import` for the two VM extensions, and deletion for the
virtual machines, which was cleaner than importing a partially-provisioned VM.
This is a good argument for the remote backend the assignment requires — state
locking is what prevents two runs colliding in the first place.

---

## Reaching exactly 48 resources

The first working plan produced 53. Three changes brought it to 48:

| Change | Delta | Requirement still met? |
|---|---|---|
| NSG rules moved from four separate `azurerm_network_security_rule` resources into four inline `security_rule` blocks in a `dynamic` block | −4 | Yes — still four inbound rules for 22, 3389, 5985 and 80 |
| Provisioner consolidated from three `null_resource` (one per VM via `for_each`) into one carrying three `remote-exec` blocks | −2 | Yes — all three VMs are still logged into and print their hostname |
| Added `azurerm_backup_policy_vm` to the Recovery Services vault | +1 | Additional — a vault with no policy performs no backups, so this completes the design |

53 − 4 − 2 + 1 = 48.

---

## Suggestions

1. The exactly-48 requirement rewards matching one reference implementation
   rather than sound design. A range, or a checklist of required resource types,
   would assess the same understanding without penalising equally valid
   structures.

2. The specified operating systems, VM size, load balancer SKU and database type
   are all now retired or unavailable on current Azure subscriptions. A student
   starting today on a fresh account cannot follow the specification literally.
   Suggested modern equivalents: Rocky Linux 9 or AlmaLinux 9, Windows Server
   2022, Standard SKU load balancer, PostgreSQL Flexible Server, and a 1 vCPU
   size from the F-series.

3. Worth warning students that the newer v6 and v7 VM families are NVMe-only and
   will not boot pre-2021 operating system images. The failure message points at
   the disk controller rather than at the image age, which makes it hard to
   diagnose without cross-referencing the SKU capabilities API.

4. The naming instruction conflicts with Azure's own validation for Recovery
   Services vaults, PostgreSQL servers and DNS labels, all of which require a
   leading letter. Since every student ID is numeric, every student hits this.
