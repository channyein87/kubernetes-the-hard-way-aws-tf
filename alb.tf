data "http" "alb_iam_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.0/docs/install/iam_policy.json"
}

resource "aws_iam_role" "alb_addon" {
  name = "kubernetes-the-hard-way-alb-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Federated = aws_iam_openid_connect_provider.oidc.arn
        }
        Condition = {
          StringEquals = {
            "${aws_lb.nlb.dns_name}:aud" : "kubernetes-the-hard-way"
          }
        }
      },
    ]
  })

  inline_policy {
    name = "alb-access-policy"

    policy = data.http.alb_iam_policy.body
  }
}

resource "aws_ec2_tag" "public_subnet" {
  for_each = data.aws_subnet_ids.public_subnet_ids.ids

  resource_id = each.value
  key         = "kubernetes.io/role/elb"
  value       = ""
}

resource "aws_ec2_tag" "private_subnets" {
  for_each = data.aws_subnet_ids.private_subnet_ids.ids

  resource_id = each.value
  key         = "kubernetes.io/role/internal-elb"
  value       = ""
}

resource "aws_ec2_tag" "vpc" {
  resource_id = var.vpc_id
  key         = "kubernetes.io/cluster/kubernetes-the-hard-way"
  value       = "shared"
}

resource "aws_ec2_tag" "workers" {
  count = var.worker_count

  resource_id = aws_instance.workers[count.index].id
  key         = "kubernetes.io/cluster/kubernetes-the-hard-way"
  value       = "owned"
}
