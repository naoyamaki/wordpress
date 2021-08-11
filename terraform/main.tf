data "aws_caller_identity" "self" {}
variable "db_endpoint" {}
variable "db_password" {}

provider "aws" {
  region = "ap-northeast-1"
}

# VPC/network
resource "aws_vpc" "wordpress_vpc" {
  cidr_block           = "10.1.0.0/16"
  instance_tenancy     = "default"
  enable_dns_support   = "true"
  enable_dns_hostnames = "true"
  tags = {
    Name = "wordpress_vpc"
  }
}
resource "aws_internet_gateway" "wordpress_igw" {
  vpc_id = aws_vpc.wordpress_vpc.id
}

resource "aws_subnet" "public-a" {
  vpc_id            = aws_vpc.wordpress_vpc.id
  cidr_block        = "10.1.1.0/24"
  availability_zone = "ap-northeast-1a"
  tags = {
    Name = "wordpress_pubsub_1a"
  }
}
resource "aws_subnet" "public-c" {
  vpc_id            = aws_vpc.wordpress_vpc.id
  cidr_block        = "10.1.2.0/24"
  availability_zone = "ap-northeast-1c"
  tags = {
    Name = "wordpress_pubsub_1c"
  }
}
resource "aws_subnet" "private-a" {
  vpc_id            = aws_vpc.wordpress_vpc.id
  cidr_block        = "10.1.128.0/24"
  availability_zone = "ap-northeast-1a"
  tags = {
    Name = "wordpress_pvtsub_1a"
  }
}
resource "aws_subnet" "private-c" {
  vpc_id            = aws_vpc.wordpress_vpc.id
  cidr_block        = "10.1.129.0/24"
  availability_zone = "ap-northeast-1c"
  tags = {
    Name = "wordpress_pvtsub_1c"
  }
}

resource "aws_route_table" "public-route" {
  vpc_id = aws_vpc.wordpress_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.wordpress_igw.id
  }
}
resource "aws_route_table" "private-route" {
  vpc_id = aws_vpc.wordpress_vpc.id
}

resource "aws_route_table_association" "puclic-a" {
  subnet_id      = aws_subnet.public-a.id
  route_table_id = aws_route_table.public-route.id
}
resource "aws_route_table_association" "puclic-c" {
  subnet_id      = aws_subnet.public-c.id
  route_table_id = aws_route_table.public-route.id
}

# security group
resource "aws_security_group" "wordpress-alb-sg" {
  name   = "wordpress-alb-sg"
  vpc_id = aws_vpc.wordpress_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "open"
  }
}
resource "aws_security_group" "wordpress-service-sg" {
  name   = "wordpress-service-sg"
  vpc_id = aws_vpc.wordpress_vpc.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = ["${aws_security_group.wordpress-alb-sg.id}"]
  }
}
resource "aws_security_group" "wordpress-efs-sg" {
  name   = "wordpress-efs-sg"
  vpc_id = aws_vpc.wordpress_vpc.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = ["${aws_security_group.wordpress-service-sg.id}"]
  }
}
resource "aws_security_group" "wordpress-rds-sg" {
  name   = "wordpress-rds-sg"
  vpc_id = aws_vpc.wordpress_vpc.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = ["${aws_security_group.wordpress-service-sg.id}"]
  }
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["122.208.209.60/32", "133.201.32.128/32"]
  }
}

# ALB
resource "aws_lb_target_group" "wordpress-tgg" {
  deregistration_delay = "300"

  health_check {
    enabled             = "true"
    healthy_threshold   = "5"
    interval            = "30"
    matcher             = "200"
    path                = "/healthcheck/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = "5"
    unhealthy_threshold = "2"
  }

  load_balancing_algorithm_type = "round_robin"
  name                          = "wordpress-tgg"
  port                          = "80"
  protocol                      = "HTTP"
  protocol_version              = "HTTP1"
  slow_start                    = "0"

  stickiness {
    cookie_duration = "86400"
    enabled         = "false"
    type            = "lb_cookie"
  }

  target_type = "ip"
  vpc_id      = aws_vpc.wordpress_vpc.id
}
resource "aws_lb" "wordpress-alb" {
  drop_invalid_header_fields = "false"
  enable_deletion_protection = "false"
  enable_http2               = "false"
  idle_timeout               = "60"
  internal                   = "false"
  ip_address_type            = "ipv4"
  load_balancer_type         = "application"
  name                       = "wordpress-alb"
  security_groups            = ["${aws_security_group.wordpress-alb-sg.id}"]
  subnets                    = ["${aws_subnet.public-a.id}", "${aws_subnet.public-c.id}"]
}
resource "aws_lb_listener" "wordpress-alb-listner" {
  load_balancer_arn = aws_lb.wordpress-alb.arn
  port              = 443
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_lb_target_group.wordpress-tgg.arn
    type             = "forward"
  }
}

# efs
resource "aws_efs_file_system" "wordpress-efs" {
  performance_mode                = "generalPurpose"
  provisioned_throughput_in_mibps = "0"

  tags = {
    Name = "wordpress-efs"
  }
  throughput_mode = "bursting"
}
resource "aws_efs_mount_target" "wordpress-efs-tgt-1a" {
  file_system_id = aws_efs_file_system.wordpress-efs.id
  subnet_id      = aws_subnet.public-a.id
}
resource "aws_efs_mount_target" "wordpress-efs-tgt-1c" {
  file_system_id = aws_efs_file_system.wordpress-efs.id
  subnet_id      = aws_subnet.public-c.id
}

# ecs
resource "aws_ecs_task_definition" "wordpress-task-def" {
  family                   = "wordpress"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "2048"
  network_mode             = "awsvpc"

  container_definitions = jsonencode([
    {
      "command" : [],
      "cpu" : 384,
      "environment" : [
        { "name" : "DB_HOST", "value" : "${var.db_endpoint}" },
        { "name" : "DB_PASSWORD", "value" : "${var.db_password}" }
      ],
      "essential" : true,
      "healthCheck" : {
        "command" : ["CMD-SHELL", "curl -f http://localhost:9000/ || exit 0"],
        "interval" : 30,
        "retries" : 3,
        "startPeriod" : 3,
        "timeout" : 5
      },
      "image" : "${data.aws_caller_identity.self.account_id}.dkr.ecr.ap-northeast-1.amazonaws.com/wp_app:latest",
      "logConfiguration" : {
        "logDriver" : "awslogs",
        "options" : { "awslogs-group" : "/ecs/wordpress", "awslogs-region" : "ap-northeast-1", "awslogs-stream-prefix" : "ecs" }
      },
      "memoryReservation" : 1536,
      "mountPoints" : [{ "containerPath" : "/var/www/html/", "sourceVolume" : "wordpress" }],
      "name" : "app",
      "portMappings" : [{ "containerPort" : 9000, "hostPort" : 9000, "protocol" : "tcp" }],
      "volumesFrom" : []
    },
    {
      "command" : ["envsubst '$$APP_HOST' < /etc/nginx/conf.d/default.conf.template > /etc/nginx/conf.d/default.conf \u0026\u0026 nginx -g 'daemon off;'"],
      "cpu" : 128,
      "dependsOn" : [{ "condition" : "START", "containerName" : "app" }],
      "entryPoint" : ["sh", "-c"],
      "environment" : [{ "name" : "APP_HOST", "value" : "localhost" }],
      "essential" : true,
      "healthCheck" : {
        "command" : ["CMD-SHELL", "curl -f http://localhost:80/healthcheck/|| exit 1"],
        "interval" : 30,
        "retries" : 3,
        "startPeriod" : 3,
        "timeout" : 5
      },
      "image" : "${data.aws_caller_identity.self.account_id}.dkr.ecr.ap-northeast-1.amazonaws.com/wp_web:latest",
      "links" : [],
      "logConfiguration" : {
        "logDriver" : "awslogs",
        "options" : {
          "awslogs-group" : "/ecs/wordpress",
          "awslogs-region" : "ap-northeast-1",
          "awslogs-stream-prefix" : "ecs"
        }
      },
      "memoryReservation" : 512,
      "mountPoints" : [{ "containerPath" : "/var/www/html/", "sourceVolume" : "wordpress" }],
      "name" : "web",
      "portMappings" : [{ "containerPort" : 80, "hostPort" : 80, "protocol" : "tcp" }],
      "volumesFrom" : []
    }
  ])

  volume {
    efs_volume_configuration {
      authorization_config {
        iam = "DISABLED"
      }

      file_system_id          = aws_efs_file_system.wordpress-efs.id
      root_directory          = "/"
      transit_encryption      = "DISABLED"
      transit_encryption_port = "0"
    }

    name = "wordpress"
  }
}
resource "aws_ecs_cluster" "wordpress-cluster" {
  capacity_providers = ["FARGATE_SPOT", "FARGATE"]
  name               = "wordpress"

  setting {
    name  = "containerInsights"
    value = "disabled"
  }
}
resource "aws_ecs_service" "wordpress-service" {
  cluster                            = "wordpress"
  name                               = "wordpress"
  platform_version                   = "1.4.0"
  scheduling_strategy                = "REPLICA"
  deployment_maximum_percent         = "200"
  deployment_minimum_healthy_percent = "100"
  desired_count                      = "2"
  enable_ecs_managed_tags            = "true"
  enable_execute_command             = "true"
  health_check_grace_period_seconds  = "30"
  launch_type                        = "FARGATE"
  task_definition                    = aws_ecs_task_definition.wordpress-task-def.arn

  load_balancer {
    container_name   = "web"
    container_port   = "80"
    target_group_arn = aws_lb_target_group.wordpress-tgg.arn
  }
  network_configuration {
    assign_public_ip = "true"
    security_groups  = ["${aws_security_group.wordpress-service-sg.id}"]
    subnets          = ["${aws_subnet.public-a.id}", "${aws_subnet.public-c.id}"]
  }
}
