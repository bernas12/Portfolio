variable "github_repo" {
  description = "GitHub repository name containing the Lambda code and Terraform configuration"
  type        = string
  default     = "<YOUR_REPO>" #Replace with your own
}

variable "artifact-s3-bucket" {
  description = "S3 bucket for storing artifacts for CodePipeline"
  type        = string
  default     = "<S3_BUCKET>" #Replace with your own
}

variable "TF_state_bucket" {
  description = "S3 bucket for Terraform state storage"
  type        = string
  default     = "<TF_BUCKET>" #Replace with your own
}

variable "TF_dynamodb_table" {
  description = "DynamoDB table for state locking"
  type        = string
  default     = "<TF_TABLE>" #Replace with your own
}