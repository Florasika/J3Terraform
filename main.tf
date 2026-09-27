# ============================================================
#  JOUR 3 / 10 — Terraform : Remote State & Workspaces
#  Backend local simulé + Workspaces dev/staging/prod
# ============================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }

  # ── BACKEND : où stocker le state ────────────────────────
  # Backend local (défaut) — state dans terraform.tfstate
  # En production on utiliserait :
  #   backend "s3" { bucket = "mon-bucket", key = "state.tfstate" }
  #   backend "gcs" { bucket = "mon-bucket" }
  #   backend "azurerm" { ... }
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "local" {}

# ── LOCALS : config différente par workspace ─────────────────
# terraform.workspace = nom du workspace actif (default, dev, prod...)
locals {
  # Workspace actif
  workspace = terraform.workspace

  # Config par environnement
  config_par_env = {
    default = {
      db_host       = "localhost"
      db_port       = 5432
      max_retries   = 1
      log_level     = "DEBUG"
      objectif_ca   = 10000
    }
    dev = {
      db_host       = "dev-db.internal"
      db_port       = 5432
      max_retries   = 2
      log_level     = "DEBUG"
      objectif_ca   = 20000
    }
    staging = {
      db_host       = "staging-db.internal"
      db_port       = 5432
      max_retries   = 3
      log_level     = "INFO"
      objectif_ca   = 50000
    }
    prod = {
      db_host       = "prod-db.internal"
      db_port       = 5432
      max_retries   = 5
      log_level     = "WARNING"
      objectif_ca   = 100000
    }
  }

  # Sélectionner la config du workspace actif
  # Si le workspace n'existe pas dans la map → fallback sur "default"
  env_config = lookup(local.config_par_env, local.workspace,
                      local.config_par_env["default"])
}

# ── RESOURCE 1 : Config de l'environnement ───────────────────
resource "local_file" "config_env" {
  filename = "${path.module}/output/${local.workspace}/config.json"
  content  = jsonencode({
    workspace     = local.workspace
    nom_projet    = var.nom_projet
    db_host       = local.env_config.db_host
    db_port       = local.env_config.db_port
    max_retries   = local.env_config.max_retries
    log_level     = local.env_config.log_level
    objectif_ca   = local.env_config.objectif_ca
    genere_le     = timestamp()
  })
  file_permission = "0644"
}

# ── RESOURCE 2 : Fichier .env spécifique au workspace ────────
resource "local_file" "env_file" {
  filename = "${path.module}/output/${local.workspace}/.env"
  content  = <<-EOT
    WORKSPACE=${local.workspace}
    PROJET=${var.nom_projet}
    DB_HOST=${local.env_config.db_host}
    DB_PORT=${local.env_config.db_port}
    LOG_LEVEL=${local.env_config.log_level}
    MAX_RETRIES=${local.env_config.max_retries}
    OBJECTIF_CA=${local.env_config.objectif_ca}
  EOT
  file_permission = "0600"
}

# ── RESOURCE 3 : Rapport de déploiement ──────────────────────
resource "local_file" "rapport_deploiement" {
  filename = "${path.module}/output/${local.workspace}/rapport.md"
  content  = <<-EOT
    # Rapport de déploiement — ${var.nom_projet}

    **Workspace :** ${local.workspace}
    **Généré par :** Terraform Remote State & Workspaces

    ## Configuration active

    | Paramètre     | Valeur                          |
    |---------------|---------------------------------|
    | DB Host       | ${local.env_config.db_host}     |
    | DB Port       | ${local.env_config.db_port}     |
    | Max Retries   | ${local.env_config.max_retries} |
    | Log Level     | ${local.env_config.log_level}   |
    | Objectif CA   | ${local.env_config.objectif_ca} €|

    ## State Backend
    - Type : local
    - Chemin : terraform.tfstate.d/${local.workspace}/terraform.tfstate

    > Généré automatiquement par Terraform.
    > Ne pas modifier manuellement.
  EOT
}
