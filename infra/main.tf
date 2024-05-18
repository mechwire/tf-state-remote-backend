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