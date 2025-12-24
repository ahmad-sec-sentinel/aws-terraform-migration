output "load_balancer_dns" {
  description = "DNS name of the load balancer"
  value       = aws_lb.web_lb.dns_name
}

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = aws_db_instance.default.endpoint
}

output "rds_database_name" {
  description = "Database name"
  value       = aws_db_instance.default.db_name
}

output "autoscaling_group_name" {
  description = "Auto Scaling Group name"
  value       = aws_autoscaling_group.web_asg.name
}

output "target_group_arn" {
  description = "Target Group ARN"
  value       = aws_lb_target_group.web_tg.arn
}
