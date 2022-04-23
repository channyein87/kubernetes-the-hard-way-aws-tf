resource "tls_private_key" "key" {
  algorithm = "RSA"
}

resource "tls_self_signed_cert" "cert" {
  key_algorithm   = "RSA"
  private_key_pem = tls_private_key.key.private_key_pem

  subject {
    common_name  = "echoserver.${var.zone_name}"
    organization = "Kubernetes The Hard Way"
  }

  validity_period_hours = 8766

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "aws_acm_certificate" "cert" {
  private_key      = tls_private_key.key.private_key_pem
  certificate_body = tls_self_signed_cert.cert.cert_pem
}
