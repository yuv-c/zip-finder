# *************************************************************************
# ******************************* VPC & IGW *******************************
# *************************************************************************
resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "main"
  }
}

resource "aws_subnet" "subnet_zip_api" {
  vpc_id     = aws_vpc.main_vpc.id
  cidr_block = "10.0.1.0/24"

  map_public_ip_on_launch = true

  tags = {
    Name = "subnet_zip_api"
  }
}

resource "aws_subnet" "subnet_es_ec2" {
  vpc_id     = aws_vpc.main_vpc.id
  cidr_block = "10.0.2.0/24"

  map_public_ip_on_launch = true

  tags = {
    Name = "subnet_es_ec2"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "main_igw"
  }
}

# *******************************************************************************
# ******************************* Route Table ***********************************
# *******************************************************************************
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public_route_table"
  }
}

resource "aws_route_table_association" "zip_api_rt_association" {
  subnet_id      = aws_subnet.subnet_zip_api.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "ec2_rt_association" {
  subnet_id      = aws_subnet.subnet_es_ec2.id
  route_table_id = aws_route_table.public.id
}

# ***********************************************************************************
# *************************** Lambda ZIP Code REST API ******************************
# ***********************************************************************************

resource "aws_api_gateway_rest_api" "es_zip_gateway_rest_api" {
  name        = "es_zip_gateway_rest_api"
  description = "REST API for Lambda to ES"
}

resource "aws_api_gateway_resource" "query_lambda" {
  rest_api_id = aws_api_gateway_rest_api.es_zip_gateway_rest_api.id
  parent_id   = aws_api_gateway_rest_api.es_zip_gateway_rest_api.root_resource_id
  path_part   = "zip-api"
}

resource "aws_api_gateway_method" "get_zip_api" {
  rest_api_id   = aws_api_gateway_rest_api.es_zip_gateway_rest_api.id
  resource_id   = aws_api_gateway_resource.query_lambda.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_to_es_gateway_integration" {
  rest_api_id = aws_api_gateway_rest_api.es_zip_gateway_rest_api.id
  resource_id = aws_api_gateway_resource.query_lambda.id
  http_method = aws_api_gateway_method.get_zip_api.http_method

  type = "AWS_PROXY"

  integration_http_method = "POST"
  uri                     = aws_lambda_function.query_es_lambda.invoke_arn
}

