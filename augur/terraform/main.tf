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


# DynamoDB Table
resource "aws_dynamodb_table" "augur_results" {
    name = "rubicon-augur-results"
    billing_mode = "PAY_PER_REQUEST"
    hash_key = "id"

    attribute {
        name = "id"
        type = "S"
    }

    tags = {
        Project = "RubiconAPI"
        API = "Augur"
    }
}

# IAM Role 
resource "aws_iam_role" "augur_lambda_role" {
    name = "rubicon-augur-lambda-role"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Principal = { Service = "lambda.amazonaws.com"}
        }]
    })
}

# IAM Policy 
resource "aws_iam_role_policy" "augur_lambda_policy" {
    name = "rubicon-augur-lambda-policy"
    role = aws_iam_role.augur_lambda_role.id

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
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
            Action = ["comprehend:DetectSentiment"]
            Resource = "*"
        },
        {
            Effect = "Allow"
            Action = [
                "dynamodb:PutItem",
                "dynamodb:GetItem",
                "dynamodb:Scan"
            ]
            Resource = aws_dynamodb_table.augur_results.arn
        }

        ]
    })
}

# Lambda Function 
data "archive_file" "augur_zip" {
    type = "zip"
    source_file = "${path.module}/../lambda/augur.py"
    output_path = "${path.module}/../lambda/augur.zip"
}

resource "aws_lambda_function" "augur" {
    function_name = "rubicon-augur"
    role = aws_iam_role.augur_lambda_role.arn
    handler = "augur.lambda_handler"
    runtime = "python3.12"
    filename = data.archive_file.augur_zip.output_path
    source_code_hash = data.archive_file.augur_zip.output_base64sha256
    timeout = 30
    memory_size = 128

    environment {
        variables = {
            ENVIRONMENT = var.environment
            RAPIDAPI_SECRET = var.rapidapi_secret
        }
    }

    tags = {
        Project = "RubiconAPI"
        API = "Augur"
    }
}



# API Gateway 
resource "aws_apigatewayv2_api" "rubicon" {
    name = "rubicon-api"
    protocol_type = "HTTP"

    cors_configuration {
      allow_origins = ["*"]
      allow_methods = ["POST", "OPTIONS"]
      allow_headers = ["Content-Type", "X-Api-Key"]
    }
}

resource "aws_apigatewayv2_stage" "rubicon" {
    api_id = aws_apigatewayv2_api.rubicon.id
    name = var.environment
    auto_deploy = true
}

resource "aws_apigatewayv2_integration" "augur"{
    api_id = aws_apigatewayv2_api.rubicon.id
    integration_type = "AWS_PROXY"
    integration_uri = aws_lambda_function.augur.invoke_arn
    payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "augur" {
    api_id = aws_apigatewayv2_api.rubicon.id
    route_key = "POST /augur"
    target = "integrations/${aws_apigatewayv2_integration.augur.id}"
}

resource "aws_lambda_permission" "augur_apigw" {
    statement_id = "AllowAPIGatewayInvoke"
    action = "lambda:InvokeFunction"
    function_name = aws_lambda_function.augur.function_name
    principal = "apigateway.amazonaws.com"
    source_arn = "${aws_apigatewayv2_api.rubicon.execution_arn}/*/*"
}

