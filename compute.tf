data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"]
}

resource "aws_key_pair" "keypair" {
  key_name   = "kubernetes-the-hard-way-key"
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "aws_instance" "controllers" {
  count                  = var.controller_count
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.keypair.key_name
  vpc_security_group_ids = [aws_security_group.external.id]
  source_dest_check      = false
  subnet_id              = element(tolist(data.aws_subnet_ids.public_subnet_ids.ids), count.index)
  iam_instance_profile   = aws_iam_instance_profile.profile.name
  tags = {
    "Name"                                          = join("-", ["controller", count.index])
    "Role"                                          = "controller"
    "kubernetes.io/cluster/kubernetes-the-hard-way" = "owned"
  }
  depends_on = [aws_iam_instance_profile.profile]
}

resource "aws_instance" "workers" {
  count                  = var.worker_count
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.keypair.key_name
  vpc_security_group_ids = [aws_security_group.internal.id]
  source_dest_check      = false
  subnet_id              = element(tolist(data.aws_subnet_ids.private_subnet_ids.ids), count.index)
  iam_instance_profile   = aws_iam_instance_profile.profile.name
  tags = {
    "Name"                                          = join("-", ["worker", count.index])
    "Role"                                          = "worker"
    "kubernetes.io/cluster/kubernetes-the-hard-way" = "owned"
    "pod-cidr"                                      = join("", ["10.200.", count.index, ".0/24"])
  }
  depends_on = [aws_iam_instance_profile.profile]
}

resource "aws_iam_role" "role" {
  name = "kubernetes-the-hard-way-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_instance_profile" "profile" {
  name = "kubernetes-the-hard-way-ec2-role"
  role = aws_iam_role.role.name
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_policy" "policy" {
  name        = "kubernetes-the-hard-way-ec2-policy"
  path        = "/"
  description = "kubernetes-the-hard-way-ec2-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:*",
          "elasticloadbalancing:*",
          "ecr:*",
          "autoscaling:*",
          "iam:CreateServiceLinkedRole",
          "kms:DescribeKey"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2" {
  role       = aws_iam_role.role.name
  policy_arn = aws_iam_policy.policy.arn
}

resource "aws_eip" "eip" {
  count = var.controller_count <= length(tolist(data.aws_subnet_ids.public_subnet_ids.ids)) ? var.controller_count : length(tolist(data.aws_subnet_ids.public_subnet_ids.ids))
}

locals {
  nlb_subnets = zipmap(aws_instance.controllers[*].subnet_id, aws_eip.eip[*].id)
}

resource "aws_lb" "nlb" {
  name               = "kubernetes-the-hard-way-nlb"
  internal           = false
  load_balancer_type = "network"
  dynamic "subnet_mapping" {
    for_each = local.nlb_subnets
    content {
      subnet_id     = subnet_mapping.key
      allocation_id = subnet_mapping.value
    }
  }
}

resource "aws_lb_target_group" "tg" {
  name                 = "kubernetes-the-hard-way-tg"
  port                 = 6443
  protocol             = "TCP"
  target_type          = "instance"
  deregistration_delay = 60
  vpc_id               = var.vpc_id
  health_check {
    protocol            = "HTTP"
    port                = "80"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 10
    path                = "/healthz"
  }
}

resource "aws_lb_target_group_attachment" "tg_attach" {
  count            = var.controller_count
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.controllers[count.index].id
  port             = 6443
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = 443
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

output "controller_pip" {
  value = {
    for instance in aws_instance.controllers :
    instance.id => {
      public-ip  = instance.public_ip
      private-ip = instance.private_ip
      Name       = lookup(instance.tags, "Name")
      hostname   = instance.private_dns
    }
  }
}

output "worker_ip" {
  value = {
    for instance in aws_instance.workers :
    instance.id => {
      private-ip = instance.private_ip
      Name       = lookup(instance.tags, "Name")
      hostname   = instance.private_dns
    }
  }
}

output "nlb_dns" {
  value = aws_lb.nlb.dns_name
}
