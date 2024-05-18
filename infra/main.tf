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

# Create Infrastructure

## S3

// This stores / tracks the state / metadata, and makes it available outside our local machine
resource "aws_s3_bucket" "tf_state" {
  bucket_prefix = "tf-state" // Bucket Names have to be unique per region, so prefix ensures some part is random

  tags = {
    github     = true,
    repository = var.repository_name
  }
}

resource "aws_s3_bucket_ownership_controls" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration {
    status = "Enabled" // helps with file recovery
  }
}

// IAM alone is not enough to grant access to the contents of an s3 bucket, particularly for PutObject. We need a policy document to allow it.
data "aws_iam_policy_document" "tf_state_bucket_objects" {
  statement {
    principals {
      type        = "*" // Overly permissive, because we're restricting it below
      identifiers = ["*"]
    }

    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["${aws_s3_bucket.tf_state.arn}/$${aws:PrincipalTag/repository}/*.tf_state"]
    condition {
      test     = "StringLike"
      variable = "aws:PrincipalArn"
      values   = ["arn:aws:iam::${var.aws_account_id}:role/github_infra_*"]
    }
  }
  // Since we decided to have a separate role to configure the project / repo role, that needs a separate statement to allow it to use a different directory
  statement {
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.aws_account_id}:role/github_infra_role_provisioner"]
    }

    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["${aws_s3_bucket.tf_state.arn}//*/repo-setup.tf_state"]
  }
}

resource "aws_s3_bucket_policy" "tf_state_bucket_objects" {
  bucket = aws_s3_bucket.tf_state.id
  policy = data.aws_iam_policy_document.tf_state_bucket_objects.json
}


## DynamoDB

// This helps ensure only 1 party is modifying the resources
resource "aws_dynamodb_table" "tf_state" {
  name         = "tf-state-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    github     = true,
    repository = var.repository_name,
  }
}

// Create a policy that will be shared

data "aws_iam_policy_document" "tf_state_dependency" {
  statement {
    sid    = "TFStateS3Dependency"
    effect = "Allow"
    # https://developer.hashicorp.com/terraform/language/settings/backends/s3
    actions   = ["s3:ListBucket", "s3:GetObject", "s3:PutObject"]
    resources = [aws_s3_bucket.tf_state.arn]
  }
  statement {
    sid       = "TFStateDynamoDBDependency"
    effect    = "Allow"
    actions   = ["dynamodb:DescribeTable", "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
    resources = [aws_dynamodb_table.tf_state.arn]
  }
}

resource "aws_iam_policy" "tf_state_dependency" {
  name        = "tf-state-dependency-interaction"
  description = "This policy assigns permissions to interact with a tfstate stored in s3 and locks in DynamoDB."
  policy      = data.aws_iam_policy_document.tf_state_dependency.json
}