output "api_endpoint" {
  description = "Base URL for the Consul API"
  value       = "${aws_apigatewayv2_stage.consul.invoke_url}/consul"
}

output "dynamodb_table" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.consul_results.name
}

output "lambda_function" {
  description = "Lambda function name"
  value       = aws_lambda_function.consul.function_name
}