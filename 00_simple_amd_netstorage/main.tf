variable "edgerc" {
  type        = string
  default     = "~/.edgerc"
  description = "Path to the edgerc file."
}

variable "edgerc_papi" {
  type        = string
  default     = "papi"
  description = "Name of the edgerc section for PAPI."
}

variable "conf_name" {
  type        = string
  description = "Name of the Akamai configuration file"
}

variable "group_name" {
  type        = string
  description = "Name of the Akamai Access Control Group (aka folder)"
}

variable "hostname" {
  type        = string
  description = "Hostname"
}

variable "edge_hostname" {
  type        = string
  description = "Edge hostname"
}

variable "email" {
  type        = list(string)
  description = "Notification email"
}

variable "amd_product" {
  type        = string
  description = "Product"
}

variable "amd_cpcode_name" {
  type        = string
  description = "AMD Delivery CP Code"
}

variable "ns_cpcode_id" {
  type        = number
  description = "NetStorage CP Code ID"
}

variable "ns_cpcode_name" {
  type        = string
  description = "NetStorage CP Code"
}

variable "ns_download_domain" {
  type        = string
  description = "NetStorage download domain"
}

provider "akamai" {
  edgerc           = var.edgerc
  property_section = var.edgerc_papi
}

data "akamai_contract" "default" {}

data "akamai_group" "default" {
  contract = data.akamai_contract.default.id
  name     = var.group_name
}

data "akamai_cp_code" "amd" {
  contract = data.akamai_contract.default.id
  name     = var.amd_cpcode_name
  group    = data.akamai_group.default.id
}

locals {
  # Generate the PAPI JSON rule tree into a local variable.
  # This is not required, but allows it to be output into a
  # file and into the actual property without running the logic
  # twice.
  rules = templatefile("${path.module}/rules.tfjson", {
    ns_cpcode_name     = var.ns_cpcode_name
    ns_cpcode_id       = parseint(replace(var.ns_cpcode_id, "cpc_", ""), 10)
    amd_product        = var.amd_product
    amd_cpcode_name    = var.amd_cpcode_name
    amd_cpcode_id      = parseint(replace(data.akamai_cp_code.amd.id, "cpc_", ""), 10)
    ns_download_domain = var.ns_download_domain
  })
}

resource "akamai_edge_hostname" "default" {
  product       = "prd_${var.amd_product}"
  contract      = data.akamai_contract.default.id
  group         = data.akamai_group.default.id
  edge_hostname = var.edge_hostname
}

# Generate the rule tree into a local file; this simplifies
# debugging the generated configuration and also allows
# easy re-use of the JSON in other tools such as Sandbox.
resource "local_file" "rules" {
  filename = "local/rules.json"

  content = local.rules
}

resource "akamai_property" "default" {
  name     = var.conf_name
  contact  = var.email
  product  = "prd_${var.amd_product}"
  contract = data.akamai_contract.default.id
  group    = data.akamai_group.default.id

  hostnames = {
    (var.hostname) = akamai_edge_hostname.default.edge_hostname
  }

  rule_format = "latest"
  rules       = local.rules
}

resource "akamai_property_activation" "staging" {
  property = akamai_property.default.id
  network  = "STAGING"
  activate = true
  contact  = var.email
}
