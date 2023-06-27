output "configure_kubectl_team1" {
  description = "Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig"
  value       = "${module.team1.configure_kubectl} --kubeconfig /tmp/team1; export KUBECONFIG=/tmp/team1"
}
output "configure_kubectl_team2" {
  description = "Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig"
  value       = "${module.team2.configure_kubectl} --kubeconfig /tmp/team2; export KUBECONFIG=/tmp/team2"
}