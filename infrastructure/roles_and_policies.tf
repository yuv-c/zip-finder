resource "aws_iam_role" "lambda_ec2_manager" {
  name = "lambda_ec2_manager"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Effect = "Allow"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_ec2_manager_vpc" {
  role       = aws_iam_role.lambda_ec2_manager.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "ec2_stop" {
  name = "ec2_stop"
  role = aws_iam_role.lambda_ec2_manager.id

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:Stop*"
        ]
        Effect   = "Allow"
        Resource = aws_instance.es_kibana_instance.arn
      },
    ]
  })
}

# ********************************************************************************************************************
# ******************************************** Query ES Lambda *******************************************************
# ********************************************************************************************************************

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


# ********************************************************************************************************************
# ************************************************ API GW ************************************************************
# ********************************************************************************************************************

resource "aws_iam_role" "api_gateway_cloudwatch_logs" {
  name = "api_gateway_cloudwatch_logs"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "apigateway.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "api_gateway_cloudwatch_logs" {
  name = "api_gateway_cloudwatch_logs"
  role = aws_iam_role.api_gateway_cloudwatch_logs.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
        "logs:PutLogEvents",
        "logs:GetLogEvents",
        "logs:FilterLogEvents"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_api_gateway_account" "api_gateway_account" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch_logs.arn
}
