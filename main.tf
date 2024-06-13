provider "aws" {
  region = var.aws_region
}

# Generate a random string for uniqueness
resource "random_string" "suffix" {
  length  = 8
  special = false
}

# Create an S3 bucket to store the Lambda function code with a unique name
resource "aws_s3_bucket" "lambda_bucket" {
  bucket_prefix = "ai-summarizer-lambda-bucket-"
}

# Generate a random ID for the S3 object key
resource "random_id" "lambda_key" {
  byte_length = 8
}

# Upload the Lambda function ZIP file to the S3 bucket
resource "aws_s3_object" "lambda_zip" {
  bucket = aws_s3_bucket.lambda_bucket.bucket
  key    = "${random_id.lambda_key.hex}-my_deployment_package.zip"
  source = "my_deployment_package.zip" # Local path to your ZIP file
}

# Create a Lambda execution role
resource "aws_iam_role" "lambda_exec_role" {
  name = "ai_summarizer_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = { Service = "lambda.amazonaws.com" },
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

# Attach AWSLambdaBasicExecutionRole policy to the Lambda execution role
resource "aws_iam_policy_attachment" "lambda_basic_execution" {
  name       = "LambdaBasicExecution"
  roles      = [aws_iam_role.lambda_exec_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Create the Lambda function
resource "aws_lambda_function" "ai_summarizer" {
  function_name = "ai_summarizer_function_${random_string.suffix.result}"
  handler       = var.lambda_handler
  runtime       = "python3.10"
  role          = aws_iam_role.lambda_exec_role.arn
  timeout       = 30

  s3_bucket = aws_s3_bucket.lambda_bucket.bucket
  s3_key    = aws_s3_object.lambda_zip.key

  environment {
    variables = {
      OPENAI_API_KEY = var.openai_api_key
      OPENAI_MODEL   = var.openai_model
    }
  }

  tracing_config {
    mode = "Active"
  }

  depends_on = [aws_s3_object.lambda_zip]
}

# Create an API Gateway REST API
resource "aws_api_gateway_rest_api" "ai_summarizer_api" {
  name        = "AiSummarizerAPI"
  description = "API Gateway for AI Summarizer Lambda function"
}

# Create a resource for the API Gateway
resource "aws_api_gateway_resource" "ai_summarizer_resource" {
  rest_api_id = aws_api_gateway_rest_api.ai_summarizer_api.id
  parent_id   = aws_api_gateway_rest_api.ai_summarizer_api.root_resource_id
  path_part   = "summarize"
}

# Create a method for the API Gateway resource
resource "aws_api_gateway_method" "ai_summarizer_method" {
  rest_api_id   = aws_api_gateway_rest_api.ai_summarizer_api.id
  resource_id   = aws_api_gateway_resource.ai_summarizer_resource.id
  http_method   = "POST"
  authorization = "NONE"
  api_key_required = true
}

# Create an integration for the API Gateway method to the Lambda function
resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.ai_summarizer_api.id
  resource_id             = aws_api_gateway_resource.ai_summarizer_resource.id
  http_method             = aws_api_gateway_method.ai_summarizer_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.ai_summarizer.invoke_arn
}

# Create an API Gateway deployment
resource "aws_api_gateway_deployment" "api_deployment" {
  depends_on = [aws_api_gateway_integration.lambda_integration]
  rest_api_id = aws_api_gateway_rest_api.ai_summarizer_api.id
  stage_name  = "prod"
}

# Create an API Gateway API key
resource "aws_api_gateway_api_key" "ai_summarizer_api_key" {
  name        = "ai_summarizer_api_key"
  description = "API key for the AI Summarizer API"
  enabled     = true
}

# Create a usage plan for the API Gateway
resource "aws_api_gateway_usage_plan" "api_usage_plan" {
  depends_on = [aws_api_gateway_api_key.ai_summarizer_api_key]
  name = "ai_summarizer_usage_plan"
  api_stages {
    api_id = aws_api_gateway_rest_api.ai_summarizer_api.id
    stage  = aws_api_gateway_deployment.api_deployment.stage_name
  }
  quota_settings {
    limit  = 10000
    offset = 2
    period = "MONTH"
  }
  throttle_settings {
    burst_limit = 500
    rate_limit  = 100
  }
}

# Associate the API key with the usage plan
resource "aws_api_gateway_usage_plan_key" "usage_plan_key" {
  key_id        = aws_api_gateway_api_key.ai_summarizer_api_key.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.api_usage_plan.id
}

# Create a Lambda permission for API Gateway to invoke the Lambda function
resource "aws_lambda_permission" "api_gateway_invoke_lambda" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ai_summarizer.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.ai_summarizer_api.execution_arn}/*/${aws_api_gateway_method.ai_summarizer_method.http_method}/summarize"
}

output "api_key" {
  value     = aws_api_gateway_api_key.ai_summarizer_api_key.value
  sensitive = true  # Mark the output as sensitive to avoid exposing it in logs or outputs
}

output "api_gateway_url" {
  value = "${aws_api_gateway_deployment.api_deployment.invoke_url}/summarize"
}
