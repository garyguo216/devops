# VPC DESIGN
# define 4 layers subnets in 2 AZs, include 2 public subnets for Internet access, 2 private subnet for web layer, 2 private subnet for application layer, 2 private subnet for DB layer, and IGW,NAT Gateway route table.

resource "aws_vpc" "gary_test" {
  cidr_block           = "10.${var.cidr_numeral}.0.0/16"
  enable_dns_hostnames = true

  tags {
    Name = "vpc-${var.vpc_name}"
  }
}

resource "aws_internet_gateway" "gary_test" {
  vpc_id = "${aws_vpc.gary_test.id}"

  tags {
    Name = "igw-${var.vpc_name}"
  }
}

resource "aws_eip" "nat" {
  count = "${length(split(",", "${var.availability_zones}"))}"
  vpc   = true

  tags {
    Name = "ip-NAT-${var.vpc_name}"
  }
}

resource "aws_nat_gateway" "nat" {
  count  = "${length(split(",", "${var.availability_zones}"))}"

  allocation_id = "${element(aws_eip.nat.*.id, count.index)}"
  subnet_id = "${element(aws_subnet.public.*.id, count.index)}"

  tags {
    Name = "gw-NAT-${var.vpc_name}"
  }
}


# PUBLIC SUBNETS
# The public subnet is where the bastion, NATs and ELBs reside. In most cases,
# there should not be any servers in the public subnet.

resource "aws_subnet" "public" {
  count  = "${length(split(",", "${var.availability_zones}"))}"
  vpc_id = "${aws_vpc.gary_test.id}"

  cidr_block              = "10.${var.cidr_numeral}.${lookup(var.cidr_numeral_public, count.index)}.0/24"
  availability_zone       = "${element(split(",", var.availability_zones), count.index)}"
  map_public_ip_on_launch = true

  tags {
    Name               = "public${count.index}-${var.vpc_name}"
    immutable_metadata = "{ \"purpose\": \"external_${var.vpc_name}\", \"target\": null }"
  }
}

# PUBLIC SUBNETS - Default route
#
resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.gary_test.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gary_test.id}"
  }

  tags {
    Name = "publicrt-${var.vpc_name}"
  }
}

# PUBLIC SUBNETS - Route associations
#
resource "aws_route_table_association" "public" {
  count          = "${length(split(",", "${var.availability_zones}"))}"
  subnet_id      = "${element(aws_subnet.public.*.id, count.index)}"
  route_table_id = "${aws_route_table.public.id}"
}

# PRIVATE SUBNETS
#
# Route Tables in a private subnet will not have Route resources created
# statically for them as the NAT instances are responsible for dynamically
# managing them on a per-AZ level using the Network=Private tag.

resource "aws_subnet" "private" {
  count  = "${length(split(",", "${var.availability_zones}"))}"
  vpc_id = "${aws_vpc.gary_test.id}"

  cidr_block        = "10.${var.cidr_numeral}.${lookup(var.cidr_numeral_private, count.index)}.0/24"
  availability_zone = "${element(split(",", var.availability_zones), count.index)}"

  tags {
    Name               = "private${count.index}-${var.vpc_name}"
    immutable_metadata = "{ \"purpose\": \"internal_${var.vpc_name}\", \"target\": null }"
    Network            = "Private"
  }
}

resource "aws_route_table" "private" {
  count  = "${length(split(",", "${var.availability_zones}"))}"
  vpc_id = "${aws_vpc.gary_test.id}"

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = "${element(aws_nat_gateway.nat.*.id, count.index)}"
  }

  tags {
    Name    = "private${count.index}rt-${var.vpc_name}"
    Network = "Private"
  }
}

resource "aws_route_table_association" "private" {
  count          = "${length(split(",", "${var.availability_zones}"))}"
  subnet_id      = "${element(aws_subnet.private.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.private.*.id, count.index)}"
}

# PRIVATE SUBNETS (DB)
#
# Route Tables in a private subnet will not have Route resources created
# statically for them as the NAT instances are responsible for dynamically
# managing them on a per-AZ level using the Network=Private tag.

resource "aws_subnet" "private_db" {
  count  = "${length(split(",", "${var.availability_zones}"))}"
  vpc_id = "${aws_vpc.gary_test.id}"

  cidr_block        = "10.${var.cidr_numeral}.${lookup(var.cidr_numeral_private_db, count.index)}.0/24"
  availability_zone = "${element(split(",", var.availability_zones), count.index)}"

  tags {
    Name               = "db-private${count.index}-${var.vpc_name}"
    immutable_metadata = "{ \"purpose\": \"internal_${var.vpc_name}\", \"target\": null }"
    Network            = "Private"
  }
}

resource "aws_route_table" "private_db" {
  count  = "${length(split(",", "${var.availability_zones}"))}"
  vpc_id = "${aws_vpc.gary_test.id}"

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = "${element(aws_nat_gateway.nat.*.id, count.index)}"
  }

  tags {
    Name    = "privatedb${count.index}rt-${var.vpc_name}"
    Network = "Private"
  }
}

resource "aws_route_table_association" "private_db" {
  count          = "${length(split(",", "${var.availability_zones}"))}"
  subnet_id      = "${element(aws_subnet.private_db.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.private_db.*.id, count.index)}"
}


# PRIVATE SUBNETS
#
# Route Tables in a private subnet will not have Route resources created
# statically for them as the NAT instances are responsible for dynamically
# managing them on a per-AZ level using the Network=Private tag.

resource "aws_subnet" "private_emr" {
  count  = "${length(split(",", "${var.availability_zones}"))}"
  vpc_id = "${aws_vpc.gary_test.id}"

  cidr_block        = "10.${var.cidr_numeral}.${lookup(var.cidr_numeral_private_emr, count.index)}.0/24"
  availability_zone = "${element(split(",", var.availability_zones), count.index)}"

  tags {
    Name               = "private_emr${count.index}-${var.vpc_name}"
    immutable_metadata = "{ \"purpose\": \"internal_${var.vpc_name}\", \"target\": null }"
    Network            = "Private"
  }
}

resource "aws_route_table" "private_emr" {
  count  = "${length(split(",", "${var.availability_zones}"))}"
  vpc_id = "${aws_vpc.gary_test.id}"

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = "${element(aws_nat_gateway.nat.*.id, count.index)}"
  }

  tags {
    Name    = "private_emr${count.index}rt-${var.vpc_name}"
    Network = "Private"
  }
}

resource "aws_route_table_association" "private_emr" {
  count          = "${length(split(",", "${var.availability_zones}"))}"
  subnet_id      = "${element(aws_subnet.private_emr.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.private_emr.*.id, count.index)}"
}
