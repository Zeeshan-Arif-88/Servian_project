

# Setting a variable for the AWS access key.
variable "access-key" {

  description = "The access key of the AWS account."
  type = string
}


# Setting a variable for the AWS secret key.
variable "secret-key" {

  description = "The secret key of the AWS account."
  type = string
}
provider "aws" {
    
    # Paste your aws region below.
    region = "ap-southeast-2"
    
    access_key = var.access-key
    
    secret_key = var.secret-key
  
}

# The aws VPC details are as below.
resource "aws_vpc" "project-vpc" {
    cidr_block = "10.0.0.0/16"
    tags = {
      "Name" = "project-vpc"
    }
  
}

# The aws internet gateway settings are as below.
resource "aws_internet_gateway" "project-gateway" {
    vpc_id = aws_vpc.project-vpc.id

  
}

# The aws route table details are as below. Re-route all traffic to the default VPC gateway.
resource "aws_route_table" "project-route-table" {
  
  vpc_id = aws_vpc.project-vpc.id
  # Route all IPV4 traffic to default VPC gateway.
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.project-gateway.id
  }

  # Route all IPV6 traffic to default gateway.
  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.project-gateway.id
  }

  tags = {
    "Name" = "project-route-table"
  }


}

# The aws VPC subnet details are as below.
resource "aws_subnet" "project-subnet" {
    vpc_id = aws_vpc.project-vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "ap-southeast-2a"
    tags = {
      "Name" = "project-subnet"
    }
  
}

# Associate subnet with route table.
resource "aws_route_table_association" "project-route-table-association" {
    subnet_id = aws_subnet.project-subnet.id
    route_table_id = aws_route_table.project-route-table.id
  
}

# The aws security group below allows traffic through ports 22 (SSH), 80 (HTTP) & 443 (HTTPS).
resource "aws_security_group" "project-security-group" {
  name = "project-security-group"
  description = "Security group for allowing network traffic on ports 22, 80 & 443."

  vpc_id = aws_vpc.project-vpc.id

  # Inbound rule for HTTPS traffic.
  ingress {
    description      = "HTTPS inbound traffic"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  
  # Inbound rule for HTTP traffic.
  ingress {
    description      = "HTTP inbound traffic"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  # Inbound rule for SSH traffic.
  ingress {
    description      = "SSH inbound traffic"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  # Outbound rule for all traffic.
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    "Name" = "project-security-group"
  }
}

# Create aws network interface with IP from subnet.
resource "aws_network_interface" "project-network-interface" {

  subnet_id = aws_subnet.project-subnet.id
  
  # The private IP of the host is 10.0.1.50.
  private_ips = [ "10.0.1.50" ]
  security_groups = [aws_security_group.project-security-group.id]
  
}

# Assign an elastic IP to the instance.
resource "aws_eip" "project-elastic-ip" {

  # Elastic IP is part of my VPC.
  vpc = true

  network_interface = aws_network_interface.project-network-interface.id
  
  # Elastic IP assigned to instance is 10.0.1.50.
  associate_with_private_ip = "10.0.1.50"
  
  # NOTE: Elastic IP needs to be created AFTER creating internet gateway.
  #       because a public IP needs to have agateway first.
  #       This creates a dependency of the elastic IP on the gateway.

  depends_on = [
    aws_internet_gateway.project-gateway
  ]
}

# The aws ec2 instance details are as below.
resource "aws_instance" "project-server" {

    ami = "ami-0567f647e75c7bc05"
    instance_type = "t2.micro"

    # Instance avialablity zone must be the same as the subnet's availablity zone.
    availability_zone = "ap-southeast-2a"

    key_name = "project-key"

    network_interface {
      
      device_index = 0

      network_interface_id = aws_network_interface.project-network-interface.id

    }
    tags = {
        Name = "project-server"
    }
  
}
