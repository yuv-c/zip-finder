provider "aws" {
  region  = "eu-central-1"
  profile = "zip-codes-prod"
}

resource "aws_instance" "es_kibana_instance" {
  ami           = "ami-08e415170f52d1657"
  instance_type = "r5d.large"
  key_name      = aws_key_pair.my_key.key_name

  vpc_security_group_ids = [aws_security_group.es_kibana_sg.id]

  tags = {
    Name = "ESKibana"
  }
  # editing and then running apply will create a new instance
  user_data = <<-EOF
              #!/bin/bash
              echo "Setting up docker"
              sudo yum update -y
              sudo yum install -y docker
              sudo service docker start
              sudo usermod -a -G docker ec2-user
              sudo systemctl enable docker
              sudo chkconfig docker on

              # Pull the images
              echo "Pulling images"
              sudo docker pull docker.elastic.co/kibana/kibana:7.10.2
              sudo docker pull docker.elastic.co/elasticsearch/elasticsearch:7.10.2

              # Start the containers
              echo "Starting containers"
              sudo docker run -d --name elasticsearch -p 9200:9200 -p 9300:9300 -e "discovery.type=single-node" --restart always -v es_data:/usr/share/elasticsearch/data docker.elastic.co/elasticsearch/elasticsearch:7.10.2
              sudo docker run -d --name kibana --link elasticsearch:elasticsearch -p 5601:5601 --restart always -v kibana_data:/usr/share/kibana/data docker.elastic.co/kibana/kibana:7.10.2

              # Install plugin
              echo "Installing plugin"
              sudo docker exec elasticsearch ./bin/elasticsearch-plugin install --batch https://github.com/Immanuelbh/elasticsearch-analysis-hebrew/releases/download/elasticsearch-analysis-hebrew-7.10.2/elasticsearch-analysis-hebrew-7.10.2.zip

              # Restart elasticsearch and kibana
              sudo docker restart elasticsearch kibana
              EOF
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

resource "aws_iam_role_policy" "ec2_stop" {
  name = "ec2_stop"
  role = aws_iam_role.lambda_ec2_manager.id

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "ec2:Stop*"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/stop_ec2_alarm_handler.py"
  output_path = "${path.module}/function.zip"
}

resource "aws_lambda_function" "stop_ec2" {
  filename      = "${path.module}/function.zip"
  function_name = "stop_ec2"
  role          = aws_iam_role.lambda_ec2_manager.arn
  handler       = "stop_ec2.handler"
  runtime       = "python3.10"

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  tags = {
    Name = "stop_ec2_lambda"
  }
}

resource "aws_sns_topic" "alarm_topic" {
  name = "alarm-topic"
}

resource "aws_lambda_permission" "sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.stop_ec2.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.alarm_topic.arn
}

resource "aws_sns_topic_subscription" "lambda_subscription" {
  topic_arn = aws_sns_topic.alarm_topic.arn
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
  threshold           = "10"
  alarm_description   = "This metric checks if EC2 instance is idle for 30 minutes"
  alarm_actions       = [aws_sns_topic.alarm_topic.arn]

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
  alarm_actions       = [aws_sns_topic.alarm_topic.arn]

  dimensions = {
    InstanceId = aws_instance.es_kibana_instance.id
  }
}