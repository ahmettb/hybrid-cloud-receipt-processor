resource "aws_vpc" "main" {
  cidr_block           = "172.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "${var.project_name}-vpc" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "172.0.2.0/24"
  availability_zone       = var.availability_zones
  map_public_ip_on_launch = true
  tags = { Name = "public" }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "172.0.1.0/24"
  availability_zone = var.availability_zones
  tags = { Name = "private" }
}

# data "aws_ami" "nat_ami" {
#   most_recent = true
#   owners      = ["amazon"]
#   filter {
#     name   = "name"
#     values = ["amzn2-ami-hvm-*-x86_64-gp2"]
#   }
# }

# resource "aws_instance" "nat_instance" {
#   ami                    = data.aws_ami.nat_ami.id
#   instance_type          = var.instance_type
#   subnet_id              = aws_subnet.public.id
#   vpc_security_group_ids = [aws_security_group.nat_instance_sg.id]
#   source_dest_check      = false 
#   user_data = <<-EOF
#               #!/bin/bash
#               sudo yum install iptables-services -y
#               sudo systemctl enable iptables
#               sudo systemctl start iptables
#               echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
#               sudo sysctl -p
#               sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
#               sudo service iptables save
#               EOF
#   tags = { Name = "${var.project_name}-nat-instance" }
# }

# resource "aws_security_group" "nat_instance_sg" {
#   name   = "nat-sg"
#   vpc_id = aws_vpc.main.id
#   ingress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["172.0.1.0/24"]
#   }
#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# }


resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public.id 

  tags = {
    Name = "${var.project_name}-nat-gateway"
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private_rt.id
}


resource "aws_security_group" "lambda_sg" {
  name   = "lambda-sg"
  vpc_id = aws_vpc.main.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "endpoint_sg" {
  name   = "endpoint-sg"
  vpc_id = aws_vpc.main.id
  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda_sg.id]
  }
}

resource "aws_vpc_endpoint" "s3_gw" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.us-east-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private_rt.id]
}

resource "aws_vpc_endpoint" "textract" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.us-east-1.textract"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.endpoint_sg.id]
  subnet_ids          = [aws_subnet.private.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "bedrock" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.us-east-1.bedrock-runtime"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.endpoint_sg.id]
  subnet_ids          = [aws_subnet.private.id]
  private_dns_enabled = true
}

resource "aws_iam_role" "lambda_main_role" {
  name = "lambda-main-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "vpc_access" {
  role       = aws_iam_role.lambda_main_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "textract_access" {
  role       = aws_iam_role.lambda_main_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonTextractFullAccess"
}

resource "aws_iam_role_policy_attachment" "bedrock_access" {
  role       = aws_iam_role.lambda_main_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonBedrockFullAccess"
}

resource "aws_iam_role_policy_attachment" "s3_full" {
  role       = aws_iam_role.lambda_main_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_s3_bucket" "receipt_bucket" {
  bucket = var.s3_bucket_name
}

resource "aws_lambda_function" "textract_lambda" {
  filename         = "${path.module}/lambda_source/python-ocr-aws.zip"
  function_name    = "textract-processor"
  role             = aws_iam_role.lambda_main_role.arn
  handler          = "lambda_function.lambda_handler" 
  runtime          = "python3.12"
  source_code_hash = filebase64sha256("${path.module}/lambda_source/python-ocr-aws.zip")
  timeout          = 180
  vpc_config {
    subnet_ids         = [aws_subnet.private.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }
  environment {
    variables = {
      DB_USER         = var.db_user
      DB_PASSWORD     = var.db_password
      DB_DSN          = var.db_dsn
      WALLET_PASSWORD = var.wallet_password
    }
  }
}

resource "aws_lambda_function" "receipt_db_reader" {
  filename         = "${path.module}/lambda_source/db-reader.zip"
  function_name    = "receipt-db-reader"
  role             = aws_iam_role.lambda_main_role.arn
  handler          = "lambda_function.lambda_handler"
  timeout          = 180
  runtime          = "python3.12"
  source_code_hash = filebase64sha256("${path.module}/lambda_source/db-reader.zip")
  vpc_config {
    subnet_ids         = [aws_subnet.private.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }
  environment {
    variables = {
      DB_USER         = var.db_user
      DB_PASSWORD     = var.db_password
      DB_DSN          = var.db_dsn
      WALLET_PASSWORD = var.wallet_password
    }
  }
}

resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.textract_lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.receipt_bucket.arn
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.receipt_bucket.id
  lambda_function {
    lambda_function_arn = aws_lambda_function.textract_lambda.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".jpg" 
  }
  depends_on = [aws_lambda_permission.allow_s3]
}

resource "aws_api_gateway_rest_api" "receipt_api" {
  name = "receipt-rest-api"
}

resource "aws_api_gateway_resource" "receipt_resource" {
  rest_api_id = aws_api_gateway_rest_api.receipt_api.id
  parent_id   = aws_api_gateway_rest_api.receipt_api.root_resource_id
  path_part   = "receipts"
}

resource "aws_api_gateway_method" "receipt_method" {
  rest_api_id   = aws_api_gateway_rest_api.receipt_api.id
  resource_id   = aws_api_gateway_resource.receipt_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.receipt_api.id
  resource_id             = aws_api_gateway_resource.receipt_resource.id
  http_method             = aws_api_gateway_method.receipt_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.receipt_db_reader.invoke_arn
}

resource "aws_api_gateway_deployment" "deployment" {
  depends_on  = [aws_api_gateway_integration.lambda_integration]
  rest_api_id = aws_api_gateway_rest_api.receipt_api.id

  lifecycle {
    create_before_destroy = true
  }

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.receipt_resource.id,
      aws_api_gateway_method.receipt_method.id
    ]))
  }
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.deployment.id
  rest_api_id   = aws_api_gateway_rest_api.receipt_api.id
  stage_name    = "prod"
}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.receipt_db_reader.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.receipt_api.execution_arn}/*/*"
}