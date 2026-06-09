data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Internal-only. Inbound from the VPC CIDR is for future in-VPC consumers (e.g. SOAR);
# SSM port forwarding does not traverse this SG, so SSM access works with no inbound at all.
resource "aws_security_group" "siem" {
  name        = "${var.environment}-siem"
  description = "Elastic SIEM - internal access only"
  vpc_id      = var.vpc_id

  ingress {
    description = "Elasticsearch from within the VPC"
    from_port   = 9200
    to_port     = 9200
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
  }

  ingress {
    description = "Kibana from within the VPC"
    from_port   = 5601
    to_port     = 5601
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
  }

  egress {
    description = "Outbound for SSM, S3, and package repositories"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-siem"
  }
}

# Private subnet + instance profile = no public IP, no SSH key; reached only via SSM.
resource "aws_instance" "this" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.private_subnet_id
  iam_instance_profile   = var.instance_profile_name
  vpc_security_group_ids = [aws_security_group.siem.id]

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }

  tags = {
    Name = "${var.environment}-siem"
  }
}

# Separate encrypted volume for Elasticsearch indices — formatted and mounted during install.
resource "aws_ebs_volume" "data" {
  availability_zone = aws_instance.this.availability_zone
  size              = var.ebs_volume_size_gb
  type              = "gp3"
  encrypted         = true

  tags = {
    Name = "${var.environment}-siem-data"
  }
}

resource "aws_volume_attachment" "data" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.data.id
  instance_id = aws_instance.this.id
}
