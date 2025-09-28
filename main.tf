

terraform {
  required_providers {
    kind = {
      source = "tehcyx/kind"
      version = "0.9.0"
    }
    helm = {
      source = "hashicorp/helm"
      version = "2.12.1"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "2.27.0"
    }
    kubectl = {
      source = "gavinbunney/kubectl"
      version = "1.14.0"
    }
    time = {
      source = "hashicorp/time"
      version = "0.11.1"
    }
  }
}

provider "kind" {}

provider "helm" {
  kubernetes {
    config_path = kind_cluster.default.kubeconfig_path
  }
}

provider "kubernetes" {
  config_path = kind_cluster.default.kubeconfig_path
}

provider "kubectl" {
  config_path = kind_cluster.default.kubeconfig_path
}

resource "kind_cluster" "default" {
  name = "kind-cluster"
  wait_for_ready = true
  kind_config {
    kind = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"
    node {
      role = "control-plane"
    }
    node {
      role = "worker"
    }
    node {
      role = "worker"
    }
  }
}

resource "helm_release" "ingress_nginx" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart       = "ingress-nginx"
  namespace  = "ingress-nginx"
  create_namespace = true
  depends_on = [kind_cluster.default]
}

resource "helm_release" "metallb" {
  name       = "metallb"
  repository = "https://metallb.github.io/metallb"
  chart      = "metallb"
  namespace  = "metallb-system"
  create_namespace = true
  depends_on = [kind_cluster.default]
}

resource "time_sleep" "wait_for_metallb_crds" {
  create_duration = "30s"
  depends_on = [helm_release.metallb]
}

resource "kubectl_manifest" "metallb_ip_pool" {
  yaml_body = <<-EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default
  namespace: metallb-system
spec:
  addresses:
  - 172.18.255.1-172.18.255.250
  EOF

  depends_on = [time_sleep.wait_for_metallb_crds]
}

resource "kubectl_manifest" "metallb_l2_advertisement" {
  yaml_body = <<-EOF
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
spec:
  ipAddressPools:
  - default
  EOF

  depends_on = [time_sleep.wait_for_metallb_crds]
}
