output "arn" {
  description = "The ARN for the role that was created"
  value       = aws_iam_role.github.arn
}

output "name" {
  description = "The name for the created role"
  value       = aws_iam_role.github.name
}