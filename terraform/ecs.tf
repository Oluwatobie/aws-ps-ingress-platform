variable "container_image_tag" {
  type    = string
  default = "latest"
}


# 1. Core ECS Compute Cluster
resource "aws_ecs_cluster" "main" {
  name = "ps-ingress-compute-cluster"
}

# 2. Centralized CloudWatch Log Group for Application Monitoring
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/ps-ingress-worker"
  retention_in_days = 7 # Keep logs for 7 days to manage storage costs cleanly
}

# 3. ECS Task EXECUTION Role (Allows AWS Fargate to pull from ECR and write to CloudWatch)
resource "aws_iam_role" "ecs_execution_role" {
  name = "ps-ingress-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_attach" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# 4. ECS TASK Role (Gives the actual Python script permissions to interact with AWS resources)
resource "aws_iam_role" "ecs_task_role" {
  name = "ps-ingress-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

# Granular IAM policy mapping for SQS least privilege access
resource "aws_iam_policy" "ecs_sqs_access" {
  name        = "ps-ingress-ecs-sqs-policy"
  description = "Allows worker container to poll and delete messages from active buffer queue"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes"
      ]
      Resource = aws_sqs_queue.ps_ingress_queue.arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_sqs_attach" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_sqs_access.arn
}

# Granular IAM policy mapping for S3 Data Lake access
resource "aws_iam_policy" "ecs_s3_access" {
  name        = "ps-ingress-ecs-s3-policy"
  description = "Allows worker container to push validated payloads into the S3 data lake bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:PutObject",
        "s3:PutObjectAcl"
      ]
      Resource = "${aws_s3_bucket.data_lake.arn}/*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_s3_attach" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_s3_access.arn
}

# 5. ECS Fargate Task Definition Layout
resource "aws_ecs_task_definition" "app" {
  family                   = "ps-ingress-worker-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256" # 0.25 vCPU (Highly cost-efficient)
  memory                   = "512" # 512 MB
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([{
    name      = "worker"
    image = "${aws_ecr_repository.app_repo.repository_url}:${var.container_image_tag}"
    essential = true
    
    environment = [
      { name = "SQS_QUEUE_URL", value = aws_sqs_queue.ps_ingress_queue.url },
      { name = "AWS_REGION", value = var.aws_region },
      { name = "DATA_LAKE_BUCKET", value = aws_s3_bucket.data_lake.id } # Feeds the data lake bucket name into Python
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "worker"
      }
    }
  }])
}

# 6. Compute Network Security Group Configuration
resource "aws_security_group" "ecs_tasks" {
  name        = "ps-ingress-ecs-tasks-sg"
  description = "Isolate container traffic within private app subnets"
  vpc_id      = aws_vpc.main.id

  # No inbound rules configured - containers are completely unreachable from outside
  
  # Outbound access allowed out to AWS endpoints/internet strictly via NAT Gateway
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 7. The ECS Fargate Continuous Running Service
resource "aws_ecs_service" "main" {
  name            = "ps-ingress-worker-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1 # Keep 1 single processing container continuously running
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [aws_security_group.ecs_tasks.id]
    subnets          = aws_subnet.private_app[*].id
    assign_public_ip = false # Enforce zero exposure public IP boundaries
  }
}