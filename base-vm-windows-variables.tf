variable "vpc_id" {
  description = "ID of VPC to target for deployment"
}

variable "instance_profile" {
  description = "Name of the EC2 instance profile to associate with the VM"
}

variable "join_ad" {
  description = "Flag to indicate if the VM should be joined to a domain (or not)"
  default = false
}

variable "ad_join_doc_name" {
  description = "Name of the Directory Service SSM document to use for automatic domain integration"
  default = ""
}

variable "instance_subnet" {
  description = "Target subnet for attachment of instance"
}

variable "ami_owners" {
  description = "IDs or aliases of the owning organization used when searching AMIs"
  default = [ "self", "amazon", "aws-marketplace" ] 
}

variable "ami_name" {
  description = "An AMI name (wildcards supported) for selecting the base image for the VM"
  default     = "Windows_Server-2016-English-Full-Base*"
}

variable "root_volume_size" {
  description = "Size in GB to allocate to OS drive"
  default     = 45
}

variable "instance_type" {
  description = "Required instance type for server"
  default     = "t3.small"
}

variable "host_name_prefix" {
  description = "Prefix value to use in Hostname metadata tag (e.g. CIS1A)"
  default     = "WINDOWS1A"
}

variable "aws_subnet_az" {
  description = "Availability Zone for deployment (A/B/...)"
  default     = "A"
}

variable "host_description" {
  description = "Prefix description to use in Name metadata tag (e.g. Cinegy Identity Service (CIS) 01)"
  default     = "Default Windows VM"
}

variable "attach_data_volume" {
  description = "Attach a secondary data volume to the host (default false)"
  default     = false
}

variable "data_volume_size" {
  description = "Size of any secondary data volume (default 30GB)"
  default     = 30
}

variable "allow_open_rdp_access" {
  description = "Allow world-access to RDP ports (default false)"
  default     = false
}

variable "allow_all_internal_traffic" {
  description = "Allow all internal network traffic (default false)"
  default     = false
}

variable "allow_media_udp_ports_externally" {
  description = "Opens UDP media streaming ports for external access (default false)"
  default     = false
}

variable "create_external_dns_reference" {
  description = "Create a DNS entry for the public IP of the VM inside the default Route53 zone (default false)"
  default     = false
}

variable "create_internal_dns_reference" {
  description = "Create a DNS entry for the private IP of the VM inside the internal Route53 zone (default false)"
  default     = false
}

variable "route53_zone_name" {
  description = "Name of Route53 zone for use in creating external DNS entries"
  default = ""
}

variable "internal_route53_zone_name" {
  description = "Name of Route53 zone for use in creating internal DNS entries"
  default = ""
}

variable "user_data_script_extension" {
  description = "Extended element to attach to core user data script. Default installs Cinegy Powershell Modules and renames host to match metadata name tag."
  default     = <<EOF
  Install-CinegyPowershellModules
  Install-DefaultPackages
  RenameHost
EOF
}

variable "tenancy" {
  description = "Instance tenancy mode (can be default, dedicated or host)"
  default     = "default"
}

variable "security_groups" {
  description = "Array of security group IDs to attach to the instance"
  default = []
}
