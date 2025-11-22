# --- Variables para GCP ---
variable "gcp_project_id" {
  description = "ID del Proyecto de Google Cloud donde se desplegarán los recursos."
  type        = string
  default = "plataformas2-356563"
}

variable "gcp_region" {
  description = "Región de Google Cloud para los recursos. (Ej: us-west1, europe-west4)"
  type        = string
  default     = "us-central1"
}

variable "gke_node_machine_type" {
  description = "El tipo de máquina para los nodos de GKE (equivalente a Standard_B2ms de Azure)."
  type        = string
  default     = "e2-standard-4" # 2 vCPU, 4 GB RAM (Comparable al B2ms)
}

# Manteniendo las variables existentes para la configuración del clúster
variable "aks_cluster_name" {
  description = "El nombre deseado para el clúster (se usará como nombre del GKE)."
  type        = string
  default     = "mygpccluster"
}

variable "prefix" {
  type    = string
  default = "225"
}

