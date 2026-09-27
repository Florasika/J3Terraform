output "workspace_actif" {
  description = "Workspace Terraform actuellement actif"
  value       = terraform.workspace
}

output "config_active" {
  description = "Configuration du workspace actif"
  value = {
    workspace   = terraform.workspace
    db_host     = local.env_config.db_host
    log_level   = local.env_config.log_level
    objectif_ca = local.env_config.objectif_ca
  }
}

output "fichiers_generes" {
  description = "Fichiers générés pour ce workspace"
  value = [
    local_file.config_env.filename,
    local_file.env_file.filename,
    local_file.rapport_deploiement.filename,
  ]
}
