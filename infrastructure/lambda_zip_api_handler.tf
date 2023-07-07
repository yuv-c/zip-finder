data "archive_file" "query_es_zip" {
  type        = "zip"
  source_file = "${path.module}/query_es.py"
  output_path = "${path.module}/query_es.zip"
}

resource "aws_lambda_function" "query_es_lambda" {
  filename      = "${path.module}/query_es.zip"
  function_name = "query_es"
  role          = aws_iam_role.lambda_es_query.arn
  handler       = "query_es.lambda_handler"
  runtime       = "python3.10"

  tags = {
    Name = "query_es_lambda"
  }

  environment {
    variables = {
      AWS_REGION  = "eu-central-1"
      ES_ENDPOINT = aws_instance.es_kibana_instance.public_ip
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

resource "aws_iam_role_policy_attachment" "lambda_es_query_logs" {
  role       = aws_iam_role.lambda_es_query.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

