data "aws_vpc" "vpc" {
  id = var.vpc_id
}

data "aws_subnet_ids" "public_subnet_ids" {
  vpc_id = var.vpc_id
  filter {
    name   = "tag:Name"
    values = ["*public*"]
  }
}

data "aws_subnet_ids" "private_subnet_ids" {
  vpc_id = var.vpc_id
  filter {
    name   = "tag:Name"
    values = ["*private*"]
  }
}

data "aws_subnet" "public_subnets" {
  for_each = data.aws_subnet_ids.public_subnet_ids.ids
  id       = each.value
}

data "aws_subnet" "private_subnets" {
  for_each = data.aws_subnet_ids.private_subnet_ids.ids
  id       = each.value
}

data "aws_route_table" "public_rt" {
  subnet_id = element(tolist(data.aws_subnet_ids.public_subnet_ids.ids), 0)
}

data "aws_route_table" "private_rt" {
  subnet_id = element(tolist(data.aws_subnet_ids.private_subnet_ids.ids), 0)
}

resource "aws_security_group" "external" {
  name        = "kubernetes-the-hard-way-allow-external"
  description = "kubernetes-the-hard-way-allow-external"
  vpc_id      = var.vpc_id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "kubernetes.io/cluster/kubernetes-the-hard-way" = "owned"
  }
}

resource "aws_security_group" "internal" {
  name        = "kubernetes-the-hard-way-allow-internal"
  description = "kubernetes-the-hard-way-allow-internal"
  vpc_id      = var.vpc_id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "kubernetes.io/cluster/kubernetes-the-hard-way" = "owned"
  }
}

resource "aws_security_group_rule" "ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.external.id
}

resource "aws_security_group_rule" "http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.external.id
}

resource "aws_security_group_rule" "https" {
  type              = "ingress"
  from_port         = 6443
  to_port           = 6443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.external.id
}

resource "aws_security_group_rule" "healthz" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.external.id
}

resource "aws_security_group_rule" "icmp" {
  type              = "ingress"
  from_port         = -1
  to_port           = -1
  protocol          = "icmp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.external.id
}

resource "aws_security_group_rule" "external_self" {
  type              = "ingress"
  from_port         = -1
  to_port           = -1
  protocol          = -1
  self              = true
  security_group_id = aws_security_group.external.id
}

resource "aws_security_group_rule" "internal_self" {
  type              = "ingress"
  from_port         = -1
  to_port           = -1
  protocol          = -1
  self              = true
  security_group_id = aws_security_group.internal.id
}

resource "aws_security_group_rule" "ext_to_int" {
  type                     = "ingress"
  from_port                = -1
  to_port                  = -1
  protocol                 = -1
  source_security_group_id = aws_security_group.external.id
  security_group_id        = aws_security_group.internal.id
}

resource "aws_security_group_rule" "int_to_ext" {
  type                     = "ingress"
  from_port                = -1
  to_port                  = -1
  protocol                 = -1
  source_security_group_id = aws_security_group.internal.id
  security_group_id        = aws_security_group.external.id
}

resource "aws_route" "public_route" {
  count                  = var.worker_count
  route_table_id         = data.aws_route_table.public_rt.id
  instance_id            = aws_instance.workers[count.index].id
  destination_cidr_block = join("", ["10.200.", count.index, ".0/24"])
}

resource "aws_route" "private_route" {
  count                  = var.worker_count
  route_table_id         = data.aws_route_table.private_rt.id
  instance_id            = aws_instance.workers[count.index].id
  destination_cidr_block = join("", ["10.200.", count.index, ".0/24"])
}

/*output "public_subnets" {
  value = [for s in data.aws_subnet.public_subnets : s.cidr_block]
}

output "private_subnets" {
  value = [for s in data.aws_subnet.private_subnets : s.cidr_block]
}*/
