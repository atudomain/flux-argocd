data "flux_install" "main" {
    target_path = "production"
    network_policy = false
    version = "latest"
}

resource "kubernetes_namespace" "flux_system" {
    metadata {
        name = "flux-system"
    }
}

resource "kubernetes_namespace" "flux" {
    metadata {
        name = "flux"
    }
}

# Split multi-doc YAML with
# https://registry.terraform.io/providers/gavinbunney/kubectl/latest
data "kubectl_file_documents" "apply" {
  content = data.flux_install.main.content
}

# Convert documents list to include parsed yaml data
locals {
  apply = [ for v in data.kubectl_file_documents.apply.documents : {
      data: yamldecode(v)
      content: v
    }
  ]
}

# Apply manifests on the cluster
resource "kubectl_manifest" "apply" {
  for_each   = { for v in local.apply : lower(join("/", compact([v.data.apiVersion, v.data.kind, lookup(v.data.metadata, "namespace", ""), v.data.metadata.name]))) => v.content }
  depends_on = [kubernetes_namespace.flux_system]
  yaml_body = each.value
}
