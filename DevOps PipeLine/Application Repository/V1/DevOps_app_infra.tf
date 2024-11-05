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


# Create the Lambda role and attach policy
resource "aws_iam_role" "Metrics-role" {
  name = "Metrics-role" 

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Create the Lambda function
resource "aws_lambda_function" "MetricsAPP" {
  function_name = "MetricsAPP"
  role          = aws_iam_role.Metrics-role.arn
  handler       = "metric_app_V1.lambda_handler"
  runtime       = "python3.12"
  filename      = "metric_app.zip"  # Make sure it present in the same directory

  # Use source_code_hash to detect code changes
  source_code_hash = filebase64sha256("metric_app.zip")
}

# Backend State management for the Terraform state
terraform {
  backend "s3" {
    bucket         = "<YOUR TF STATE BUCKET NAME>" # Change for your own
    key            = "terraform.tfstate"
    dynamodb_table = "terraform-lock"
    encrypt        = true
  }
}