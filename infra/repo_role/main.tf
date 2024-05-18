terraform {
  backend "s3" {}
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.48.0"
    }
  }
}

provider "aws" {}

module "github_oidc_role" {
  source          = "git::https://github.com/mechwire/github-oidc-role//infra/github_oidc_role"
  aws_account_id  = var.aws_account_id
  organization    = var.organization
  repository_name = var.repository_name
}

data "aws_iam_policy" "tf_state_dependency_interaction" {
  name = "tf-state-dependency-interaction"
}

resource "aws_iam_role_policy_attachment" {
  role       = module.github_oidc_role.name
  policy_arn = aws_iam_policy.tf_state_dependency_interaction.arn
}