output "network_id" {
  value = google_compute_network.vpc.id
}

output "subnetwork_id" {
  value = google_compute_subnetwork.subnet.id
}

output "private_vpc_connection_id" {
  value = google_service_networking_connection.private_vpc_connection.id
}

