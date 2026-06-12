output "api_endpoint" {
  description = "Base URL for the Specula API"
  value       = "${aws_apigatewayv2_stage.specula.invoke_url}/specula"
}

output "dynamodb_table" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.specula_results.name
}

output "lambda_function" {
  description = "Lambda function name"
  value       = aws_lambda_function.specula.function_name
}