provider "aws" {
  region = "eu-north-1"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_instance" "web_servers" {
  count         = 2
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  key_name      = "exam-key"

  tags = {
    Name = "Ansible-Target-${count.index + 1}"
  }

  provisioner "remote-exec" {
    inline = ["echo 'Server is ready!'"]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/exam-key.pem")
      host        = self.public_ip
    }
  }
}

resource "null_resource" "ansible_provisioner" {
  depends_on = [aws_instance.web_servers]

  provisioner "local-exec" {
    command = <<EOT
      echo "[webservers]" > inventory.ini
      for ip in ${join(" ", aws_instance.web_servers[*].public_ip)}; do
        echo "$ip ansible_user=ubuntu ansible_ssh_private_key_file=./exam-key.pem ansible_ssh_common_args='-o StrictHostKeyChecking=no'" >> inventory.ini
      done
      ansible-playbook -i inventory.ini playbook.yml
    EOT
  }
}
