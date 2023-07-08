data "archive_file" "query_es_zip" {
  type        = "zip"
  source_file = "${path.module}/query_es.py"
  output_path = "${path.module}/query_es.zip"
}

resource "aws_lambda_layer_version" "lambda_layer" {
  filename            = "${path.module}/requests_layer.zip"
  layer_name          = "requests_layer"
  compatible_runtimes = ["python3.10"]
}

resource "aws_lambda_function" "query_es_lambda" {
  filename      = "${path.module}/query_es.zip"
  function_name = "query_es"
  role          = aws_iam_role.lambda_es_query.arn
  handler       = "query_es.lambda_handler"
  runtime       = "python3.10"
  layers        = [aws_lambda_layer_version.lambda_layer.arn]

  tags = {
    Name = "query_es_lambda"
  }

  environment {
    variables = {
      ES_ENDPOINT = aws_instance.es_kibana_instance.private_ip
    }
  }

  vpc_config {
    subnet_ids         = [aws_subnet.subnet_zip_api.id]
    security_group_ids = [aws_security_group.public_es_sg.id]
  }

  source_code_hash = data.archive_file.query_es_zip.output_base64sha256
}

# Access control for lambda function to ES (on EC2) is done at the SG level
resource "aws_iam_role" "lambda_es_query" {
  name = "lambda_es_query"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com",
        },
        Action = "sts:AssumeRole",
      },
    ]
  })
}

resource "aws_iam_role_policy" "lambda_es_query_policy" {
  name = "lambda_es_query_policy"
  role = aws_iam_role.lambda_es_query.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateNetworkInterface",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DeleteNetworkInterface"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_es_query_logs" {
  role       = aws_iam_role.lambda_es_query.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.query_es_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${replace(aws_api_gateway_deployment.api_gateway_deployment.execution_arn, var.stage_name, "")}*/*"
}