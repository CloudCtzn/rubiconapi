output "api_endpoint" {
    description = "Base URL for the Augur API"
    value = "${aws_apigatewayv2_stage.rubicon.invoke_url}/augur"
}

output "dynamodb_table" {
    description = "DynamoDB table name"
    value = aws_dynamodb_table.augur_results.name
}

output "lambda_function" {
    description = "Lambda function name"
    value = aws_lambda_function.augur.function_name
}