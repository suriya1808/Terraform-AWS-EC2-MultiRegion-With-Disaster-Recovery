# Disaster Recovery, part 1: automatic nightly backups of the prod server.
#
# Every night AWS Backup takes an AMI (a full disk image) of the prod server,
# stores it in prod-vault (Mumbai), and copies it to prod-dr-vault
# (Singapore). If Mumbai goes down, dr.tf builds a new server from the copy.
# See README.md for the full failover steps.

# IAM role = a set of permissions. This one lets the AWS Backup service
# snapshot the server and copy the snapshot to the DR region.
resource "aws_iam_role" "backup" {
  provider = aws.prod # IAM is global; any provider works
  name     = "prod-backup-role"

  # Trust policy: only the AWS Backup service may use this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "backup.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Give the role AWS's ready-made backup permissions
resource "aws_iam_role_policy_attachment" "backup" {
  provider   = aws.prod
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

# Vault = a storage box for backups. One in each region.
# force_destroy lets terraform destroy delete vaults that still hold backups.
resource "aws_backup_vault" "prod" {
  provider      = aws.prod
  name          = "prod-vault"
  force_destroy = true
}

resource "aws_backup_vault" "dr" {
  provider      = aws.dr
  name          = "prod-dr-vault"
  force_destroy = true
}

# The schedule: what to do, when, and how long to keep it
resource "aws_backup_plan" "prod" {
  provider = aws.prod
  name     = "prod-ec2-daily"

  rule {
    rule_name         = "daily"
    target_vault_name = aws_backup_vault.prod.name
    schedule          = "cron(0 18 * * ? *)" # every day 18:00 UTC = 23:30 IST
    start_window      = 60                   # minutes the job may wait to start
    completion_window = 180                  # minutes the job may take to finish

    # Delete backups in prod-vault after N days
    lifecycle {
      delete_after = var.backup_retention_days
    }

    # After each backup, copy it to the Singapore vault
    copy_action {
      destination_vault_arn = aws_backup_vault.dr.arn

      lifecycle {
        delete_after = var.backup_retention_days
      }
    }
  }
}

# Which servers the plan backs up: every prod server
resource "aws_backup_selection" "prod" {
  provider     = aws.prod
  name         = "prod-ec2"
  plan_id      = aws_backup_plan.prod.id
  iam_role_arn = aws_iam_role.backup.arn
  resources    = [for instance in aws_instance.prod : instance.arn]
}
