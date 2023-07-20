resource "aws_api_gateway_rest_api" "zip_rest_api" {
  name        = "es_zip_gateway_rest_api"
  description = "REST API for Lambda to ES"
}

resource "aws_api_gateway_resource" "zip-api" {
  rest_api_id = aws_api_gateway_rest_api.zip_rest_api.id
  parent_id   = aws_api_gateway_rest_api.zip_rest_api.root_resource_id
  path_part   = "zip-api"
}

resource "aws_api_gateway_method" "post_zip_api" {
  rest_api_id   = aws_api_gateway_rest_api.zip_rest_api.id
  resource_id   = aws_api_gateway_resource.zip-api.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "options_zip_api" {
  rest_api_id   = aws_api_gateway_rest_api.zip_rest_api.id
  resource_id   = aws_api_gateway_resource.zip-api.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "post_lambda_to_es" {
  rest_api_id             = aws_api_gateway_rest_api.zip_rest_api.id
  resource_id             = aws_api_gateway_resource.zip-api.id
  http_method             = aws_api_gateway_method.post_zip_api.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.query_es_lambda.invoke_arn
}

resource "aws_api_gateway_integration" "options_lambda_to_es" {
  rest_api_id = aws_api_gateway_rest_api.zip_rest_api.id
  resource_id = aws_api_gateway_resource.zip-api.id
  http_method = aws_api_gateway_method.options_zip_api.http_method

  type              = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_deployment" "api_gateway_deployment" {
  rest_api_id = aws_api_gateway_rest_api.zip_rest_api.id
  stage_name  = null # See api_gateway_prod_stage below

  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_integration.post_lambda_to_es))
    redeployment = sha1(jsonencode(aws_api_gateway_integration.options_lambda_to_es))
    redeployment = sha1(jsonencode(aws_api_gateway_method.post_zip_api))
    redeployment = sha1(jsonencode(aws_api_gateway_method.options_zip_api))
    redeployment = sha1(jsonencode(aws_api_gateway_resource.zip-api))
  }

  lifecycle {
    create_before_destroy = true
  }

}

resource "aws_api_gateway_stage" "api_gateway_prod_stage" {
  rest_api_id   = aws_api_gateway_rest_api.zip_rest_api.id
  deployment_id = aws_api_gateway_deployment.api_gateway_deployment.id
  stage_name    = var.stage_name
}

resource "aws_api_gateway_method_settings" "gateway_method_settings" {
  rest_api_id = aws_api_gateway_rest_api.zip_rest_api.id
  stage_name  = var.stage_name
  method_path = "*/*"
  depends_on  = [aws_api_gateway_deployment.api_gateway_deployment]

  settings {
    metrics_enabled = true
    logging_level   = "INFO"
  }
}

resource "aws_api_gateway_method_response" "options_zip-api_response" {
  http_method = "OPTIONS"
  resource_id = aws_api_gateway_resource.zip-api.id
  rest_api_id = aws_api_gateway_rest_api.zip_rest_api.id
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "options_zip-api" {
  http_method = "OPTIONS"
  resource_id = aws_api_gateway_resource.zip-api.id
  rest_api_id = aws_api_gateway_rest_api.zip_rest_api.id
  status_code = aws_api_gateway_method_response.options_zip-api_response.status_code

  response_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'",
    "method.response.header.Access-Control-Allow-Origin"  = "'https://${aws_cloudfront_distribution.s3_distribution_prod.domain_name}'"
    "method.response.header.Access-Control-Allow-Origin"  = "'https://${aws_cloudfront_distribution.s3_distribution_prod.domain_name}:3000'"
  }
}

resource "aws_cloudwatch_log_group" "api_gateway_execution_logs" {
  name              = "API-Gateway-Execution-Logs_${aws_api_gateway_rest_api.zip_rest_api.name}/${var.stage_name}"
  retention_in_days = 7
}

output "invoke_url" {
  value = "https://${aws_api_gateway_rest_api.zip_rest_api.id}.execute-api.${var.region}.amazonaws.com/prod"
}