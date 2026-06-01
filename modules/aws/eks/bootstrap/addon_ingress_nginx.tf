resource "helm_release" "ingress_nginx" {
  count = try(var.addons.ingress_nginx, true) ? 1 : 0

  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = try(var.helm_versions["ingress_nginx"], "4.10.1")
  namespace        = "ingress-nginx"
  create_namespace = true
  wait             = false
  timeout          = 300

  set {
    name  = "controller.replicaCount"
    value = "1"
  }

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
    value = "external"
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-nlb-target-type"
    value = "ip"
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-scheme"
    value = "internet-facing"
  }

  depends_on = [
    helm_release.aws_load_balancer_controller,
  ]
}
