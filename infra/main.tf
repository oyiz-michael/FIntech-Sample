provider "aws" {
  region = var.aws_region
}

module "jenkins" {
  source   = "./modules/jenkins"
  key_name = var.aws_key_pair
  subnet_id = aws_default_subnet.default.id
  jenkins_ami_id = var.jenkins_ami_id
}

module "nexus" {
  source   = "./modules/nexus"
  key_name = var.aws_key_pair
  subnet_id = aws_default_subnet.default.id
  nexus_ami_id = var.nexus_ami_id
}


resource "aws_default_vpc" "default" {}

resource "aws_default_subnet" "default" {
  availability_zone = "us-east-1a"
  }

resource "aws_instance" "ansible_control_machine" {
  ami           = "ami-0aa2b7722dc1b5612"
  instance_type = "t2.micro"
  key_name      = var.aws_key_pair
  subnet_id     = aws_default_subnet.default.id

  vpc_security_group_ids = [aws_security_group.ansible_sg.id]

  tags = {
    Name = "AnsibleControlMachine"
  }
}

resource "aws_security_group" "ansible_sg" {
  name        = "ansible_sg"
  description = "Security group for Ansible control machine"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#ansible configuration on server
resource "null_resource" "ansible_provisioner" {
  provisioner "remote-exec" {
    connection {
    type     = "ssh"
    user     = "ubuntu"
    private_key = "${file("~/downloads/jenkins_nexus.pem")}"
    host     = "${aws_instance.ansible_control_machine.public_ip}"
    }
    inline = [
      "echo 'Provisioning with Ansible...'",
      "sudo apt-get update",
      "echo deb http://ppa.launchpad.net/ansible/ansible/ubuntu focal main > /etc/apt/sources.list.d/ansible.list",
      "sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 93C4A3FD7BB9C367",
      "sudo apt update",
      "sudo apt install ansible -y",
      "mkdir -p /home/ubuntu/.ssh",
      "chmod 700 /home/ubuntu/.ssh",
      "touch /home/ubuntu/.ssh/authorized_keys",
      "chmod 600 /home/ubuntu/.ssh/authorized_keys",
      "cat >> /home/ubuntu/.ssh/authorized_keys << EOF",
      "${file("/Users/michelle/downloads/jenkins_nexus.pem")}",
      "EOF",
      "sudo ansible-playbook -i /Users/michelle/FinTech-sample/infra/jenkins_playbook.yml/inventory.ini /Users/michelle/FinTech-sample/infra/jenkins_playbook.yml/jenkins_playbook.yml",
      "sudo ansible-playbook -i /Users/michelle/FinTech-sample/infra/jenkins_playbook.yml/inventory.ini /Users/michelle/FinTech-sample/infra/jenkins_playbook.yml/nexus_playbook.yml"
    ]
  }
  
  depends_on = [aws_instance.ansible_control_machine]
}

