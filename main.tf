provider "aws" {
  region = "us-east-2" 
  access_key = "AKIAQEIP3NKUMCJTSRRL"
  secret_key = "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" 
}
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.10.10.0/24"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "vpc name"
  }
}

# Public Subnets
resource "aws_subnet" "public_subnet_1" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.10.10.0/26"
  availability_zone = "us-west-2a"
  map_public_ip_on_launch = true  # Enable public IP for instances in this subnet

  tags = {
    Name = "publicsubnet1"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.10.10.64/26"
  availability_zone = "us-west-2b"
  map_public_ip_on_launch = true  # Enable public IP for instances in this subnet

  tags = {
    Name = "PublicSubnet2"
  }
}

# Private Subnets
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.10.10.128/26"
  availability_zone = "us-west-2a"

  tags = {
    Name = "PrivateSubnet1"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.10.10.192/26"
  availability_zone = "us-west-2b"

  tags = {
    Name = "PrivateSubnet2"
  }
}
resource "aws_internet_gateway" "my_igw" {
vpc_id = aws_vpc.my_vpc.id
}

resource "aws_eip" "my_eip" {
domain = true
}

resource "aws_nat_gateway" "my_nat_gateway" {
allocation_id = aws_eip.my_eip.id
subnet_id = aws_subnet.my_public_subnet_1.id
}

resource "aws_security_group" "my_security_group" {
vpc_id = aws_vpc.my_vpc.id

ingress {
from_port = 80
to_port = 80
protocol = "tcp"
cidr_blocks = [aws_security_group.alb_sg.id]
}

ingress {
from_port = 22
to_port = 22
protocol = "tcp"
cidr_blocks = ["0.0.0.0/0"]
}
ingress {
from_port = 443
to_port = 443
protocol = "tcp"
cidr_blocks = [aws_security_group.alb_sg.id]
}
egress {
from_port   = 0
to_port     = 0
protocol    = "-1"
cidr_blocks = ["0.0.0.0/0"]
}
tags = {
Name = "sg_name"
}
}

resource "aws_instance" "my_instance" {
ami = "<amiid>"
instance_type = "t2.micro"
key_name      = aws_key_pair.jaga_key.key_name
subnet_id = aws_subnet.my_private_subnet_1.id
security_groups = [aws_security_group.my_security_group.name]
tags = {
Name = "PrivateInstance"
}
  associate_public_ip_address = false
}

resource "aws_route_table" "public_route_table" {
vpc_id = aws_vpc.my_vpc.id

route {
cidr_block = "0.0.0.0/0"
gateway_id = aws_internet_gateway.my_igw.id
}
}

resource "aws_route_table_association" "public_route_table_assoc_1" {
subnet_id = aws_subnet.my_public_subnet_1.id
route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_route_table_assoc_2" {
subnet_id = aws_subnet.my_public_subnet_2.id
route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table" "private_route_table" {
vpc_id = aws_vpc.my_vpc.id

route {
cidr_block = "0.0.0.0/0"
nat_gateway_id = aws_nat_gateway.my_nat_gateway.id
}
}

resource "aws_route_table_association" "private_route_table_assoc_1" {
subnet_id = aws_subnet.my_private_subnet_1.id
route_table_id = aws_route_table.private_route_table.id
}

resource "aws_route_table_association" "private_route_table_assoc_2" {
subnet_id = aws_subnet.my_private_subnet_2.id
route_table_id = aws_route_table.private_route_table.id
}

resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Allow inbound traffic on port 80 from all sources"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "alb" {
  name               = "example-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}

resource "aws_lb_target_group" "tg" {
  name     = "ALB-TG"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.my_vpc.id
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}


resource "aws_vpc_endpoint" "ssm" {
  vpc_id       = aws_vpc.my_vpc.id
  service_name = "com.amazonaws.us-east-2.ssm"
  subnet_ids   = [aws_subnet.private_1.id, aws_subnet.private_2.id]
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id       = aws_vpc.my_vpc.id
  service_name = "com.amazonaws.us-east-2.ssmmessages"
  subnet_ids   = [aws_subnet.private_1.id, aws_subnet.private_2.id]
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id       = aws_vpc.my_vpc.id
  service_name = "com.amazonaws.us-east-2.ec2messages"
  subnet_ids   = [aws_subnet.private_1.id, aws_subnet.private_2.id]
}

# S3 Bucket for CodePipeline Artifacts
resource "aws_s3_bucket" "artifacts" {
  bucket = "sample-python-app-pipeline-artifacts"
  acl    = "private"

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

# IAM Role for CodePipeline
resource "aws_iam_role" "codepipeline_role" {
  name = "codepipeline_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      }
    ]
  })

  inline_policy {
    name   = "CodePipelinePolicy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:PutObject",
            "s3:ListBucket"
          ]
          Resource = "*"
        },
        {
          Effect = "Allow"
          Action = [
            "codebuild:BatchGetBuilds",
            "codebuild:StartBuild"
          ]
          Resource = "*"
        },
        {
          Effect = "Allow"
          Action = [
            "ssm:*"
          ]
          Resource = "*"
        }
      ]
    })
  }
}

# IAM Role for CodeBuild
resource "aws_iam_role" "codebuild_role" {
  name = "codebuild_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })

  inline_policy {
    name   = "CodeBuildPolicy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "logs:*",
            "cloudwatch:*",
            "s3:GetObject",
            "s3:PutObject",
            "ssm:*"
          ]
          Resource = "*"
        }
      ]
    })
  }
}

# IAM Role for CodeDeploy
resource "aws_iam_role" "codedeploy_role" {
  name = "codedeploy_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codedeploy.amazonaws.com"
        }
      }
    ]
  })

  inline_policy {
    name   = "CodeDeployPolicy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "autoscaling:*",
            "ec2:Describe*",
            "ssm:*"
          ]
          Resource = "*"
        }
      ]
    })
  }
}

# CodeBuild Project
resource "aws_codebuild_project" "sample_project" {
  name          = "sample-python-app-build"
  description   = "Build project for sample-python-app"
  build_timeout = "5"
  service_role  = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:5.0"
    type                        = "LINUX_CONTAINER"
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = <<-EOF
    version: 0.2

    phases:
      install:
        commands:
          - echo Installing dependencies...
          - pip install -r requirements.txt
      build:
        commands:
          - echo Building the Python application...
          - python setup.py install
    artifacts:
      files:
        - '**/*'
    EOF
  }
}

# CodePipeline
resource "aws_codepipeline" "github_pipeline" {
  name     = "sample-python-app-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    type     = "S3"
    location = aws_s3_bucket.artifacts.bucket
  }

  stage {
    name = "Source"
    action {
      name             = "GitHub_Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        Owner      = "Dineesh-reddy"
        Repo       = "sample-python-app"
        Branch     = "main"
        OAuthToken = var.github_oauth_token
      }
    }
  }

  stage {
    name = "Build"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"
      configuration    = {
        ProjectName = aws_codebuild_project.sample_project.name
      }
    }
  }

  stage {
    name = "Deploy"
    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      input_artifacts = ["build_output"]
      version         = "1"
      configuration   = {
        ApplicationName     = aws_codedeploy_app.sample_app.name
        DeploymentGroupName = aws_codedeploy_deployment_group.sample_app_group.name
      }
    }
  }
}

# CodeDeploy Application and Deployment Group
resource "aws_codedeploy_app" "sample_app" {
  name = "sample-python-app-deploy"
}

resource "aws_codedeploy_deployment_group" "sample_app_group" {
  app_name              = aws_codedeploy_app.sample_app.name
  deployment_group_name = "sample-python-app-deployment-group"

  service_role_arn = aws_iam_role.codedeploy_role.arn

  deployment_style {
    deployment_option = "WITHOUT_TRAFFIC_CONTROL"
    deployment_type   = "IN_PLACE"
  }

  ec2_tag_set {
    ec2_tag_filter {
      key   = "Name"
      type  = "KEY_AND_VALUE"
      value = "SampleAppServer"
    }
  }

  load_balancer_info {
    elb_info {
      name = aws_lb.app_lb.name
    }
  }

  autoscaling_groups = []
}

variable "github_oauth_token" {
  description = "GitHub OAuth token with permissions to access the repository"
  type        = string
}


 


