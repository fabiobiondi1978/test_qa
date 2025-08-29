data "aws_availability_zones" "this" {
  state = "available"
}


locals {
  # Use 1 AZ if single-AZ, otherwise use first 3 AZs
  azs = var.multi_az ? slice(data.aws_availability_zones.this.names, 0, 3) : slice(data.aws_availability_zones.this.names, 0, 1)

  # Availability Zones map
  az_map = { for idx, az in local.azs : az => { index = idx } }

  # Public subnets cidr /24s
  public_cidr = { for az, o in local.az_map : az => cidrsubnet(var.vpc_cidr, 8, 200 + o.index) }

  # Private subnets cidr /19s
  private_cidr = { for az, o in local.az_map : az => cidrsubnet(var.vpc_cidr, 3, o.index) }

  common_tags = merge({
    "Company" = var.Company,
  }, var.tags)
}

resource "aws_vpc" "test_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(local.common_tags, { "Type" = "vpc" }, { "Name" = "${var.Company}-vpc" })
}


resource "aws_internet_gateway" "test_vpc" {
  vpc_id = aws_vpc.test_vpc.id
  tags   = merge(local.common_tags, { "Type" = "Internet-GW" }, { "Name" = "${var.Company}-igw" })
}


### Public Subnets ###

resource "aws_subnet" "public-sbn" {
  for_each                = local.az_map
  vpc_id                  = aws_vpc.test_vpc.id
  availability_zone       = each.key
  cidr_block              = local.public_cidr[each.key]
  map_public_ip_on_launch = true
  tags = merge(local.common_tags, {
    "Type" = "subnet"
    "AZ"   = each.key
    "Name" = "${var.Company}-public-${each.value.index}"
  })
}


resource "aws_route_table" "public-rtb" {
  vpc_id = aws_vpc.test_vpc.id
  tags   = merge(local.common_tags, { "Type" = "routetable-public" }, { "Name" = "${var.Company}-public-rtb" })
}


resource "aws_route" "public_route_internet" {
  route_table_id         = aws_route_table.public-rtb.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.test_vpc.id
}


resource "aws_route_table_association" "public-rtb-assoc" {
  for_each       = aws_subnet.public-sbn
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public-rtb.id
}
