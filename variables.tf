variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "lambda_s3_key" {
  description = "S3 key for the Lambda function ZIP file"
  type        = string
}

variable "lambda_handler" {
  description = "Handler for the Lambda function"
  type        = string
}

variable "openai_api_key" {
  description = "OpenAI API key"
  type        = string
}

variable "openai_model" {
  description = "OpenAI model"
  type        = string
}
