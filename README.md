# 🏗️ Jour 3 / 10 — Terraform : Remote State & Workspaces

> **Série : 10 Days of Terraform** · Jour 3/10  
> Concepts : Backend · Remote State · Workspaces · locals · lookup()

---

## 📁 Fichiers du projet

```
day-03-remote-state/
│
├── main.tf                   ← Resources + locals par workspace
├── variables.tf              ← Variables
├── outputs.tf                ← Outputs dynamiques
├── backend_s3_example.tf     ← Exemple backend S3 (commenté)
├── output/                   ← Dossier créé par Terraform
│   ├── dev/                  ← Fichiers du workspace dev
│   ├── staging/              ← Fichiers du workspace staging
│   └── prod/                 ← Fichiers du workspace prod
└── README.md
```

---

## 🧠 C'est quoi le Remote State ?

```
State local (défaut) :
  → terraform.tfstate sur ta machine
  → problème : pas partageable en équipe, risque de perte

Remote State :
  → state stocké dans S3, GCS, Azure Blob, Terraform Cloud
  → partagé entre tous les membres de l'équipe
  → verrouillage pour éviter les conflits simultanés
```

---

## 🧠 C'est quoi un Workspace ?

```
Workspace = instance séparée du même code Terraform
  → chaque workspace a son propre state
  → même code → configs différentes selon le workspace

Sans workspace : 3 dossiers séparés (dev/, staging/, prod/)
Avec workspace : 1 seul dossier, 3 states distincts
```

---

## 🚀 ÉTAPE 1 — Préparer les fichiers

```bash
mkdir -p jour3-terraform/output
cd jour3-terraform/

# Copier les fichiers depuis le dépôt :
# main_j3.tf              → main.tf
# variables_j3.tf         → variables.tf
# outputs_j3.tf           → outputs.tf
# backend_s3_example.tf   → backend_s3_example.tf

cat > .gitignore << 'EOF'
.terraform/
.terraform.lock.hcl
terraform.tfstate
terraform.tfstate.d/
output/
EOF
```

---

## 🔑 ÉTAPE 2 — Le backend dans main.tf

```hcl
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}

# En production — backend S3 (AWS) :
# backend "s3" {
#   bucket         = "mon-bucket-state"
#   key            = "etl/terraform.tfstate"
#   region         = "eu-west-3"
#   encrypt        = true
#   dynamodb_table = "terraform-lock"
# }
```

---

## 🔑 ÉTAPE 3 — locals et lookup() par workspace

```hcl
locals {
  workspace = terraform.workspace   # "dev", "prod"...

  config_par_env = {
    dev  = { db_host = "dev-db.internal",  objectif_ca = 20000 }
    prod = { db_host = "prod-db.internal", objectif_ca = 100000 }
  }

  # lookup(map, clé, valeur_par_défaut)
  env_config = lookup(local.config_par_env, local.workspace,
                      local.config_par_env["dev"])
}

# Utilisation dans les resources
resource "local_file" "config" {
  filename = "output/${local.workspace}/config.json"
  content  = jsonencode({
    db_host     = local.env_config.db_host      # valeur selon workspace
    objectif_ca = local.env_config.objectif_ca
  })
}
```

---

## 🚀 ÉTAPE 4 — Initialiser

```bash
terraform init

# Résultat :
# Initializing the backend...
# Successfully configured the backend "local"!
# Terraform initialized successfully!
```

---

## 🚀 ÉTAPE 5 — Gérer les workspaces

```bash
# Voir les workspaces disponibles
terraform workspace list
# * default    ← workspace actif (marqué *)

# Créer et basculer sur "dev"
terraform workspace new dev
# Created and switched to workspace "dev"!

# Créer staging et prod
terraform workspace new staging
terraform workspace new prod

# Voir tous les workspaces
terraform workspace list
# * prod
#   staging
#   dev
#   default

# Revenir sur dev
terraform workspace select dev
```

---

## 🚀 ÉTAPE 6 — Appliquer sur chaque workspace

```bash
# Sur dev
terraform workspace select dev
terraform apply -auto-approve
# → crée output/dev/config.json avec db_host=dev-db.internal

# Sur staging
terraform workspace select staging
terraform apply -auto-approve
# → crée output/staging/config.json avec db_host=staging-db.internal

# Sur prod
terraform workspace select prod
terraform apply -auto-approve
# → crée output/prod/config.json avec db_host=prod-db.internal
```

---

## 🚀 ÉTAPE 7 — Vérifier les states séparés

```bash
# Chaque workspace a son propre state
ls terraform.tfstate.d/
# dev/
# staging/
# prod/

# State du workspace dev
cat terraform.tfstate.d/dev/terraform.tfstate

# Lister les ressources du workspace actif
terraform workspace select dev
terraform state list

# Comparer les outputs entre workspaces
terraform workspace select dev
terraform output config_active

terraform workspace select prod
terraform output config_active
# → db_host et objectif_ca différents !
```

---

## 🚀 ÉTAPE 8 — Voir les fichiers générés

```bash
# Chaque workspace a son propre dossier output
cat output/dev/config.json
cat output/staging/config.json
cat output/prod/config.json

cat output/dev/rapport.md
```

---

## 🔑 ÉTAPE 9 — Remote State avec S3 (exemple)

```bash
# 1. Créer le bucket S3 (une seule fois)
aws s3api create-bucket \
  --bucket mon-terraform-state \
  --region eu-west-3 \
  --create-bucket-configuration LocationConstraint=eu-west-3

# 2. Activer le versioning
aws s3api put-bucket-versioning \
  --bucket mon-terraform-state \
  --versioning-configuration Status=Enabled

# 3. Créer la table DynamoDB pour le verrou
aws dynamodb create-table \
  --table-name terraform-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST

# 4. Dans main.tf, remplacer le backend local par S3
# backend "s3" {
#   bucket         = "mon-terraform-state"
#   key            = "etl/terraform.tfstate"
#   region         = "eu-west-3"
#   encrypt        = true
#   dynamodb_table = "terraform-lock"
# }

# 5. Migrer le state existant vers S3
terraform init -migrate-state
```

---

## 🔑 ÉTAPE 10 — Lire le state d'un autre projet

```hcl
# data source terraform_remote_state
data "terraform_remote_state" "reseau" {
  backend = "local"
  config = {
    path = "../projet-reseau/terraform.tfstate"
  }
}

# Utiliser les outputs de l'autre projet
resource "local_file" "config" {
  content = "VPC: ${data.terraform_remote_state.reseau.outputs.vpc_id}"
}
```

---

## 💡 Récap — Workspaces vs Modules vs Dossiers séparés

| Approche | Avantages | Inconvénients |
|----------|-----------|---------------|
| Workspaces | Simple, même code | Configs trop différentes = complexe |
| Dossiers séparés | Isolation totale | Duplication de code |
| Modules | Réutilisabilité | Plus de fichiers |

**Règle :** Workspaces pour des environnements similaires (dev/prod).
Dossiers séparés si les environnements sont très différents.

---



---

⭐ **Si ce projet t'aide, mets une étoile !**
