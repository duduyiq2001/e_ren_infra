# Jenkins namespace
resource "kubernetes_namespace" "jenkins" {
  metadata {
    name = "jenkins"
    
    labels = {
      name = "jenkins"
    }
  }
  
  depends_on = [module.eks]
}

# Jenkins Helm release
resource "helm_release" "jenkins" {
  name       = "jenkins"
  repository = "https://charts.jenkins.io"
  chart      = "jenkins"
  version    = "5.0.0"  # Pin version for reproducibility
  namespace  = kubernetes_namespace.jenkins.metadata[0].name
  
  wait    = true
  timeout = 600  # 10 minutes
  
  # Jenkins controller configuration
  set {
    name  = "controller.adminUser"
    value = "admin"
  }
  
  set_sensitive {
    name  = "controller.adminPassword"
    value = var.jenkins_admin_password
  }
  
  # Service type - LoadBalancer for external access
  set {
    name  = "controller.serviceType"
    value = "LoadBalancer"
  }
  
  # Schedule controller on dedicated node
  set {
    name  = "controller.nodeSelector.role"
    value = "controller"
  }
  
  # Tolerate controller taint
  set {
    name  = "controller.tolerations[0].key"
    value = "jenkins.io/controller"
  }
  set {
    name  = "controller.tolerations[0].operator"
    value = "Equal"
  }
  set {
    name  = "controller.tolerations[0].value"
    value = "true"
  }
  set {
    name  = "controller.tolerations[0].effect"
    value = "NoSchedule"
  }
  
  # Resource limits for controller
  set {
    name  = "controller.resources.requests.cpu"
    value = "200m"
  }
  set {
    name  = "controller.resources.requests.memory"
    value = "256Mi"
  }
  set {
    name  = "controller.resources.limits.cpu"
    value = "500m"
  }
  set {
    name  = "controller.resources.limits.memory"
    value = "512Mi"
  }
  
  # Enable persistence
  set {
    name  = "persistence.enabled"
    value = "true"
  }
  set {
    name  = "persistence.size"
    value = "8Gi"
  }
  set {
    name  = "persistence.storageClass"
    value = "gp3"
  }
  
  # Install essential plugins
  set {
    name  = "controller.installPlugins[0]"
    value = "kubernetes:4246.v5a_12b_1fe120e"
  }
  set {
    name  = "controller.installPlugins[1]"
    value = "workflow-aggregator:latest"
  }
  set {
    name  = "controller.installPlugins[2]"
    value = "git:latest"
  }
  set {
    name  = "controller.installPlugins[3]"
    value = "github:latest"
  }
  set {
    name  = "controller.installPlugins[4]"
    value = "github-branch-source:latest"
  }
  set {
    name  = "controller.installPlugins[5]"
    value = "configuration-as-code:latest"
  }
  set {
    name  = "controller.installPlugins[6]"
    value = "kubernetes-credentials-provider:latest"
  }
  
  # Configure Kubernetes cloud
  set {
    name  = "agent.enabled"
    value = "true"
  }
  set {
    name  = "agent.namespace"
    value = "jenkins"
  }
  
  # Agent pods schedule on agent node
  set {
    name  = "agent.podTemplates.default.nodeSelector"
    value = "role=agent"
  }
  
  depends_on = [module.eks]
}