resource "aws_route53_zone" "zone" {
  name          = var.zone_name
  comment       = "kubernetes-the-hard-way"
  force_destroy = true

  vpc {
    vpc_id     = var.vpc_id
    vpc_region = var.aws_region
  }

  tags = {
    "Name" = var.zone_name
  }
}

resource "aws_iam_role" "externaldns" {
  name = "kubernetes-the-hard-way-externaldns-role"

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
    name = "route53-access-policy"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = "route53:GetChange"
          Resource = "arn:aws:route53:::change/*"
        },
        {
          Effect = "Allow"
          Action = [
            "route53:ChangeResourceRecordSets",
            "route53:ListResourceRecordSets"
          ]
          Resource = "arn:aws:route53:::hostedzone/*"
        },
        {
          Effect   = "Allow"
          Action   = ["route53:ListHostedZonesByName", "route53:ListHostedZones"]
          Resource = "*"
        },
      ]
    })
  }
}

output "zone_id" {
  value = aws_route53_zone.zone.zone_id
}

output "name_servers" {
  value = aws_route53_zone.zone.name_servers
}
