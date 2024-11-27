provider "aws" {
  region = "eu-west-1"
}

variable "key_name" {
  description = "Key pair name for EC2 instances"
  default     = "Aish-key-eu"
}

# VPC Configuration
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# Subnets Configuration
resource "aws_subnet" "public" {
  vpc_id             = aws_vpc.main.id
  cidr_block         = "10.0.1.0/24"
  availability_zone  = "eu-west-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "jumpbox" {
  vpc_id             = aws_vpc.main.id
  cidr_block         = "10.0.2.0/24"
  availability_zone  = "eu-west-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private" {
  vpc_id             = aws_vpc.main.id
  cidr_block         = "10.0.3.0/24"
  availability_zone  = "eu-west-1a"
  map_public_ip_on_launch = false
}

# Internet Gateway Configuration
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

# Route Table Configuration for Public Subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public_association" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security Groups Configuration
resource "aws_security_group" "public" {
  vpc_id = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "jumpbox" {
  vpc_id = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"] # Allow SSH access from public subnet


  }
}

resource "aws_security_group" "private" {
  vpc_id = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.jumpbox.id] # Allow access only from Jumpbox SG

  }
}

# Network Interface Configuration for Public EC2 Instance
resource "aws_network_interface" "public_nic" {
  subnet_id       = aws_subnet.public.id
  security_groups = [aws_security_group.public.id]
  depends_on = [aws_security_group.public]
}

# Network Interface Configuration for Jumpbox EC2 Instance
resource "aws_network_interface" "jumpbox_nic" {
  subnet_id       = aws_subnet.jumpbox.id
  security_groups = [aws_security_group.jumpbox.id]
  depends_on = [aws_security_group.jumpbox]
}

# Network Interface Configuration for Private EC2 Instance
resource "aws_network_interface" "private_nic" {
  subnet_id       = aws_subnet.private.id
  security_groups = [aws_security_group.private.id]
  depends_on = [aws_security_group.private]
}

output "public_instance_ip" {
  value = aws_instance.public_instance.public_ip
}

output "jumpbox_instance_ip" {
  value = aws_instance.jumpbox_instance.public_ip
}

# EC2 Instances Configuration
resource "aws_instance" "public_instance" {
  ami                   = "ami-02141377eee7defb9"
  instance_type         = "t2.micro"
  key_name              = var.key_name

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.public_nic.id
  }

  tags = {
    Name = "Public EC2 Instance"
  }

  depends_on = [aws_network_interface.public_nic]
}

resource "aws_instance" "jumpbox_instance" {
  ami                   = "ami-02141377eee7defb9"
  instance_type         = "t2.micro"
  key_name              = var.key_name

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.jumpbox_nic.id
  }

  tags = {
    Name = "Jumpbox EC2 Instance"
  }

  depends_on = [aws_network_interface.jumpbox_nic]
}

resource "aws_instance" "private_instance" {
  ami                   = "ami-02141377eee7defb9"
  instance_type         = "t2.micro"
  key_name              = var.key_name

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.private_nic.id
  }

  tags = {
    Name = "Private EC2 Instance"
  }
}
