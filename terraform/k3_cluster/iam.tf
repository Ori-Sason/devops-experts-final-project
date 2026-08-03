# SSM PARAMETER STORAGE
resource "aws_ssm_parameter" "k3s_token" {
  name        = "/k3s/cluster-token"
  type        = "SecureString"
  value       = "placeholder" # Initially a dummy value; overwritten dynamically by the ./scripts/master_provision.sh
  description = "Token used to securely join worker agents to the K3s cluster"

  lifecycle {
    ignore_changes = [value] # Prevents Terraform from overwriting the real token during updates
  }
}


# MASTER NODE
resource "aws_iam_role" "k3s_master_role" {
  name = "devops-experts-k3s-master-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "k3s_master_policy" {
  name        = "devops-experts-k3s-master-policy"
  description = "Allows K3s master control plane to securely write token to SSM"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ssm:PutParameter"]
        Resource = "arn:aws:ssm:${var.region}:${var.account_id}/k3s/cluster-token"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "master_attach" {
  role       = aws_iam_role.k3s_master_role.name
  policy_arn = aws_iam_policy.k3s_master_policy.arn
}

resource "aws_iam_role_policy_attachment" "master_ssm_read_for_rds_secrets_attach" {
  role       = aws_iam_role.k3s_master_role.name
  policy_arn = var.ssm_read_for_rds_secrets_policy_arn
}

resource "aws_iam_role_policy_attachment" "master_ssm_core" {
  role       = aws_iam_role.k3s_master_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "k3s_master_profile" {
  name = "devops-experts-k3s-master-profile"
  role = aws_iam_role.k3s_master_role.name
}


# WORKER NODES
resource "aws_iam_role" "k3s_worker_role" {
  name = "devops-experts-k3s-worker-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_policy" "k3s_worker_policy" {
  name        = "devops-experts-k3s-worker-policy"
  description = "Allows K3s workers to lookup the master IP via tags and read the SSM token"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter"]
        Resource = "arn:aws:ssm:${var.region}:${var.account_id}/k3s/cluster-token"
      },
      {
        Effect   = "Allow"
        Action   = ["ec2:DescribeInstances"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "worker_attach" {
  role       = aws_iam_role.k3s_worker_role.name
  policy_arn = aws_iam_policy.k3s_worker_policy.arn
}

resource "aws_iam_role_policy_attachment" "worker_ssm_core" {
  role       = aws_iam_role.k3s_worker_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "k3s_worker_profile" {
  name = "devops-experts-k3s-worker-profile"
  role = aws_iam_role.k3s_worker_role.name
}
