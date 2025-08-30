# AWS VPC Terraform Module

This Terraform module provisions an AWS VPC with public and private subnets, supporting both single-AZ and multi-AZ deployments, and configurable egress via single or multiple NAT Gateways.

# Files
```
README.md
vpc/
   ├─ versions.tf
   ├─ variables.tf
   ├─ main.tf
```

# Features

- VPC CIDR must to be /16. (example 10.10.0.0/16)

- Single AZ: 
   - 1 public subnet /24
   - 1 private subnet /19

Multi AZs:
   - 3 public subnets /24
   - 3 private subnets /19

Configurable subnets:
   - single: 1 NAT Gateway
   - multi: 1 NAT Gateway per each AZs


# Inputs

Variable, Type, Default, Description
 - Company,  string, "QA",   Base name of the company used as prefix for tagging resources
 - vpc_cidr, string, no, VPC CIDR block, must be /16 (example 10.10.0.0/16)
 - multi_az, bool, no,  If true provision subnets across 3 AZs, otherwise 1 AZ only
 - nat_gateway_provisioning, string, no, if "single" provision 1 NAT GW, if "multi" provision one NAT GW for each AZs
 - tags, string, { "Environmenr" = "POC", "Company" = "QA"}, tags applied to all resources


 # Usage

 `terrafor plan`
```
input: 
   - multi_az: true/false
   - nat_gateway_provisioning: single/multi
   - vpc_cidr: X.X.X.X/16 
```