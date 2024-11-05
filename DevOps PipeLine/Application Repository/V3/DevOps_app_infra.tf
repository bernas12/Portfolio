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


# Create the DynamoDB table
resource "aws_dynamodb_table" "MetricsDB" {
  name           = "MetricsDB"
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "MetricID"

  attribute {
    name = "MetricID"
    type = "S"
  }
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

# Create the DynamoDB policy
resource "aws_iam_policy" "Metrics-DynamoDB-Policy" {
  name        = "Metrics-DynamoDB-Policy"
  description = "IAM policy to allow Lambda to access DynamoDB"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem"
        ],
        Effect   = "Allow",
        Resource = aws_dynamodb_table.MetricsDB.arn
      }
    ]
  })
}


# Attach Policy to the Lambda Role
resource "aws_iam_role_policy_attachment" "Metrics-policy-attachment" {
  role       = aws_iam_role.Metrics-role.name
  policy_arn = aws_iam_policy.Metrics-DynamoDB-Policy.arn
}

# Create the Lambda function
resource "aws_lambda_function" "MetricsAPP" {
  function_name = "MetricsAPP"
  role          = aws_iam_role.Metrics-role.arn
  handler       = "metric_app_V1.lambda_handler"
  runtime       = "python3.12"
  filename      = "metric_app_V1.zip"  # Make sure it present in the same directory
  }

# Create API Gateway
resource "aws_api_gateway_rest_api" "MetricsAPI" {
  name = "MetricsAPI"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# Create metrics resource for the API
resource "aws_api_gateway_resource" "metrics_resource" {
  path_part   = "metrics"
  parent_id   = aws_api_gateway_rest_api.MetricsAPI.root_resource_id
  rest_api_id = aws_api_gateway_rest_api.MetricsAPI.id
}

# Create POST method for the API
resource "aws_api_gateway_method" "post_method" {
  rest_api_id   = aws_api_gateway_rest_api.MetricsAPI.id
  resource_id   = aws_api_gateway_resource.metrics_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

# Integrate the Lambda function with the API Gateway
resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id = aws_api_gateway_rest_api.MetricsAPI.id
  resource_id = aws_api_gateway_resource.metrics_resource.id
  http_method = aws_api_gateway_method.post_method.http_method
  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = aws_lambda_function.MetricsAPP.invoke_arn
  depends_on = [aws_api_gateway_method.post_method]
}

# Grant API Gateway permission to invoke the Lambda function
resource "aws_lambda_permission" "apigw_lambda_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.MetricsAPP.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.MetricsAPI.execution_arn}/*/*"
}

# Create thhe OPTION method for the API Gateway (CORS)
resource "aws_api_gateway_method" "options_method" {
  rest_api_id   = aws_api_gateway_rest_api.MetricsAPI.id
  resource_id   = aws_api_gateway_resource.metrics_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# Integrate OPTION method with MOCK integration
resource "aws_api_gateway_integration" "options_integration" {
  rest_api_id = aws_api_gateway_rest_api.MetricsAPI.id
  resource_id = aws_api_gateway_resource.metrics_resource.id
  http_method = aws_api_gateway_method.options_method.http_method
  type        = "MOCK"
  depends_on = [aws_api_gateway_method.options_method]
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

# Create the method response for the OPTION method
resource "aws_api_gateway_method_response" "options_method_response" {
  rest_api_id = aws_api_gateway_rest_api.MetricsAPI.id
  resource_id = aws_api_gateway_resource.metrics_resource.id
  http_method = aws_api_gateway_method.options_method.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
  depends_on = [aws_api_gateway_method.options_method]
}

# Create the integration response for the OPTION method
resource "aws_api_gateway_integration_response" "options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.MetricsAPI.id
  resource_id = aws_api_gateway_resource.metrics_resource.id
  http_method = aws_api_gateway_method.options_method.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
  depends_on = [
    aws_api_gateway_method_response.options_method_response,
    aws_api_gateway_integration.options_integration
  ]
}

# Create the method response for the API Gateway
resource "aws_api_gateway_method_response" "method_response" {
  rest_api_id = aws_api_gateway_rest_api.MetricsAPI.id
  resource_id = aws_api_gateway_resource.metrics_resource.id
  http_method = aws_api_gateway_method.post_method.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
  depends_on = [aws_api_gateway_method.post_method]
}

# Create the integration response for the API Gateway
resource "aws_api_gateway_integration_response" "integration_response" {
  rest_api_id = aws_api_gateway_rest_api.MetricsAPI.id
  resource_id = aws_api_gateway_resource.metrics_resource.id
  http_method = aws_api_gateway_method.post_method.http_method
  status_code = aws_api_gateway_method_response.method_response.status_code
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }
  depends_on = [
    aws_api_gateway_integration.lambda_integration,
    aws_api_gateway_method_response.method_response
  ]
}

# Deploy the API Gateway
resource "aws_api_gateway_deployment" "metrics_deployment" {
  depends_on = [
    aws_api_gateway_integration.lambda_integration,
    aws_api_gateway_integration_response.integration_response,
    aws_api_gateway_integration_response.options_integration_response
  ]
  rest_api_id = aws_api_gateway_rest_api.MetricsAPI.id
  stage_name  = "dev"
}

# Backend State management for the Terraform state
terraform {
  backend "s3" {
    bucket         = "<YOUR TF STATE BUCKET NAME>" #change for your own
    key            = "terraform.tfstate"
    dynamodb_table = "terraform-lock"
    encrypt        = true
  }
}