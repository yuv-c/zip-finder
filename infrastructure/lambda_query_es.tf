data "archive_file" "query_es_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_handlers/query_es.py"
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
      ES_ENDPOINT    = aws_instance.es_kibana_instance.private_ip
      CLOUDFRONT_URL = "https://${aws_cloudfront_distribution.s3_distribution_prod.domain_name}"
    }
  }

  vpc_config {
    subnet_ids         = [aws_subnet.subnet_zip_api.id]
    security_group_ids = [aws_security_group.public_es_sg.id]
  }

  source_code_hash = data.archive_file.query_es_zip.output_base64sha256
}
