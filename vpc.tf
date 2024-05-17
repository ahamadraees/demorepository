resource "aws_vpc" "my-vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "my-vpc"
  }
}
resource "aws_subnet" "subnet-1" {
  vpc_id                  = aws_vpc.my-vpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet-1"
  }
}
resource "aws_subnet" "subnet-2" {
  vpc_id                  = aws_vpc.my-vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet-2"
  }
}
resource "aws_internet_gateway" "my-internet-gatway" {
  vpc_id = aws_vpc.my-vpc.id

  tags = {
    Name = "my-internet-gatway"
  }
}
resource "aws_route_table" "my-rt" {
  vpc_id = aws_vpc.my-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my-internet-gatway.id
  }
}
resource "aws_route_table_association" "my-rta" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.my-rt.id
}
resource "aws_route_table_association" "my-rtb" {
  subnet_id      = aws_subnet.subnet-2.id
  route_table_id = aws_route_table.my-rt.id
}
resource "aws_security_group" "my-sg" {
  name        = "my-sg"
  description = "for taking ssh and port 80 also the instance"
  vpc_id      = aws_vpc.my-vpc.id

  tags = {
    Name = "my-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "for-ssh" {
  security_group_id = aws_security_group.my-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "for-http" {
  security_group_id = aws_security_group.my-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}
resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.my-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
resource "aws_instance" "web1" {
  ami                    = "ami-05a5bb48beb785bf1"
  instance_type          = "t2.micro"
  availability_zone      = "ap-south-1a"
  subnet_id              = aws_subnet.subnet-1.id
  vpc_security_group_ids = [aws_security_group.my-sg.id]
  user_data              = base64encode(file("${path.module}/user1.sh"))

  tags = {
    Name = "web1"
  }
}
resource "aws_instance" "web2" {
  ami                    = "ami-05a5bb48beb785bf1"
  instance_type          = "t2.micro"
  availability_zone      = "ap-south-1b"
  subnet_id              = aws_subnet.subnet-2.id
  vpc_security_group_ids = [aws_security_group.my-sg.id]
  user_data              = base64encode(file("${path.module}/user2.sh"))

  tags = {
    Name = "web2"
  }
}
resource "aws_lb" "my-lb" {
  name               = "my-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.my-sg.id]
  subnets            = [aws_subnet.subnet-1.id, aws_subnet.subnet-2.id]

}
resource "aws_lb_target_group" "target-group" {
  name     = "target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.my-vpc.id
}
resource "aws_lb_target_group_attachment" "attach-1" {
  target_group_arn = aws_lb_target_group.target-group.arn
  target_id        = aws_instance.web1.id
  port             = 80
}
resource "aws_lb_target_group_attachment" "attach-2" {
  target_group_arn = aws_lb_target_group.target-group.arn
  target_id        = aws_instance.web2.id
  port             = 80
}
resource "aws_lb_listener" "my-listener" {
  load_balancer_arn = aws_lb.my-lb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target-group.arn
  }
}
output "loadbalancerdns" {
  value = aws_lb.my-lb.dns_name
}

