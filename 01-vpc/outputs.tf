output "vpc_id" {
  value = aws_vpc.main.id
}

output "subnet_ids" {
  value = [
    aws_subnet.public_subnet_1.id,
    aws_subnet.public_subnet_2.id
  ]
}

output "route_table_id" {
  value = aws_route_table.public.id
}

output "internet_gateway_id" {
  value = aws_internet_gateway.igw.id
}
