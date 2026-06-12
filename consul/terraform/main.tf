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

resource "aws_dynamodb_table" "consul_results" {
    name = "rubicon-consul-results"
    billing_mode = "PAY_PER_REQUEST"
    hash_key = "id"

    attribute {
      name = "id"
      type = "S"
    }

    tags = {
        Project = "RubiconAPI"
        API = "Consul"
    }
}

resource "aws_iam_role" "consul_lambda_role" {
    name = "rubicon-consul-lambda-role"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Principal = { Service = "lambda.amazonaws.com"}
        }]
    })
}



resource "aws_iam_role_policy" "consul_lambda_policy" {
    name = "rubicon-consul-lambda-policy"
    role = aws_iam_role.consul_lambda_role.id

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
                Action = ["bedrock:InvokeModel"]
                Resource = "*"
            },
            {
                Effect = "Allow"
                Action = [
                "dynamodb:PutItem",
                "dynamodb:GetItem",
                "dynamodb:Scan"
                ]
                Resource = aws_dynamodb_table.consul_results.arn
            }
    
        ]
    })
}

data "archive_file" "consul_zip" {
    type = "zip"
    source_file = "${path.module}/../lambda/consul.py"
    output_path = "${path.module}/../lambda/consul.zip"
}

resource "aws_lambda_function" "consul" {
    function_name = "rubicon-consul"
    role = aws_iam_role.consul_lambda_role.arn
    handler = "consul.lambda_handler"
    runtime = "python3.12"
    filename = data.archive_file.consul_zip.output_path
    source_code_hash = data.archive_file.consul_zip.output_base64sha256
    timeout = 60
    memory_size = 256
    kms_key_arn = null


    environment {
      variables = {
        ENVIRONMENT = var.environment
      }
    }

    tags = {
      Project = "RubiconAPI"
      API = "Consul"
    }
}

resource "aws_apigatewayv2_api" "consul" {
    name = "consul-api"
    protocol_type = "HTTP"

    cors_configuration {
      allow_origins = ["*"]
      allow_methods = ["POST", "OPTIONS"]
      allow_headers = ["Content-Type", "X-Api-Key"]
    }
  
}

resource "aws_apigatewayv2_stage" "consul" {
    api_id = aws_apigatewayv2_api.consul.id
    name = var.environment
    auto_deploy = true
}

resource "aws_apigatewayv2_integration" "consul" {
    api_id = aws_apigatewayv2_api.consul.id
    integration_type = "AWS_PROXY"
    integration_uri = aws_lambda_function.consul.invoke_arn
    payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "consul" {
    api_id = aws_apigatewayv2_api.consul.id
    route_key = "POST /consul"
    target = "integrations/${aws_apigatewayv2_integration.consul.id}"
}

resource "aws_lambda_permission" "consul_apigw" {
    statement_id = "AllowAPIGatewayInvoke"
    action = "lambda:InvokeFunction"
    function_name = aws_lambda_function.consul.function_name
    principal = "apigateway.amazonaws.com"
    source_arn = "${aws_apigatewayv2_api.consul.execution_arn}/*/*"
}