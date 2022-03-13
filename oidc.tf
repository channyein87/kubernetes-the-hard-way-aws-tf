data "tls_certificate" "oidc" {
  url          = "https://${aws_lb.nlb.dns_name}"
  verify_chain = false

  depends_on = [
    null_resource.dns
  ]
}

resource "aws_iam_openid_connect_provider" "oidc" {
  url             = "https://${aws_lb.nlb.dns_name}"
  client_id_list  = ["kubernetes-the-hard-way"]
  thumbprint_list = ["${data.tls_certificate.oidc.certificates.0.sha1_fingerprint}"]
}

resource "aws_iam_role" "oidc" {
  name = "kubernetes-the-hard-way-pod-role"

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

  managed_policy_arns = ["arn:aws:iam::aws:policy/job-function/ViewOnlyAccess"]
}

output "oidc_arn" {
  value = aws_iam_openid_connect_provider.oidc.arn
}
