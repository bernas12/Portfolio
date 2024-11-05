# Documentation
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "eu-west-3"
}

######## Terraform State Management configuration #######

# Create s3 Bucket for Terraform State Management
resource "aws_s3_bucket" "TF_state_bucket" {
  bucket = var.TF_state_bucket
}

# Enable versioning for the s3 state bucket
resource "aws_s3_bucket_versioning" "TF_state_bucket" {
  bucket = aws_s3_bucket.TF_state_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable encryption for the s3 state bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "TF_state_bucket" {
  bucket = aws_s3_bucket.TF_state_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access to the s3 state bucket
resource "aws_s3_bucket_public_access_block" "TF_state_bucket" {
  bucket = aws_s3_bucket.TF_state_bucket.id
  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}

# Create DynamoDB Table for Terraform State Management
resource "aws_dynamodb_table" "TF_dynamodb_table" {
  name = var.TF_dynamodb_table
  billing_mode   = "PROVISIONED"
  hash_key = "LockID"
  read_capacity = 5
  write_capacity = 5

  attribute {
    name = "LockID"
    type = "S"
  }
}

######## CodeBUild configuration

# Creating IAM role for CodeBuild
resource "aws_iam_role" "Codebuild-Role" {
  name = "Codebuild-Role"

  assume_role_policy = jsonencode({
    "Version" = "2012-10-17"
    "Statement" = [
      {
        "Action" = "sts:AssumeRole"
        "Principal" = {
          "Service" = "codebuild.amazonaws.com"
        }
        "Effect" = "Allow"
      }
    ]
  })
}

# Create the IAM policy for the CodeBuild role
#Needs Policy for S3, Lambda, DynamoDB, Cloudwatch and IAM Role
resource "aws_iam_policy" "Codebuild-Policy" {
  name = "Codebuild-Policy"

  policy = jsonencode({
    "Version" = "2012-10-17"
    "Statement" = [
      {
        "Effect" = "Allow"
        "Action" = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:ListBucket",
          "s3:GetBucketAcl",
          "s3:GetBucketLocation"
        ]
        "Resource" = "*"
      },
      {
        "Effect" = "Allow"
        "Action" = [
          "lambda:*"
        ]
        "Resource" = "*"
      },
      {
        "Effect" = "Allow"
        "Action" = [
          "iam:GetRole",
				  "iam:PassRole",
				  "iam:GetPolicy",
				  "iam:CreateRole",
				  "iam:DeleteRole",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:ListInstanceProfilesForRole",
				  "iam:AttachRolePolicy"
        ]
        "Resource" = "*"
      },
      {
        "Effect" = "Allow"
        "Action" = [
          "dynamodb:CreateTable",
				  "dynamodb:PutItem",
				  "dynamodb:DescribeTable",
				  "dynamodb:ListTables",
				  "dynamodb:DeleteItem",
				  "dynamodb:GetItem",
				  "dynamodb:Query",
				  "dynamodb:UpdateItem",
				  "dynamodb:DeleteTable"
        ]
        "Resource" = "*"
      },
      {
        "Effect" = "Allow"
        "Action" = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        "Resource" = "*"
      }
    ]
  })
}

# Attach Codebuild-Policy Policy to the CodeBuild Role
resource "aws_iam_role_policy_attachment" "Codebuild-Policy-Attachment" {
  policy_arn = aws_iam_policy.Codebuild-Policy.arn
  role       = aws_iam_role.Codebuild-Role.name
}

# Create the CodeBuild project
resource "aws_codebuild_project" "Codebuild-DevOps-Project" {
  name = "Codebuild-DevOps-Project"
  description   = "CodeBuild project for DevOps metrics deployment"
  service_role = aws_iam_role.Codebuild-Role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type = "LINUX_CONTAINER"

    environment_variable {
      name  = "TERRAFORM_DYNAMODB_TABLE"
      value = var.TF_dynamodb_table
    }
     environment_variable {
      name  = "TERRAFORM_BUCKET"
      value = var.TF_state_bucket
    }
  }

  source {
    type = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }
}

####### CodePipeline Configuration

# Create GitHub connection with CodeStar
resource "aws_codestarconnections_connection" "DevOps-GitHub-Connection" {
  name = "DevOps-GitHub-Connection"
  provider_type = "GitHub"
}

# Create S3 bucket for artifacts
resource "aws_s3_bucket" "artifact-s3-bucket" {
  bucket = var.artifact-s3-bucket
}

# Enable versioning for the s3 artifacts bucket
resource "aws_s3_bucket_versioning" "artifact-s3-bucket" {
  bucket = aws_s3_bucket.artifact-s3-bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable encryption for the s3 artifacts bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "artifact-s3-bucket" {
  bucket = aws_s3_bucket.artifact-s3-bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access to the s3 artifacts bucket
resource "aws_s3_bucket_public_access_block" "artifact-s3-bucket" {
  bucket = aws_s3_bucket.artifact-s3-bucket.id
  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}

# Create IAM role for CodePipeline
resource "aws_iam_role" "Codepipeline-Role" {
  name = "Codepipeline-Role"

  assume_role_policy = jsonencode({
    "Version" = "2012-10-17"
    "Statement" = [
      {
        "Action" = "sts:AssumeRole"
        "Principal" = {
          "Service" = "codepipeline.amazonaws.com"
        }
        "Effect" = "Allow"
      }
    ]
  })
}

# Create the IAM policy for the CodePipeline role
resource "aws_iam_role_policy" "Codepipeline-Policy" {
  name = "Codepipeline-Policy"
  role = aws_iam_role.Codepipeline-Role.id

  policy = jsonencode({
    "Version" = "2012-10-17"
    "Statement" = [
      {
        "Effect" = "Allow"
        "Action" = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketVersioning",
          "s3:PutObject",
          "s3:GetBucketAcl",
          "s3:GetBucketLocation"
        ]
        "Resource" = "arn:aws:s3:::${var.artifact-s3-bucket}/*"
      },
      {
        "Effect" = "Allow"
        "Action" = [
          "codestar-connections:UseConnection"
        ]
        "Resource" = [aws_codestarconnections_connection.DevOps-GitHub-Connection.arn]
      },
      {
        "Effect" = "Allow"
        "Action" = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild"
        ]
        "Resource" = "*"
      },
      {
        "Effect" = "Allow"
        "Action" = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        "Resource" = "*"
      }
    ]
  })
}

# Create the CodePipeline
resource "aws_codepipeline" "DevOps-Pipeline" {
  name = "DevOps-Pipeline"
  role_arn = aws_iam_role.Codepipeline-Role.arn

  artifact_store {
    type = "S3"
    location = aws_s3_bucket.artifact-s3-bucket.id
  }

  stage {
    name = "Source"

    action {
      name = "Source"
      category = "Source"
      owner = "AWS"
      provider = "CodeStarSourceConnection"
      version = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn = aws_codestarconnections_connection.DevOps-GitHub-Connection.arn
        FullRepositoryId = "${var.github_repo}"
        BranchName = "main"
      }
    }
  }

  stage {
    name = "Build"
    action {
      name = "Build"
      category = "Build"
      owner = "AWS"
      provider = "CodeBuild"
      input_artifacts = ["source_output"]
      output_artifacts = ["build_output"]
      version = "1"
      configuration = {
        ProjectName = aws_codebuild_project.Codebuild-DevOps-Project.name
      }
    }
  }
}

