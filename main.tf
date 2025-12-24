# Using default VPC for networking. Inorder to refer to it's parameters, we use the data source below
data "aws_vpc" "default" {
  default = true
}
# Fetching default subnet IDs to launch resources in default VPC
data "aws_subnets" "default" {    
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]      # Filters subnets based on default VPC ID
  }
}
# --- 2. Security Groups ---

# Security Group for EC2 (Web Server)
resource "aws_security_group" "web_sg" {
  name        = "web-server-sg"
  description = "Allow HTTP and SSH"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # In production, we restrict this to our IP
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0 # all ports allowed
    to_port     = 0
    protocol    = "-1" # all protocols (TCP, UDP, ICMP, etc.) allowed
    cidr_blocks = ["0.0.0.0/0"] # Allow  outbound traffic to all IPv4 addresses
  }
}

# Security Group for RDS (Database)
resource "aws_security_group" "db_sg" {
  name        = "mysql-prod-db-sg"
  description = "Allow MySQL from Web SG only"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "MySQL access from EC2"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id] # SG-to-SG rule
  }
}

# --- 3. RDS Instance (MySQL) ---

resource "aws_db_instance" "default" {
  allocated_storage      = 10
  db_name                = var.db_name
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  username               = var.db_username
  password               = var.rds_password
  parameter_group_name   = "default.mysql8.0"
  skip_final_snapshot    = true
  publicly_accessible    = false
  vpc_security_group_ids = [aws_security_group.db_sg.id]
}

#--- 4. Launch template for EC2 instance ---

resource "aws_launch_template" "web_config" {
  name_prefix   = "web-server-lt"
  image_id      = "ami-02b8269d5e85954ef"  # Ubuntu ap-south-1 ✅
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.web_sg.id]

  user_data = base64encode(templatefile("${path.module}/userdata.sh", {
    rds_endpoint = aws_db_instance.default.endpoint
    db_username  = var.db_username
    db_password  = var.rds_password
    db_name      = var.db_name
  }))
}

#---5. Application load balancer ---
resource "aws_lb" "web_lb" {
  name               = "web-app-lb"
  internal           = false #internet-facing; clients on the internet can reach it. If true, it would be internal-only, usable inside the VPC.

  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_sg.id]
  subnets            = data.aws_subnets.default.ids
}

resource "aws_lb_target_group" "web_tg" {
  name     = "web-app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/index.php"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
  }
}


resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.web_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

# --- 6. Auto Scaling Group ---

resource "aws_autoscaling_group" "web_asg" {
  desired_capacity    = var.desired_capacity
  max_size            = var.max_size
  min_size            = var.min_size
  vpc_zone_identifier = data.aws_subnets.default.ids
  target_group_arns   = [aws_lb_target_group.web_tg.arn]

  launch_template {
    id      = aws_launch_template.web_config.id
    version = "$Latest"
  }

  health_check_type         = "ELB"
  health_check_grace_period = 90
}