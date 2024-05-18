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

module "basic_repo_role" {
  source          = "../repo_role"
  aws_account_id  = var.aws_account_id
  organization    = var.organization
  repository_name = var.repository_name
}

# The roles assigned should allow it to create the necessary infrastructure
data "aws_iam_policy_document" "repo_role" {
  // S3 doesn't support tag-based access, so we restrict by resource name
  statement {
    sid       = "S3"
    effect    = "Allow"
    actions   = ["s3:CreateBucket", "s3:PutBucketTagging", "s3:ListBucket", "s3:GetBucketTagging", "s3:GetBucketPolicy", "s3:GetBucketLogging", "s3:GetBucketAcl", "s3:GetBucketCors", "s3:GetBucketVersioning", "s3:GetBucketWebsite", "s3:GetAccelerateConfiguration", "s3:GetBucketRequestPayment", "s3:GetLifecycleConfiguration", "s3:GetReplicationConfiguration", "s3:GetEncryptionConfiguration", "s3:GetBucketObjectLockConfiguration", "s3:PutBucketOwnershipControls", "s3:PutBucketVersioning", "s3:GetBucketOwnershipControls", "s3:PutObjectAcl", "s3:DeleteBucket", "s3:PutBucketAcl"]
    resources = ["arn:aws:s3:::tf-state*"]
  }
  // DynamoDB doesn't support tag-based access, so we restrict by resource name
  statement {
    sid       = "DynamoDB"
    effect    = "Allow"
    actions   = ["dynamodb:CreateTable", "dynamodb:TagResource", "dynamodb:DescribeTable", "dynamodb:DescribeContinuousBackups", "dynamodb:DescribeTimeToLive", "dynamodb:ListTagsOfResource"]
    resources = ["arn:aws:dynamodb:*:*:table/tf-state-lock"]
  }
}

resource "aws_iam_policy" "repo_role" {
  name        = "S3AndBucketCreation"
  description = "This policy assigns permissions to create an s3 bucket and DynamoDB table"
  policy      = data.aws_iam_policy_document.repo_role.json
}

resource "aws_iam_role_policy_attachment" "repo_role" {
  role       = module.basic_repo_role.name
  policy_arn = aws_iam_policy.repo_role.arn
}
