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
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "tf_state" {
  depends_on = [aws_s3_bucket_ownership_controls.tf_state]
  bucket     = aws_s3_bucket.tf_state.id
  acl        = "private" // This ensures that the s3 bucket is restricted to the owner
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration {
    status = "Enabled" // helps with file recovery
  }
}

data "aws_iam_policy_document" "tf_state_s3" {
  statement {
    sid    = "TFStateS3Dependency"
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = ["arn:aws:iam::${var.aws_account_id}:oidc-provider/token.actions.githubusercontent.com"]
    }
    # https://developer.hashicorp.com/terraform/language/settings/backends/s3
    actions   = ["s3:ListBucket", "s3:GetObject", "s3:PutObject"]
    resources = [aws_s3_bucket.tf_state.arn]
  }
}

resource "aws_s3_bucket_policy" "tf_state_s3" {
  bucket = aws_s3_bucket.tf_state.id
  policy = data.aws_iam_policy_document.tf_state_s3.json
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

data "aws_iam_policy_document" "tf_state_dynamodb" {
  statement {
    sid    = "TFStateDynamoDBDependency"
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = ["arn:aws:iam::${var.aws_account_id}:oidc-provider/token.actions.githubusercontent.com"]
    }

    actions   = ["dynamodb:DescribeTable", "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
    resources = [aws_dynamodb_table.tf_state.arn]
  }
}

resource "aws_dynamodb_resource_policy" "tf_state_lock" {
  resource_arn = aws_dynamodb_table.tf_state.arn
  policy       = data.aws_iam_policy_document.tf_state_dynamodb.json
}
