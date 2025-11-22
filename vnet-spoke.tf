# --- Archivo de Redes Actualizado (vnet-spoke.tf) ---

# 1. Red VPC (equivalente a VNet Spoke)
resource "google_compute_network" "gke_vpc" {
  name                    = "gke-vpc-${var.prefix}"
  auto_create_subnetworks = false 
  routing_mode            = "REGIONAL"
}

# 2. Subred para Nodos de GKE (equivalente a snet-aks)
resource "google_compute_subnetwork" "gke_subnet" {
  name          = "gke-subnet-${var.prefix}"
  ip_cidr_range = "10.10.0.0/24" 
  region        = var.gcp_region
  network       = google_compute_network.gke_vpc.id

  # Necesario para GKE VPC-Native
  private_ip_google_access = true 

  # Rangos secundarios para Pods (Cluster IP range) y Services (Service IP range)
  secondary_ip_range {
    range_name    = "gke-pods-range"
    ip_cidr_range = "10.11.0.0/16" 
  }
  secondary_ip_range {
    range_name    = "gke-services-range"
    ip_cidr_range = "10.12.0.0/20"
  }
}

# 3. Subred de Solo Proxy para el Balanceador de Carga Interno
# (Requiere estar en una subred separada y dedicada)
resource "google_compute_subnetwork" "gke_proxy_subnet" {
  name          = "gke-proxy-subnet-${var.prefix}"
  # Usa el siguiente CIDR disponible después de 10.12.0.0/20
  ip_cidr_range = "10.12.16.0/24" 
  region        = var.gcp_region
  network       = google_compute_network.gke_vpc.self_link 

  # --- ¡ESTAS LÍNEAS SON LA CLAVE! ---
  # Define el propósito de la subred para el Balanceador de Carga Interno
  purpose       = "INTERNAL_HTTPS_LOAD_BALANCER" 
  role          = "ACTIVE"
  # ------------------------------------
}

# 4. IP ESTÁTICA INTERNA PARA EL INGRESS DE GKE (GCLB Interno)
resource "google_compute_address" "internal_ip" {
  name         = "gke-internal-ingress-ip"
  # NOTA: La IP del Ingress *sí* puede estar en la subred principal (`gke_subnet`).
  subnetwork   = google_compute_subnetwork.gke_subnet.self_link 
  address_type = "INTERNAL"
  region       = var.gcp_region
  address      = "10.10.0.50" 
}