

resource "tls_private_key" "webssh" {
  algorithm = "RSA"
}

resource "aws_key_pair" "webssh" {
  public_key = tls_private_key.webssh.public_key_openssh
}

resource "null_resource" "webkey" {
  provisioner "local-exec" {
    command = "echo \"${tls_private_key.webssh.private_key_pem}\" > ${aws_key_pair.webssh.key_name}.pem"
  }

  provisioner "local-exec" {
    command = "chmod 600 *.pem"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -f *.pem"
  }

}
