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

  user_data = file("./scripts/init_es_kibana.sh")
}

resource "aws_key_pair" "my_key" {
  key_name   = "my_key"
  public_key = file("~/.ssh/id_rsa.pub")
}
