resource "kubernetes_namespace" "monitoring" {
  depends_on = [
    var.eks_cluster_id
  ]

  metadata {
    name = var.namespace
  }
}

resource "kubectl_manifest" "pv" {
  depends_on = [kubernetes_namespace.monitoring]
  yaml_body = <<YAML
apiVersion: v1
kind: PersistentVolume
metadata:
  name: kube-prometheus-stack-pv
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  storageClassName: "gp2"  # Update with the appropriate StorageClass name
  awsElasticBlockStore:
    volumeID: ${var.ebs_volume_id}  # Replace with your EBS volume ID
    fsType: ext4
YAML
}

resource "kubectl_manifest" "pvc" {
  depends_on = [kubernetes_manifest.pv]
  yaml_body = <<YAML
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: kube-prometheus-stack-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  volumeName: kube-prometheus-stack-pv
YAML
}

resource "helm_release" "kube-prometheus" {
  depends_on = [
    kubectl_manifest.pvc
  ]

  name       = var.stack_name
  namespace  = var.namespace    
  repository = "https://raw.githubusercontent.com/theArcianCoder/helm-chart-ttn/main"
  chart      = "kube-prometheus-stack"

  set {
    name  = "grafana.ingress.enabled"
    value = "true"
  }

  set {
    name  = "grafana.ingress.annotations.kubernetes\\.io/ingress\\.class"
    value = "alb"
  }

  set {
    name  = "grafana.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/scheme"
    value = "internet-facing"
  }

  set {
    name  = "grafana.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/target-type"
    value = "ip"
  }

  set {
    name  = "grafana.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/healthcheck-protocol"
    value = "HTTP"
  }
  set {
    name  = "alertmanager.persistentVolume.existingClaim"
    value = "kube-prometheus-stack-pvc"
  }
  set {
    name  = "server.persistentVolume.existingClaim"
    value = "kube-prometheus-stack-pvc"
  }
  set {
    name  = "grafana.persistentVolume.existingClaim"
    value = "kube-prometheus-stack-pvc"
  }
}
