provider "aws" {
  region = "ap-south-1"
  access_key = "AKIAZIC7FGF2YLFODI7N"
  secret_key = "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"
}

resource "tls_private_key" "key" {
  algorithm   = "RSA"
}

resource "aws_key_pair" "mykey" {
  key_name   = "mykey11222" 
  public_key = tls_private_key.key.public_key_openssh
}

resource "aws_vpc" "vpc" { 
  cidr_block = "10.0.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = "true"

  tags = {
    Name = "myvpc"
  }
}


resource "aws_subnet" "public_subnet" { 
  depends_on = [aws_vpc.vpc]
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-south-1b"
  map_public_ip_on_launch = "true"
  
  tags = {
    Name = "public_sub"
  }
}


resource "aws_subnet" "private_subnet" { 
  depends_on = [aws_vpc.vpc]
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "ap-south-1b"
  map_public_ip_on_launch = "false"
  
  tags = {
    Name = "private_sub"
  }
}


resource "aws_internet_gateway" "internet_gateway" { 
   depends_on = [aws_vpc.vpc]
   vpc_id = aws_vpc.vpc.id
  
  tags = {
    Name = "gateway"
  }
}

resource "aws_eip" "eip" {
  vpc =true
}
resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.public_subnet.id

  tags = {
    Name = "nat_gate"
  }
}


resource "aws_route_table" "route_table" { 
  depends_on = [aws_vpc.vpc]
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }
  
  tags = {
    Name = "table"
  }
}


resource "aws_route_table_association" "route_associate" {
  depends_on = [aws_subnet.public_subnet]
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.route_table.id
 
}


resource "aws_security_group" "security_group" {
  depends_on = [aws_vpc.vpc]
  name        = "security"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.vpc.id

 ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

 ingress {
    description = "ssh"
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

  tags = {
    Name = "security_g"
  }
}


resource "aws_instance" "wordpressos" {
  ami           = "ami-049cbce295a54b26b"
  instance_type = "t2.micro"
  key_name      = aws_key_pair.mykey.key_name
  subnet_id =  aws_subnet.public_subnet.id
  vpc_security_group_ids = [ aws_security_group.security_group.id ]
  
  tags = {
    Name = "wordpress"
  }
}

output "wordpress_public_ip"{
  value=aws_instance.wordpressos.public_ip
}


resource "aws_security_group" "sql_security_group" {
  depends_on = [aws_vpc.vpc]
  name        = "sqlscurity"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "t3mysql"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sql_security_g"
  }
}


resource "aws_instance" "sql_os" {
  ami           = "ami-08706cb5f68222d09"
  instance_type = "t2.micro"
  key_name      = aws_key_pair.mykey.key_name
  subnet_id =  aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.sql_security_group.id]
  
  tags = {
    Name = "sql_os"
  }
}

resource "null_resource" "null" {
depends_on = [aws_instance.wordpressos,aws_instance.sql_os]

connection {
        type        = "ssh"
    	user        = "ec2-user"
    	private_key = tls_private_key.key.private_key_pem
        host     = aws_instance.wordpressos.public_ip
        }

provisioner "local-exec" {    
      command = "start chrome http://${aws_instance.wordpressos.public_ip}/wordpress"
   }
}