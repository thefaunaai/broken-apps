resource "aws_security_group" "alb" {
  name        = "${local.name}-alb"
  description = "Gatehouse HTTPS load balancer"
  vpc_id      = data.aws_vpc.default.id

  tags = {
    Name = "${local.name}-alb"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allowed_https" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = var.allowed_ingress_cidr
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "HTTPS from allowed source IP"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_gatehouse" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = aws_security_group.gatehouse.id
  from_port                    = 3000
  to_port                      = 3000
  ip_protocol                  = "tcp"
  description                  = "Gatehouse target traffic"
}

resource "aws_lb" "gatehouse" {
  name               = local.name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = slice(sort(data.aws_subnets.default.ids), 0, min(2, length(data.aws_subnets.default.ids)))

  tags = {
    Name = local.name
  }

  lifecycle {
    precondition {
      condition     = length(data.aws_subnets.default.ids) >= 2
      error_message = "Gatehouse requires default public subnets in at least two Availability Zones for the ALB."
    }
  }
}

resource "aws_lb_target_group" "gatehouse" {
  name     = "${local.name}-web"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  deregistration_delay = 10

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 15
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${local.name}-web"
  }
}

resource "aws_lb_target_group_attachment" "gatehouse" {
  target_group_arn = aws_lb_target_group.gatehouse.arn
  target_id        = aws_instance.gatehouse.id
  port             = 3000
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.gatehouse.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.gatehouse.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gatehouse.arn
  }
}
