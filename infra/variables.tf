variable "aws_account_id" {
  type        = string
  description = "the account ID used in many ARNs."
  sensitive   = true
}

variable "repository_name" {
  description = "the name of the repository"
  type        = string
}
