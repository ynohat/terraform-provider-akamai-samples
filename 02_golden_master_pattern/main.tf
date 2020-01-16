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

variable "master_property" {
  type        = string
  description = "Name of the master Akamai configuration file"
}

variable "master_version" {
  type        = string
  description = "Version of the master Akamai configuration file (version number or one of latest, production, staging)"
}

variable "property_name" {
  type        = string
  description = "Name of the slave Akamai configuration file"
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

variable "product" {
  type        = string
  description = "Product"
}

variable "staging" {
  type        = bool
  default = true
  description = "Activate in staging"
}

variable "production" {
  type        = bool
  default = false
  description = "Activate in production"
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

data "external" "master_rules" {
    program = ["${path.module}/get_rules.py"]

    query = {
        edgerc = var.edgerc
        section = var.edgerc_papi
        property = var.master_property
        version = var.master_version
    }
}

resource "akamai_edge_hostname" "default" {
  product       = "prd_${var.product}"
  contract      = data.akamai_contract.default.id
  group         = data.akamai_group.default.id
  edge_hostname = var.edge_hostname
}

resource "akamai_property" "default" {
  name     = var.property_name
  contact  = var.email
  product  = "prd_${var.product}"
  contract = data.akamai_contract.default.id
  group    = data.akamai_group.default.id

  hostnames = {
    (var.hostname) = akamai_edge_hostname.default.edge_hostname
  }

  rule_format = "latest"
  rules       = data.external.master_rules.result.tree
}

resource "akamai_property_activation" "staging" {
  property = akamai_property.default.id
  network  = "STAGING"
  activate = var.staging
  contact  = var.email
}

resource "akamai_property_activation" "production" {
  property = akamai_property.default.id
  network  = "PRODUCTION"
  activate = var.production
  contact  = var.email
}
