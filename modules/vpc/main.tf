# Create VPC
resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = var.enable_dns_support
  enable_dns_hostnames = var.enable_dns_hostnames
  instance_tenancy     = var.instance_tenancy

  tags = {
    Name = "${var.ResourcePrefix}-vpc"
  }
}
 
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${var.ResourcePrefix}-IGW"
  }
}

# Public Subnets (used for load balancers)
resource "aws_subnet" "public_subnet" {
  for_each = { for idx, cidr in var.public_subnet_cidr : idx => cidr }

  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = each.value
  availability_zone       = element(var.availability_zones, each.key)
  map_public_ip_on_launch = var.public_ip_on_launch

  tags = {
    Name                                      = "${var.ResourcePrefix}-Public-Subnet-${each.key + 1}"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                  = "1"
  }
}

# Private Subnets (used for EKS nodegroups and internal ELBs)
resource "aws_subnet" "private_subnet" {
  for_each = { for idx, cidr in var.private_subnet_cidr : idx => cidr }

  vpc_id            = aws_vpc.vpc.id
  cidr_block        = each.value
  availability_zone = element(var.availability_zones, each.key)

  tags = {
    Name                                      = "${var.ResourcePrefix}-Private-Subnet-${each.key + 1}"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"         = "1"
  }
}

# Route Table for Public Subnets
resource "aws_route_table" "PublicRT" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = var.PublicRT_cidr
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "${var.ResourcePrefix}-Public-RT" }
}

resource "aws_route_table_association" "PublicSubnetAssoc" {
  for_each = aws_subnet.public_subnet
  subnet_id      = each.value.id
  route_table_id = aws_route_table.PublicRT.id 
}

# Route Table for Private Subnets and NAT Gateway to allow internet access
resource "aws_eip" "eip" {
  associate_with_private_ip = var.eip_associate_with_private_ip
  tags = {
    Name = "${var.ResourcePrefix}-eip"
  }
}
 
resource "aws_nat_gateway" "ngw" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.public_subnet[0].id // Corrected reference
  tags = {
    Name = "${var.ResourcePrefix}-ngw"
  }
}
 
resource "aws_route_table" "PrivateRT" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block     = var.PrivateRT_cidr
    nat_gateway_id = aws_nat_gateway.ngw.id
  }
  tags = {
    Name = "${var.ResourcePrefix}-Private-RT"
  }
}
 
resource "aws_route_table_association" "PrivateSubnetAssoc" {
  for_each = aws_subnet.private_subnet
  subnet_id      = each.value.id
  route_table_id = aws_route_table.PrivateRT.id 
}

