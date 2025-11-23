terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region = var.region
}

module "vpc" {
  source          = "../../modules/vpc"
  project         = var.project
  region          = var.region
  vpc_cidr        = var.vpc_cidr
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
}

############################
# ACM Certificate (DNS validation)
############################
resource "aws_acm_certificate" "cert" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  tags = {
    Name = "${var.project}-cert"
  }
}

output "acm_dns_validation_records" {
  value = aws_acm_certificate.cert.domain_validation_options
}

############################
# Application Load Balancer
############################
resource "aws_lb" "app" {
  name               = "${var.project}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = module.vpc.public_subnet_ids

  tags = { Name = "${var.project}-alb" }
}

# ALB Security Group
resource "aws_security_group" "alb" {
  name        = "${var.project}-alb-sg"
  description = "ALB SG"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

############################
# Target Group -> EC2 nginx
############################
resource "aws_lb_target_group" "nginx" {
  name     = "${var.project}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_target_group_attachment" "ec2" {
  target_group_arn = aws_lb_target_group.nginx.arn
  target_id        = aws_instance.web.id
  port             = 80
}

############################
# Listeners
############################

# HTTP -> HTTPS redirect
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS listener uses ACM cert
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.app.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate.cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nginx.arn
  }
}

output "alb_dns_name" {
  value = aws_lb.app.dns_name
}


# Grab latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# Security Group allowing SSH inbound
resource "aws_security_group" "ssh" {
  name        = "${var.project}-ssh"
  description = "Allow SSH inbound"
  vpc_id      = module.vpc.vpc_id

  # ingress {
  #   description = "SSH from anywhere (lab only)"
  #   from_port   = 22
  #   to_port     = 22
  #   protocol    = "tcp"
  #   cidr_blocks = [var.my_ip_cidr]
  # }

  # ingress {
  #   description     = "HTTP from ALB"
  #   from_port       = 80

  #   to_port         = 80
  #   protocol        = "tcp"
  #   security_groups = [aws_security_group.alb.id]
  # }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-ssh"
  }
}

############################
# SSM Access for Private EC2
############################
resource "aws_iam_role" "ssm" {
  name = "${var.project}-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "${var.project}-ssm-profile"
  role = aws_iam_role.ssm.name
}


# EC2 instance in public subnet 1
resource "aws_instance" "web" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.micro"
  subnet_id                   = module.vpc.private_subnet_ids[0]
  vpc_security_group_ids      = [aws_security_group.ssh.id]
  associate_public_ip_address = false
  key_name                    = "tf-lab-key"

  iam_instance_profile = aws_iam_instance_profile.ssm_profile.name

  user_data = <<-EOF
#!/bin/bash
set -xe

# Update system
dnf update -y

# Install Docker
dnf install -y docker
systemctl enable docker
systemctl start docker

# Allow ec2-user to run docker without sudo
usermod -aG docker ec2-user

# Install docker-compose v2 plugin
mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# Wait for Docker to fully start
sleep 15

# Run nginx container
docker rm -f nginx 2>/dev/null || true
docker run -d --name nginx -p 80:80 nginx

EOF




  tags = {
    Name = "${var.project}-ec2"
  }
}

output "ec2_public_ip" {
  value = aws_instance.web.public_ip
}

output "ec2_id" {
  value = aws_instance.web.id
}

