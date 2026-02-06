output "security_group_ids" {
  description = "Map of security group names to IDs"
  value = {
    for key, sg in aws_security_group.main : key => sg.id
  }
}

output "security_group_arns" {
  description = "Map of security group names to ARNs"
  value = {
    for key, sg in aws_security_group.main : key => sg.arn
  }
}

output "web_sg_id" {
  description = "Web security group ID"
  value       = aws_security_group.main["web"].id
}

output "app_sg_id" {
  description = "Application security group ID"
  value       = aws_security_group.main["app"].id
}

output "db_sg_id" {
  description = "Database security group ID"
  value       = aws_security_group.main["db"].id
}

output "ephemeral_sg_id" {
  description = "Ephemeral ports security group ID"
  value       = aws_security_group.ephemeral.id
}

output "all_ingress_rules_summary" {
  description = "Summary of all ingress rules"
  value = {
    for key, sg in aws_security_group.main : key => [
      for rule in local.security_groups[key].ingress_rules : {
        ports       = "${rule.from_port}-${rule.to_port}"
        protocol    = rule.protocol
        description = rule.description
      }
    ]
  }
}
