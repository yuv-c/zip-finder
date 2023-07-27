provider "aws" {
  region  = var.region
  profile = "zip-codes-prod"
}

resource "aws_instance" "es_kibana_instance" {
  ami           = "ami-0dc7fe3dd38437495"
  instance_type = "m4.large"
  key_name      = aws_key_pair.my_key.key_name

  vpc_security_group_ids = [aws_security_group.public_es_sg.id]
  subnet_id              = aws_subnet.subnet_es_ec2.id

  tags = {
    Name = "ESKibana"
  }

  user_data = file("init_es_kibana.sh")
}

resource "aws_key_pair" "my_key" {
  key_name   = "my_key"
  public_key = file("~/.ssh/id_rsa.pub")
}

# ************ CloudWatch alarm and handler to stop the instance if inactive (network I/O) or uptime over X hours ************
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

data "archive_file" "stop_ec2_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/stop_ec2_alarm_handler.py"
  output_path = "${path.module}/stop_ec2_alarm_handler.zip"
}

resource "aws_lambda_function" "stop_ec2" {
  filename      = "${path.module}/stop_ec2_alarm_handler.zip"
  function_name = "stop_ec2_alarm_handler"
  role          = aws_iam_role.lambda_ec2_manager.arn
  handler       = "stop_ec2_alarm_handler.handler"
  runtime       = "python3.10"

  source_code_hash = data.archive_file.stop_ec2_lambda_zip.output_base64sha256

  tags = {
    Name = "stop_ec2_lambda"
  }
}

resource "aws_sns_topic" "stop_ec2_sns_topic" {
  name = "alarm-topic"
}

resource "aws_lambda_permission" "sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.stop_ec2.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.stop_ec2_sns_topic.arn
}

resource "aws_sns_topic_subscription" "lambda_subscription" {
  topic_arn = aws_sns_topic.stop_ec2_sns_topic.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.stop_ec2.arn
}

resource "aws_cloudwatch_metric_alarm" "idle_ec2" {
  alarm_name          = "idle_ec2"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "NetworkPacketsOut"
  namespace           = "AWS/EC2"
  period              = "900"  # 15 minutes
  statistic           = "SampleCount"
  threshold           = "20"
  alarm_description   = "This metric checks if EC2 instance is idle for 30 minutes"
  alarm_actions       = [aws_sns_topic.stop_ec2_sns_topic.arn]

  dimensions = {
    InstanceId = aws_instance.es_kibana_instance.id
  }
}

resource "aws_cloudwatch_metric_alarm" "long_running_ec2" {
  alarm_name          = "long_running_ec2"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "20"   # 20 periods of 15 minutes each = 5 hours
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "900"  # 15 minutes
  statistic           = "SampleCount"
  threshold           = "1"    # CPU utilization sample count
  alarm_description   = "This metric checks if EC2 instance is running for more than 5 hours"
  alarm_actions       = [aws_sns_topic.stop_ec2_sns_topic.arn]

  dimensions = {
    InstanceId = aws_instance.es_kibana_instance.id
  }
}