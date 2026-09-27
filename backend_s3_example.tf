# ============================================================
#  EXEMPLE : Backend S3 (AWS) — NE PAS EXÉCUTER
#  Montre comment configurer un remote state en production
# ============================================================

# terraform {
#   backend "s3" {
#     bucket         = "mon-terraform-state-bucket"
#     key            = "etl-portfolio/terraform.tfstate"
#     region         = "eu-west-3"      # Paris
#     encrypt        = true             # chiffrement côté serveur
#     dynamodb_table = "terraform-lock" # verrou pour éviter les conflits
#   }
# }

# Commandes pour créer le bucket S3 (une seule fois) :
# aws s3api create-bucket \
#   --bucket mon-terraform-state-bucket \
#   --region eu-west-3 \
#   --create-bucket-configuration LocationConstraint=eu-west-3

# aws s3api put-bucket-versioning \
#   --bucket mon-terraform-state-bucket \
#   --versioning-configuration Status=Enabled

# aws dynamodb create-table \
#   --table-name terraform-lock \
#   --attribute-definitions AttributeName=LockID,AttributeType=S \
#   --key-schema AttributeName=LockID,KeyType=HASH \
#   --billing-mode PAY_PER_REQUEST

# ── EXEMPLE : Data source pour lire le state d'un autre projet ──
# data "terraform_remote_state" "reseau" {
#   backend = "s3"
#   config = {
#     bucket = "mon-terraform-state-bucket"
#     key    = "reseau/terraform.tfstate"
#     region = "eu-west-3"
#   }
# }
# Utilisation : data.terraform_remote_state.reseau.outputs.vpc_id
