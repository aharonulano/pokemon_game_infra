# VPC and Subnets
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "pokemon-game-vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "eu-west-1a"
  tags = {
    Name = "pokemon-public-subnet"
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-west-1b"
  tags = {
    Name = "pokemon-private-subnet"
  }
}

# Internet Gateway and Route Table
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "pokemon-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = {
    Name = "pokemon-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security Groups
resource "aws_security_group" "public_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "pokemon-public-sg"
  }
}

resource "aws_security_group" "private_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "pokemon-private-sg"
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "pokemon-game-cluster"
  tags = {
    Name = "pokemon-ecs-cluster"
  }
}

# Task Definitions for ECS Services
resource "aws_ecs_task_definition" "trainer_manager" {
  family                   = "trainer-manager"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  container_definitions    = <<DEFINITION
[
  {
    "name": "trainer-manager",
    "image": "trainer-manager:latest",
    "portMappings": [
      {
        "containerPort": 8080,
        "hostPort": 8080
      }
    ]
  }
]
DEFINITION
}

resource "aws_ecs_task_definition" "pokemon_manager" {
  family                   = "pokemon-manager"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  container_definitions    = <<DEFINITION
[
  {
    "name": "pokemon-manager",
    "image": "pokemon-manager:latest",
    "portMappings": [
      {
        "containerPort": 8081,
        "hostPort": 8081
      }
    ]
  }
]
DEFINITION
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY

  tags = {
    Name = "ecs-task-execution-role"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Amazon RDS (SQL)
resource "aws_db_instance" "pokemon_rds" {
  allocated_storage      = 10
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  db_name                = "pokemon_game_db"
  username               = "pokeadmin"
  password               = "pokepassword"
  parameter_group_name   = "default.mysql8.0"
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.private_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  tags = {
    Name = "pokemon-rds"
  }
}

resource "aws_db_subnet_group" "main" {
  name       = "pokemon-db-subnet-group"
  subnet_ids = [aws_subnet.private.id, aws_subnet.public.id]
  tags = {
    Name = "pokemon-db-subnet-group"
  }
}

# Amazon MQ (ActiveMQ)
resource "aws_mq_broker" "main" {
  broker_name         = "pokemon-game-broker"
  engine_type         = "ActiveMQ"
  engine_version      = "5.17.6"
  host_instance_type  = "mq.t2.micro"
  publicly_accessible = false
  security_groups     = [aws_security_group.private_sg.id]
  subnet_ids          = [aws_subnet.private.id]

  user {
    username = "mqadmin"
    password = "mqsecurepassword"
  }

  tags = {
    Name = "pokemon-mq"
  }
}

# CI/CD with GitHub Actions
resource "aws_s3_bucket" "ci_cd_artifacts" {
  bucket = "pokemon-ci-cd-artifacts"

  tags = {
    Name = "pokemon-ci-cd-artifacts"
  }
}

resource "aws_s3_bucket_ownership_controls" "something" {
  bucket = aws_s3_bucket.ci_cd_artifacts.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "ci_cd_acl" {
  bucket = aws_s3_bucket.ci_cd_artifacts.id
  acl    = "private"

  depends_on = [aws_s3_bucket_ownership_controls.something]
}

resource "aws_iam_role" "github_actions_role" {
  name = "GitHubActionsRole"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "sts.amazonaws.com"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "github-actions"
        }
      }
    }
  ]
}
POLICY

  tags = {
    Name = "GitHubActionsRole"
  }
}

resource "aws_iam_role_policy" "github_actions_policy" {
  role = aws_iam_role.github_actions_role.id

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket",
        "ecs:UpdateService",
        "ecs:DescribeServices",
        "ecs:DescribeTaskDefinition",
        "route53:*",
        "cloudfront:*"
      ],
      "Resource": "*"
    }
  ]
}
POLICY
}

# Cognito User Pool
resource "aws_cognito_user_pool" "pokemon_users" {
  name = "pokemon-user-pool"

  password_policy {
    minimum_length    = 8
    require_numbers   = true
    require_lowercase = true
    require_uppercase = true
    require_symbols   = true
  }

  tags = {
    Name = "pokemon-cognito-user-pool"
  }
}

resource "aws_cognito_user_pool_client" "pokemon_user_pool_client" {
  name         = "pokemon-user-pool-client"
  user_pool_id = aws_cognito_user_pool.pokemon_users.id

  explicit_auth_flows = ["ALLOW_USER_PASSWORD_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]

}

resource "aws_eip" "lb" {
  domain = "vpc"
}

# Route53 and CloudFront for Frontend
resource "aws_route53_zone" "pokemon_zone" {
  name = "pokemon-game.com"
}

resource "aws_route53_record" "dev-ns" {
  zone_id = aws_route53_zone.pokemon_zone.id
  name    = "www.pokemon-game.com"
  type    = "A"
  ttl     = "300"
  records = [aws_eip.lb.public_ip]
}

# resource "aws_cloudwatch_log_group" "event_sec" {
#   name = "scale"
#
#   tags = {
#     Apllication = "ecs"
#   }
# }
#


locals {
  s3_origin_id = "myS3Origin"
}

# resource "aws_cloudfront_distribution" "pokemon_cdn" {
#   origin {
#     domain_name = aws_s3_bucket.ci_cd_artifacts.bucket_regional_domain_name
#     origin_id   = "pokemon-cdn-origin"
#   }
#   default_cache_behavior {
#     allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
#     cached_methods   = ["GET", "HEAD"]
#     target_origin_id = local.s3_origin_id
#
#     forwarded_values {
#       query_string = false
#
#       cookies {
#         forward = "none"
#       }
#     }

#     viewer_protocol_policy = "allow-all"
#     min_ttl                = 0
#     default_ttl            = 3600
#     max_ttl                = 86400
#   }
#   restrictions {
#     geo_restriction {
#       restriction_type = "whitelist"
#       locations        = ["US", "CA", "GB", "DE"]
#     }
#   }
#   viewer_certificate {
#     cloudfront_default_certificate = true
#   }
#   enabled = true
# }
