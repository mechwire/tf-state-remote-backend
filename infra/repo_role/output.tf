output "arn" {
  description = "The ARN for the role that was created"
  value       = module.github_oidc_role.arn
}

output "name" {
  description = "The name for the created role"
  value       = module.github_oidc_role.name
}