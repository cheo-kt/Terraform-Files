# Habilitar las APIs de GCP necesarias
resource "google_project_service" "gke_services" {
  for_each = toset([
    "container.googleapis.com", 
    "compute.googleapis.com",
  ])
  service            = each.key
  project            = var.gcp_project_id
  disable_on_destroy = false
}

# 1. Cuenta de Servicio (SA) para los nodos de GKE (equivalente a System Assigned Identity en AKS)
resource "google_service_account" "gke_node_sa" {
  account_id   = "gke-sa-node-${var.prefix}"
  display_name = "GKE Node Service Account"
  project      = var.gcp_project_id
}

# Asignar permisos básicos (se requiere para que las máquinas de GKE funcionen)
resource "google_project_iam_member" "gke_node_sa_binding" {
  project = var.gcp_project_id
  role    = "roles/container.nodeServiceAccount" 
  member  = "serviceAccount:${google_service_account.gke_node_sa.email}"
}


# 2. Clúster de GKE (equivalente a azurerm_kubernetes_cluster)
resource "google_container_cluster" "gke_cluster" {
  name     = var.aks_cluster_name
  location = var.gcp_region
  project  = var.gcp_project_id
  
  # Deshabilitar el pool de nodos por defecto para usar un recurso 'google_container_node_pool' separado
  remove_default_node_pool = true 
  initial_node_count       = 1 

  deletion_protection = false

  network    = google_compute_network.gke_vpc.self_link
  subnetwork = google_compute_subnetwork.gke_subnet.self_link

  # Configuración de red avanzada (VPC-Native)
  networking_mode = "VPC_NATIVE"
  ip_allocation_policy {
    cluster_secondary_range_name  = google_compute_subnetwork.gke_subnet.secondary_ip_range[0].range_name
    services_secondary_range_name = google_compute_subnetwork.gke_subnet.secondary_ip_range[1].range_name
  }
  
  # Habilitar el complemento de balanceador de carga HTTP (para Ingress)
  addons_config {
    http_load_balancing {
      disabled = false
    }
  }
  
  # La configuración de network_profile y dns_prefix de AKS se maneja aquí.
  # La configuración de política de red (Cilium) se configura de forma diferente en GKE.

  depends_on = [
    google_project_service.gke_services,
    google_project_iam_member.gke_node_sa_binding
  ]
}

# 3. Pool de Nodos de GKE (Separado, equivalente a default_node_pool en AKS)
resource "google_container_node_pool" "primary_nodes" {
  name       = "primary-pool"
  location   = var.gcp_region
  cluster    = google_container_cluster.gke_cluster.name
  node_count = 2 # min_count de AKS
  node_locations = ["${var.gcp_region}-a"]

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  autoscaling {
    max_node_count = 4 # max_count de AKS
    min_node_count = 2 
  }

  node_config {
    machine_type = var.gke_node_machine_type # e2-medium
    disk_size_gb = 20
    
    # Usar la Cuenta de Servicio creada
    service_account = google_service_account.gke_node_sa.email

    # Oauth Scopes necesarios para la comunicación básica de GKE
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }
}

# NOTA: Los recursos 'azurerm_role_assignment' (para el LB de AKS) y 'azurerm_resource_group' se eliminan.