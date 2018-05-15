# VARIABLES

variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "private_key_path" {}
variable "key_name" {
  default = "aws_rediff"
}
variable "network_address_space" {
  default = "10.1.0.0/16"
}
variable "subnet1_address_space" {
  default = "10.1.0.0/24"
}
variable "subnet2_address_space" {
  default = "10.1.1.0/24"
}

# PROVIDERS

provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "us-east-1"
}

# Gather Zone DATA

data "aws_availability_zones" "available" {}

# NETWORKING - creating in HA config across 2 Zones#

resource "aws_vpc" "vpc" {
  cidr_block = "${var.network_address_space}"
  enable_dns_hostnames = "true"

}

# Though not mentioned, i took the liberty of creating IGW

resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.vpc.id}"

}

resource "aws_subnet" "subnet1" {
  cidr_block        = "${var.subnet1_address_space}"
  vpc_id            = "${aws_vpc.vpc.id}"
  map_public_ip_on_launch = "true"
  availability_zone = "${data.aws_availability_zones.available.names[0]}"

}

resource "aws_subnet" "subnet2" {
  cidr_block        = "${var.subnet2_address_space}"
  vpc_id            = "${aws_vpc.vpc.id}"
  map_public_ip_on_launch = "true"
  availability_zone = "${data.aws_availability_zones.available.names[1]}"

}

# ROUTING #
resource "aws_route_table" "rtb" {
  vpc_id = "${aws_vpc.vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.igw.id}"
  }
}

resource "aws_route_table_association" "rta-subnet1" {
  subnet_id      = "${aws_subnet.subnet1.id}"
  route_table_id = "${aws_route_table.rtb.id}"
}

resource "aws_route_table_association" "rta-subnet2" {
  subnet_id      = "${aws_subnet.subnet2.id}"
  route_table_id = "${aws_route_table.rtb.id}"
}

# SECURITY GROUPS

resource "aws_security_group" "elb-sg" {
  name        = "nginx_elb_sg"
  vpc_id      = "${aws_vpc.vpc.id}"

  #Allow HTTPS from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Nginx security group 
resource "aws_security_group" "nginx-sg" {
  name        = "nginx_sg"
  vpc_id      = "${aws_vpc.vpc.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.network_address_space}"]
  }

  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["${var.network_address_space}"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# LOAD BALANCER #
resource "aws_elb" "web" {
  name = "nginx-elb"

  subnets         = ["${aws_subnet.subnet1.id}", "${aws_subnet.subnet2.id}"]
  security_groups = ["${aws_security_group.elb-sg.id}"]
  instances       = ["${aws_instance.nginx1.id}", "${aws_instance.nginx2.id}"]

# Assuming that a certificate is alredy uploaded for a domain to IAM or created via ACM

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 3
    target              = "HTTP:80/"
    interval            = 30
  }
}

# INSTANCES
resource "aws_instance" "nginx1" {
  ami           = "ami-467ca739"
  instance_type = "t2.micro"
  subnet_id     = "${aws_subnet.subnet1.id}"
  vpc_security_group_ids = ["${aws_security_group.nginx-sg.id}"]
  key_name        = "${var.key_name}"

  connection {
    user        = "ec2-user"
    private_key = "${file(var.private_key_path)}"
  }

provisioner "remote-exec" {
    inline = [
      "sudo yum install nginx -y",
      "sudo service nginx start",
      "echo '<html><head><title>Nginx Server is up</title></head><body style=\"background-color:#1F778D\"><p style=\"text-align: center;\"><span style=\"color:#FFFFFF;\"><span style=\"font-size:28px;\">Nginx is up & running on the instance ${aws_instance.nginx1.id}!</span></span></p></body></html>' | sudo tee /usr/share/nginx/html/index.html"
    ]
  }
}
resource "aws_instance" "nginx2" {
  ami           = "ami-467ca739"
  instance_type = "t2.micro"
  subnet_id     = "${aws_subnet.subnet2.id}"
  vpc_security_group_ids = ["${aws_security_group.nginx-sg.id}"]
  key_name        = "${var.key_name}"

  connection {
    user        = "ec2-user"
    private_key = "${file(var.private_key_path)}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install nginx -y",
      "sudo service nginx start",
      "echo '<html><head><title>Nginx Server is up</title></head><body style=\"background-color:#1F778D\"><p style=\"text-align: center;\"><span style=\"color:#FFFFFF;\"><span style=\"font-size:28px;\">Nginx is up & running on the instance ${aws_instance.nginx2.id}!</span></span></p></body></html>' | sudo tee /usr/share/nginx/html/index.html"
    ]
  }
}

# OUTPUT

output "aws_elb_public_dns" {
    value = "${aws_elb.web.dns_name}"
}
