data "aws_availability_zones" "zones" {
  state = "available"
}

locals {
  # Use 1 AZ if single-AZ, otherwise use first 3 AZs
  azs = var.multi_az ? slice(data.aws_availability_zones.zones.names, 0, 3) : slice(data.aws_availability_zones.zones.names, 0, 1)

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

resource "aws_internet_gateway" "igw" {
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
    "Name" = "${var.Company}-sbn-public-${each.value.index}"
  })
}

resource "aws_route_table" "public-rtb" {
  vpc_id = aws_vpc.test_vpc.id
  tags   = merge(local.common_tags, { "Type" = "routetable-public" }, { "Name" = "${var.Company}-public-rtb" })
}

resource "aws_route" "public_route_internet" {
  route_table_id         = aws_route_table.public-rtb.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public-rtb-assoc" {
  for_each       = aws_subnet.public-sbn
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public-rtb.id
}



### NAT Gateways and EIP

# Single NAT GW with count = 1 Multi NAT GW with count is for each AZs
resource "aws_eip" "nat-eip" {
  count  = var.nat_gateway_provisioning == "single" ? 1 : length(local.azs)
  domain = "vpc"
  tags = merge(
    local.common_tags,
    {
      "Type"  = "eip"
      "Index" = tostring(count.index)
      "Name"  = "nat-eip${count.index}"
    }
  )
}

locals {
  public_subnet_ids_by_index = [for az in local.azs : aws_subnet.public-sbn[az].id]
}

resource "aws_nat_gateway" "nat-gw" {
  count         = var.nat_gateway_provisioning == "single" ? 1 : length(local.azs)
  allocation_id = aws_eip.nat-eip[count.index].id
  subnet_id = (
    var.nat_gateway_provisioning == "single"
    ? local.public_subnet_ids_by_index[0]
    : local.public_subnet_ids_by_index[count.index]
  )
  tags = merge(local.common_tags,
    {
      "Type"  = "natgw"
      "Index" = tostring(count.index)
      "Name"  = "nat-gw${count.index}"
    }
  )
  depends_on = [aws_internet_gateway.igw]
}


# -----------------
# Private Subnets & Routing
# -----------------
resource "aws_subnet" "private-sbn" {
  for_each          = local.az_map
  vpc_id            = aws_vpc.test_vpc.id
  availability_zone = each.key
  cidr_block        = local.private_cidr[each.key]
  tags = merge(local.common_tags, {
    "Type" = "private"
    "AZ"   = each.key
    "Name" = "${var.Company}-sbn-private-${each.value.index}"
    }
  )
}


# Private route tables Mechanism
# - single NAT GW: one private route table 
# - multi NAT GW: one private route table for each AZs


# Single Route Table case
resource "aws_route_table" "private-rtb-single" {
  count  = var.nat_gateway_provisioning == "single" ? 1 : 0
  vpc_id = aws_vpc.test_vpc.id
  tags = merge(local.common_tags,
    {
      "Type" = "rtb-private-single"
      "Name" = "${var.Company}-private-rtb"
    }
  )
}

resource "aws_route" "private-route-single" {
  count                  = var.nat_gateway_provisioning == "single" ? 1 : 0
  route_table_id         = aws_route_table.private-rtb-single[0].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat-gw[0].id
}

resource "aws_route_table_association" "private-rtb-single-assoc" {
  for_each       = var.nat_gateway_provisioning == "single" ? aws_subnet.private-sbn : {}
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private-rtb-single[0].id
}


# Multi Route Table case 
resource "aws_route_table" "private-rtb-multi" {
  count  = var.nat_gateway_provisioning == "multi" ? length(local.azs) : 0
  vpc_id = aws_vpc.test_vpc.id
  tags = merge(local.common_tags,
    {
      "Type"  = "rtb-private"
      "Index" = tostring(count.index)
      "Name"  = "${var.Company}-private-rtb-${count.index}"
    }
  )
}

resource "aws_route" "private-route-multi" {
  count                  = var.nat_gateway_provisioning == "multi" ? length(local.azs) : 0
  route_table_id         = aws_route_table.private-rtb-multi[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat-gw[count.index].id
}

resource "aws_route_table_association" "private-rtb-multi-assoc" {
  for_each       = var.nat_gateway_provisioning == "multi" ? local.az_map : {}
  subnet_id      = aws_subnet.private-sbn[each.key].id
  route_table_id = aws_route_table.private-rtb-multi[each.value.index].id
}
