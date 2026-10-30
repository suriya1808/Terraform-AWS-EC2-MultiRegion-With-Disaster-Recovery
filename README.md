# Terraform Multi-Region EC2 with Disaster Recovery

A learning project that uses Terraform to build EC2 servers across three AWS regions, with a nightly backup and manual failover setup for the production server.

## What it builds

| Environment | Region | VPC | Subnet | Server |
|---|---|---|---|---|
| dev | eu-west-1 (Ireland) | `vpc-nonprod` 10.0.0.0/16 | `subnet-dev` 10.0.1.0/24 | `ec2-dev` |
| qa | eu-west-1 (Ireland) | `vpc-nonprod` 10.0.0.0/16 | `subnet-qa` 10.0.2.0/24 | `ec2-qa` |
| prod | ap-south-1 (Mumbai) | `vpc-prod` 10.1.0.0/16 | `subnet-prod` 10.1.1.0/24 | `ec2-prod` |
| DR | ap-southeast-1 (Singapore) | `vpc-dr` 10.2.0.0/16 | `subnet-dr` 10.2.1.0/24 | `ec2-prod-dr` (only during a failover) |

Every server runs the latest Ubuntu 22.04 on a `t3.micro`.

For the prod server, AWS Backup takes a disk image every night and copies it to Singapore. If Mumbai goes down, you can build a copy of prod in Singapore from that image.

```
ap-south-1 (prod)                          ap-southeast-1 (DR)
┌───────────────────────┐   nightly copy   ┌───────────────────────────┐
│ ec2-prod              │ ───────────────▶ │ prod-dr-vault (backups)   │
│ AWS Backup plan       │                  │ vpc-dr + subnet-dr        │
│ prod-vault (backups)  │                  │ ec2-prod-dr (only during  │
└───────────────────────┘                  │ a failover)               │
                                           └───────────────────────────┘
```

> **Note:** All subnets are private. There is no internet gateway, so the servers can't reach the internet and you can't SSH into them from outside.

## Project files

| File | What it does |
|---|---|
| [provider.tf](provider.tf) | Pins the AWS provider version and sets up one provider per region (`nonprod`, `prod`, `dr`). |
| [variables.tf](variables.tf) | All inputs: server size, environment names, IP ranges, backup retention, and the failover image ID. |
| [ami.tf](ami.tf) | Looks up the latest official Ubuntu 22.04 image in each region. Image IDs differ per region. |
| [vpc.tf](vpc.tf) | Creates the nonprod and prod VPCs (private networks). |
| [subnet.tf](subnet.tf) | Creates one subnet per environment inside its region's VPC. |
| [ec2.tf](ec2.tf) | Creates the dev, qa and prod servers. |
| [backup.tf](backup.tf) | Disaster recovery part 1: the IAM role, backup vaults, nightly backup plan and the copy to Singapore. |
| [dr.tf](dr.tf) | Disaster recovery part 2: the Singapore VPC and subnet, plus the recovery server that's created only during a failover. |
| [.terraform.lock.hcl](.terraform.lock.hcl) | Records the exact provider version so everyone gets the same one. Created by `terraform init`. |

## How the code works

### One provider per region
An AWS provider block talks to one region. [provider.tf](provider.tf) defines three, each with an `alias`, and every resource picks one with `provider = aws.prod` (or `aws.nonprod`, `aws.dr`).

The `provider` argument must be a fixed name. It can't be an expression like `each.key == "prod" ? aws.prod : aws.nonprod`. That's why prod and nonprod have separate resource blocks instead of one shared block.

### One server per environment with `for_each`
`var.environment` is a set: `["dev", "qa", "prod"]`. `for_each` creates one copy of a resource per item, and `each.key` holds the current item. A filter splits the set by region:

```hcl
for_each = toset([
  for env in var.environment : env
  if env != "prod"          # nonprod blocks get {"dev", "qa"}
])
```

The prod blocks use `if env == "prod"`. Subnets and servers use the same filters, so `aws_subnet.nonprod["dev"]` lines up with `aws_instance.nonprod["dev"]`.

To add an environment (for example `uat`), add it to `environment` **and** give it a CIDR in `subnet_cidrs`. Otherwise `terraform plan` fails with "key not found".

### The Ubuntu image lookup
[ami.tf](ami.tf) uses `data` blocks, which only look things up and never create anything. It filters by image name and only trusts images owned by Canonical (`099720109477`), the company behind Ubuntu.

## Getting started

### What you need
- [Terraform](https://developer.hashicorp.com/terraform/install) 1.x
- [AWS CLI](https://aws.amazon.com/cli/), logged in to an AWS account (`aws login` or `aws configure`). The project doesn't store any credentials.

### Commands
```bash
terraform init       # download the AWS provider
terraform fmt        # tidy formatting
terraform validate   # check for errors
terraform plan       # preview what will be created
terraform apply      # create it
```

The first `plan` should show about 17 resources: 3 VPCs, 4 subnets, 3 servers, 2 backup vaults, the backup IAM role and its policy attachment, and the backup plan and selection.

To remove everything, including the backups:
```bash
terraform destroy
```

### Changing settings
Edit the defaults in [variables.tf](variables.tf), or override them for a single run:
```bash
terraform apply -var="instance_type=t3.small" -var="backup_retention_days=14"
```

---

## Disaster recovery

### The idea
The prod server is like a shop in Mumbai. Every night a worker photocopies all of its records. One copy stays in a locker in Mumbai, and another is couriered to a locker in Singapore. There's also an empty shop rented in Singapore. If the Mumbai shop is lost, you take the newest copy from the Singapore locker and reopen the business in the empty shop.

| In the comparison | In AWS | File |
|---|---|---|
| Mumbai shop | Prod server in ap-south-1 | [ec2.tf](ec2.tf) |
| The night worker | AWS Backup plan | [backup.tf](backup.tf) |
| Worker's ID badge | IAM role that allows AWS Backup to take and copy snapshots | [backup.tf](backup.tf) |
| Locker in Mumbai | `prod-vault` | [backup.tf](backup.tf) |
| Locker in Singapore | `prod-dr-vault` | [backup.tf](backup.tf) |
| A photocopy | AMI: a full image of the server's disk | created by AWS Backup |
| Empty rented shop | DR VPC and subnet | [dr.tf](dr.tf) |
| Reopening the shop | `ec2-prod-dr`, created only when you ask | [dr.tf](dr.tf) |

### Key terms
- **Region:** an AWS location, such as Mumbai or Singapore. A disaster usually affects one region, not all of them.
- **AMI (Amazon Machine Image):** a complete snapshot of a server's disk. A new server can start from it.
- **Vault:** a storage box for backups.
- **RPO (Recovery Point Objective):** how much data you can lose. Backups run daily, so you can lose **up to 24 hours** of changes.
- **RTO (Recovery Time Objective):** how long recovery takes. Here, **a few minutes** after you start the failover.

### What runs by itself and what doesn't

| Task | Who does it |
|---|---|
| Nightly backup of prod | AWS Backup (automatic) |
| Copying the backup to Singapore | AWS Backup (automatic) |
| Deleting backups older than 7 days | AWS Backup (automatic) |
| Noticing that Mumbai is down | **You** |
| Finding the newest backup | **You** |
| Creating the Singapore server | **You** (`terraform apply -var=...`) |

**Failover is manual.** Terraform only does something when you run it. It doesn't keep running in the background or watch your servers. This setup is called *backup and restore*.

### Every night (automatic)
```
23:30 IST  AWS Backup starts
   │
   ▼
Takes an AMI of ec2-prod  ──────────▶ saved in prod-vault (Mumbai)
   │
   ▼
Copies that AMI to Singapore ───────▶ saved in prod-dr-vault (Singapore)
   │
   ▼
Deletes backups older than 7 days in both vaults
```

The first backup runs on the first night after `terraform apply`, not right away. Until it finishes, there's nothing to recover from.

### Failover: when Mumbai is down

**Step 1: Find the newest backup in Singapore**
```bash
aws backup list-recovery-points-by-backup-vault --backup-vault-name prod-dr-vault --region ap-southeast-1 --query "sort_by(RecoveryPoints[?Status=='COMPLETED'], &CreationDate)[-1].RecoveryPointArn" --output text
```
This means: "In the Singapore vault, list the finished backups, sort them by date, and give me the newest one." The output looks like:
```
arn:aws:ec2:ap-southeast-1::image/ami-0abc123def456
```
The AMI ID is the part after `image/`: `ami-0abc123def456`.

**Step 2: Build the recovery server**
```bash
terraform apply -var="dr_ami_id=ami-0abc123def456" -target=aws_instance.dr -refresh=false
```
- `-var="dr_ami_id=..."` sets the image ID. In [dr.tf](dr.tf), `count` changes from 0 to 1, so Terraform creates the server.
- `-target=aws_instance.dr` makes Terraform work only on the DR server.
- `-refresh=false` stops Terraform from checking the current state of other resources first. It would otherwise try to contact Mumbai, which is down, and fail.

**Step 3: Check it's running**
In the EC2 console, switch to **Asia Pacific (Singapore)**. `ec2-prod-dr` should be running with the same disk contents prod had at its last backup.

**Step 4: Send users to it**
The DR server has a new IP address. In a real setup, you'd update DNS (for example in Route 53) to point to it. This learning project doesn't include that step.

### Failback: when Mumbai is back
1. Check that `ec2-prod` in Mumbai is healthy.
2. If anything changed on the DR server while it was live, copy those changes back to prod.
3. Run a normal apply without the variable:
   ```bash
   terraform apply
   ```
   `dr_ami_id` returns to `""`, `count` becomes 0, and Terraform deletes the DR server. The nightly backups keep running.

### Practise a failover
If you've never tested recovery, you don't know whether it works. To test without waiting for the nightly run, start a backup and copy by hand. Get the ARNs from `terraform state show aws_instance.prod["prod"]`, `terraform state show aws_iam_role.backup` and `terraform state show aws_backup_vault.dr`.

```bash
# 1. Back up prod now
aws backup start-backup-job --backup-vault-name prod-vault --resource-arn <prod instance ARN> --iam-role-arn <backup role ARN> --region ap-south-1

# 2. When it finishes, copy it to Singapore
aws backup start-copy-job --recovery-point-arn <recovery point ARN from step 1> --source-backup-vault-name prod-vault --destination-backup-vault-arn <dr vault ARN> --iam-role-arn <backup role ARN> --region ap-south-1
```
A backup you start by hand doesn't run the plan's copy step automatically, so step 2 is needed.

Then:
1. In the AWS console, go to **AWS Backup → Vaults → prod-dr-vault** in Singapore and confirm a recovery point is there.
2. Do failover Steps 1–3. Mumbai is still working during a test, so you can leave out `-target` and `-refresh=false`.
3. Do the failback to delete the DR server.

### Limits of this setup
- **Failover is manual.** Making it automatic would need a health check (Route 53 or CloudWatch), a trigger (EventBridge or SNS) and a Lambda function that launches the server.
- **Up to 1 day of data can be lost,** because backups run nightly.
- **The state file is local.** `terraform.tfstate` stays on the machine that ran Terraform and is deliberately not committed (see [.gitignore](.gitignore)). If it's lost, Terraform no longer knows what it built, so keep a copy somewhere safe. In real projects, state goes in a remote backend such as S3, in a region other than prod.
- **Backups copy the disk only.** Apps and files on the server come back as they were at the last backup.
- **Single-server faults in one region** are already handled: t3 servers restart automatically on healthy hardware after a hardware failure. This DR setup is for losing the whole region.

## Troubleshooting

| Problem | Cause and fix |
|---|---|
| First `apply` fails on `aws_backup_selection` saying the role can't be assumed | A new IAM role takes a few seconds to become usable in AWS. Run `terraform apply` again. |
| `Invalid index` / key not found on a subnet | A name in `environment` has no entry in `subnet_cidrs`. Add one. |
| `Invalid provider configuration reference` | `provider =` was given an expression. It must be a fixed name like `aws.prod`. |
| `dr_ami_id` image not found | Use an AMI ID from the **Singapore** vault (`prod-dr-vault`), not from Mumbai. AMI IDs are per region. |

## Cost
Everything is small, but it isn't free:
- 3 × `t3.micro` servers while they run (4 during a failover)
- Snapshot storage in both regions, plus data transfer for the copy between regions

VPCs, subnets, vaults and IAM roles cost nothing. Run `terraform destroy` when you're done. `force_destroy` on the vaults lets this delete the backups too.
