terraform {
    required_providers {
      aws = {
        source = "hashicorp/aws"
        version = "~> 5.0"
      }
    }
}

provider "aws" {
    region = var.aws_region
}

resource "aws_dynamodb_table" "specula_results" {
    name = "rubicon-specula-results"
    billing_mode = "PAY_PER_REQUEST"
    hash_key = "id"

    attribute {
      name = "id"
      type = "S"
    }

    tags = {
        Project = "RubiconAPI"
        API = "Specula"
    }
}

resource "aws_iam_role" "specula_lambda_role" {
    name = "rubicon-specula-lambda-role"

    assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = { Service = "lambda.amazonaws.com"}
        }]
    })
}

resource "aws_iam_role_policy" "specula_lambda_policy" {
    name = "rubicon-specula-lambda-policy"
    role = aws_iam_role.specula_lambda_role.id

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Effect = "Allow"
                Action = [
                    "logs:CreateLogGroup",
                    "logs:CreateLogStream",
                    "logs:PutLogEvents"
                ]
                Resource = "arn:aws:logs:*:*:*"
            },
            {
                Effect = "Allow"
                Action = [
                    "comprehend:DetectKeyPhrases",
                    "comprehend:DetectEntities"
                ]
                Resource = "*" 
            },
            {
                Effect = "Allow"
                Action = [
                    "dynamodb:PutItem",
                    "dynamodb:GetItem",
                    "dynamodb:Scan"
                ]
                Resource = aws_dynamodb_table.specula_results.arn
            }
        ]
    })
}

data "archive_file" "specula_zip" {
    type = "zip"
    source_file = "${path.module}/../lambda/specula.py"
    output_path = "${path.module}/../lambda/specula.zip"
}

resource "aws_lambda_function" "specula" {
    function_name = "rubicon-specula"
    role = aws_iam_role.specula_lambda_role.arn
    handler = "specula.lambda_handler"
    runtime = "python3.12"
    filename = data.archive_file.specula_zip.output_path
    source_code_hash = data.archive_file.specula_zip.output_base64sha256
    timeout = 30
    memory_size = 128

    environment {
      variables = {
        ENVIRONMENT = var.environment
        
      }
    }

    tags = {
      Project = "RubiconAPI"
      API = "Specula"
    }
}

resource "aws_apigatewayv2_api" "specula" {
    name = "specula-api"
    protocol_type = "HTTP"

    cors_configuration {
      allow_origins = ["*"]
      allow_methods = ["POST", "OPTIONS"]
      allow_headers = ["Content-Type", "X-Api-Key"]
    }
}

resource "aws_apigatewayv2_stage" "specula" {
    api_id = aws_apigatewayv2_api.specula.id
    name = var.environment
    auto_deploy = true
}

resource "aws_apigatewayv2_integration" "specula" {
    api_id = aws_apigatewayv2_api.specula.id
    integration_type = "AWS_PROXY"
    integration_uri = aws_lambda_function.specula.invoke_arn
    payload_format_version = "2.0"  
}

resource "aws_apigatewayv2_route" "specula" {
    api_id = aws_apigatewayv2_api.specula.id
    route_key = "POST /specula"
    target = "integrations/${aws_apigatewayv2_integration.specula.id}"
}

resource "aws_lambda_permission" "specula_apigw" {
    statement_id = "AllowAPIGatewayInvoke"
    action = "lambda:InvokeFunction"
    function_name = aws_lambda_function.specula.function_name
    principal = "apigateway.amazonaws.com"
    source_arn = "${aws_apigatewayv2_api.specula.execution_arn}/*/*"
}