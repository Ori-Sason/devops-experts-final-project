resource "aws_iam_policy" "ssm_read_policy" {
  name        = "k3s-ssm-read-policy"
  description = "Allows reading SSM parameters for External Secrets Operator"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParameterHistory"
        ]
        Resource = "arn:aws:ssm:${var.region}:${var.account_id}:parameter/devops-experts-final-project/*"
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = "*"
      }
    ]
  })
}

output "ssm_read_for_rds_secrets_policy_arn" {
  description = "SSM read policy ARN - used in k3_master_role"
  value       = aws_iam_policy.ssm_read_policy.arn
}
