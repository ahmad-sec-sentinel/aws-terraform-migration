variable "db_name" {
  default = "intel"
}

variable "db_username" {
  default = "admin"
}

variable "rds_password" {
  default = "intel123"
}

variable "instance_type" {
  default = "t2.micro"
}

variable "desired_capacity" {
  default = 2
}

variable "max_size" {
  default = 4
}

variable "min_size" {
  default = 2
}

