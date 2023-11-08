resource "aws_db_subnet_group" "rds" {
  name       = "subnet_group_rds"

  subnet_ids = aws_subnet.private_subnet.*.id

  tags = {
    Name = "DB subnet group"
  }
}

resource "aws_security_group" "rds" {
  name = "${var.app_name}-rds-sg"
  description = "SG for RDS"
  vpc_id      = aws_vpc.vpc.id

  ingress = [{
    cidr_blocks = [ "0.0.0.0/0" ]
    description = "Acesso banco de dado local"
    from_port = 3306
    ipv6_cidr_blocks = []
    prefix_list_ids = []
    protocol = "tcp"
    security_groups = [aws_security_group.ecs.id]
    self = false
    to_port = 3306
  }]

  egress = [{
    cidr_blocks = [ "0.0.0.0/0" ]
    description = "RDS acesso externo"
    from_port = 0
    ipv6_cidr_blocks = []
    prefix_list_ids = []
    protocol = "-1"
    security_groups = []
    self = false
    to_port = 0
  }] 
}

resource "aws_db_instance" "rds" {
  identifier = "${var.app_name}-rds"
  allocated_storage    = 10
  engine               = "mysql"
  engine_version       = "8.0.33"
  username = var.db_username
  password = var.db_password
  db_name = var.db_default_database
  instance_class       = "db.t3.micro"
  skip_final_snapshot  = true
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible = true
  db_subnet_group_name = aws_db_subnet_group.rds.name
}