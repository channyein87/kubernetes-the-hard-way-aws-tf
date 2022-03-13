resource "null_resource" "tls_certs" {
  provisioner "local-exec" {
    command = "sh config/01_tlscerts.sh -c 2 -w 2"
  }

  depends_on = [
    aws_lb.nlb
  ]
}

resource "null_resource" "kubeconfigs" {
  provisioner "local-exec" {
    command = "sh config/02_kubeconfigs.sh -c 2 -w 2"
  }

  depends_on = [
    null_resource.tls_certs
  ]
}

resource "null_resource" "bootstrap" {
  provisioner "local-exec" {
    command = "sh config/03_bootstrap.sh -c 2 -w 2"
  }

  depends_on = [
    null_resource.kubeconfigs
  ]
}

resource "null_resource" "dns" {
  provisioner "local-exec" {
    command = "sh config/04_dns.sh -c 2 -w 2"
  }

  depends_on = [
    null_resource.bootstrap
  ]
}

resource "null_resource" "cleanup" {
  provisioner "local-exec" {
    when    = destroy
    command = "sh config/99_cleanup.sh -c 2 -w 2"
  }
}
