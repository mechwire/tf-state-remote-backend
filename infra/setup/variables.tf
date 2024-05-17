variable "aws_account_id" {
  type        = string
  description = "the account ID used in many ARNs."
  sensitive   = true
}

variable "organization" {
  description = "the name of the organization on GitHub (e.g., 'user' in user/project)"
  type        = string
  default     = "mechwire"
}

variable "repository_name" {
  description = "the name of the repository"
  type        = string
}
