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