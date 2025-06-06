provider "aws" {
  region = "us-east-1"
  access_key = "YOUR_ACCESS_KEY"
  secret_key = "YOUR_SECRET_KEY"
}

# # EC2 instance resource CREATION
# resource "aws_instance" "my-first-instance" {
#   ami           = "ami-084568db4383264d4"
#   instance_type = "t2.micro"
#   tags = {
#     # Name = "ubuntu"
#   }  
# }
# resource "<provider>_<resource_type>" "name" {
#     config options.....
#     key = "value"
#     key2 = "another value"  
# }



# # VPC resource CREATION
# resource "aws_vpc" "first-vpc" {
#     cidr_block = "10.0.0.0/16"
#     tags = {
#         Name = "production-vpc"
#     }
# }

# resource "aws_subnet" "subnet-1" {
#   vpc_id     = aws_vpc.first-vpc.id
#   cidr_block = "10.0.1.0/24"

#   tags = {
#     Name = "production-subnet-1"
#   }
# }



# TERRAFORM PRACTICE PROJECT
# 1. Create VPC
resource "aws_vpc" "prod-vpc" {
    cidr_block = "10.0.0.0/16"
    tags = {
        Name = "production"
    }
}


# 2. Create Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod-vpc.id
}


# 3. Create Custom Route Table 
resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Prod"
  }
}


# 4. Create Subnet
resource "aws_subnet" "subnet-1" {
  vpc_id = aws_vpc.prod-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "prod-subnet"
  }
}


# 5. Associate Route Table with Subnet
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}


# 6. Create Security Group to allow port 22, 80, 443
resource "aws_security_group" "allow_web" {
  name = "allow_web_traffic"
  description = "Allow Web inbound traffic"
  vpc_id = aws_vpc.prod-vpc.id

  ingress {
    description = "HTTPS" 
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP" 
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH" 
    from_port   = 2
    to_port     = 2
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web"
  }  
}


# 7. Create a network interface with an ip in the subnet that was created in step 4
resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]
}


# 8. Assign an Elastic IP to the network interface created in step 7
resource "aws_eip" "one" {
  vpc = true
  network_interface = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [ aws_internet_gateway.gw ]
}


# 9. Create Ubuntu server and install/enavle apache2
resource "aws_instance" "web-server-instance" {
  ami = "ami-084568db4383264d4"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "firstkey"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.web-server-nic.id
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl enable apache2
              sudo bash -c 'echo your very first web server > /var/www/html/index.html'
              EOF
  tags = {
    Name = "web-server"
  }
}


# Terraform output variables
output "server_public_ip" {
  value = aws_eip.one.public_ip
}

output "server_private_ip" {
  value = aws_instance.web-server-instance.private_ip
}

output "server_id" {
  value = aws_instance.web-server-instance.id
}


# Terraform variables
variable "subnet_prefix" {
  description = "cidr block for the subnet"
  # default = "10.0.66.0/24"
}

resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "production"
  }
}

resource "aws_subnet" "subnet-1" {
  vpc_id = aws_vpc.prod-vpc.id
  cidr_block = var.subnet_prefix[0].cidr_block
  availability_zone = "us-east-1a"
  tags = {
    Name = var.subnet_prefix[0].name
  }
}

resource "aws_subnet" "subnet-2" {
  vpc_id = aws_vpc.prod-vpc.id
  cidr_block = var.subnet_prefix[1].cidr_block
  availability_zone = "us-east-1a"
  tags = {
    Name = var.subnet_prefix[1].name
  }
}
