/*
data "aws_subnet_ids" "filtered_subnets" {
  vpc_id = var.vpc_id

  tags = {
    Tier = var.aws_subnet_tier
    AZ   = var.aws_subnet_az
  }
}
*/
data "template_file" "userdatascript" {
  template = file("${path.module}/conf/userdatascriptbase.ps1")
  vars = {
    injected_content = var.user_data_script_extension
  }
}

data "aws_ami" "latest_ami" {
  most_recent = true
  owners      = var.ami_owners

  filter {
    name   = "name"
    values = [var.ami_name]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

resource "aws_ssm_association" "domain_ssm" {
  count = var.join_ad ? 1 : 0
  name        = var.ad_join_doc_name
  instance_id = aws_instance.vm.id
}

resource "aws_ebs_volume" "data_volume" {
  availability_zone = "${var.aws_region}${lower(var.aws_subnet_az)}"
  size              = var.data_volume_size
  count             = var.attach_data_volume == true ? 1 : 0

  tags = {
    Name      = "${var.host_name_prefix}-${upper(var.environment_name)}-DATAVOL"
    Env       = var.environment_name
    App       = "${var.app_name}"
    CUSTOMER  = var.customer_tag
    Terraform = true
  }
}

resource "aws_volume_attachment" "data_volume" {
  device_name = "/dev/sdh"
  count       = var.attach_data_volume == true ? 1 : 0

  volume_id   = element(aws_ebs_volume.data_volume.*.id, count.index)
  instance_id = aws_instance.vm.id
}

resource "aws_instance" "vm" {
  ami                  = data.aws_ami.latest_ami.id
  key_name             = "terraform-key-${var.app_name}-${var.environment_name}"
  instance_type        = var.instance_type
  iam_instance_profile = var.instance_profile
  subnet_id            = var.instance_subnet //element(tolist(data.aws_subnet_ids.filtered_subnets.ids),0)
  get_password_data    = true
  tenancy              = var.tenancy
  user_data = format(
    "<powershell>%s</powershell>",
    data.template_file.userdatascript.rendered,
  )
  ebs_optimized = true

  root_block_device {
    volume_size = var.root_volume_size
  }

  vpc_security_group_ids = var.security_groups

  tags = {
    Name      = "${var.host_description} - ${upper(var.environment_name)}"
    Hostname  = "${var.host_name_prefix}-${upper(var.environment_name)}"
    Env       = var.environment_name
    App       = "${var.app_name}"
    CUSTOMER  = var.customer_tag
    Terraform = true
  }

  lifecycle {
    ignore_changes = [user_data,ami]
  }
}

/*
resource "aws_route53_record" "vm" {
  count   = var.create_external_dns_reference == true ? 1 : 0
  zone_id = var.shared_route53_zone_id
  name    = "${lower(var.host_name_prefix)}-${lower(var.environment_name)}.${var.shared_route53_zone_suffix}"
  type    = "A"
  ttl     = "60"
  records = [aws_instance.vm.public_ip]
}
*/
