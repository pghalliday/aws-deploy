require 'formatron/aws'
require 'formatron/configuration'
require 'formatron/s3_path'
require 'formatron/s3_configuration'
require 'formatron/s3_chef_server_cert'
require 'formatron/s3_cloud_formation_template'
require 'formatron/cloud_formation_stack'
require 'formatron/chef_instances'

# manages a Formatron stack
# rubocop:disable Metrics/ClassLength
class Formatron
  def initialize(credentials, directory)
    @aws = AWS.new credentials
    @configuration = Configuration.new @aws, directory
  end

  def targets
    @configuration.targets
  end

  def protected?(target)
    @configuration.protected? target
  end

  # rubocop:disable Metrics/MethodLength
  def deploy(target)
    kms_key = @configuration.kms_key target
    bucket = @configuration.bucket target
    name = @configuration.name target
    config = @configuration.config target
    chef_server_ssl_cert = @configuration.chef_server_ssl_cert target
    chef_server_ssl_key = @configuration.chef_server_ssl_key target
    cloud_formation_template = @configuration.cloud_formation_template target
    _deploy_chef_server_cert(
      kms_key,
      bucket,
      name,
      target,
      chef_server_ssl_cert,
      chef_server_ssl_key
    ) unless chef_server_ssl_cert.nil?
    _deploy_configuration kms_key, bucket, name, target, config
    _deploy_template kms_key, bucket, name, target, cloud_formation_template
    _deploy_stack bucket, name, target
  end
  # rubocop:enable Metrics/MethodLength

  def provision(target)
    ChefInstances.provision(
      aws: @aws,
      configuration: @configuration,
      target: target
    )
  end

  # rubocop:disable Metrics/MethodLength
  def destroy(target)
    bucket = @configuration.bucket target
    name = @configuration.name target
    chef_server_ssl_cert = @configuration.chef_server_ssl_cert target
    _destroy_configuration bucket, name, target
    _destroy_chef_server_cert(
      bucket,
      name,
      target
    ) unless chef_server_ssl_cert.nil?
    _destroy_template bucket, name, target
    _destroy_stack name, target
    _destroy_instances target
  end
  # rubocop:enable Metrics/MethodLength

  def _deploy_configuration(kms_key, bucket, name, target, config)
    S3Configuration.deploy(
      aws: @aws,
      kms_key: kms_key,
      bucket: bucket,
      name: name,
      target: target,
      config: config
    )
  end

  # rubocop:disable Metrics/ParameterLists
  def _deploy_chef_server_cert(kms_key, bucket, name, target, cert, key)
    S3ChefServerCert.deploy(
      aws: @aws,
      kms_key: kms_key,
      bucket: bucket,
      name: name,
      target: target,
      cert: cert,
      key: key
    )
  end
  # rubocop:enable Metrics/ParameterLists

  def _deploy_template(kms_key, bucket, name, target, cloud_formation_template)
    S3CloudFormationTemplate.deploy(
      aws: @aws,
      kms_key: kms_key,
      bucket: bucket,
      name: name,
      target: target,
      cloud_formation_template: cloud_formation_template
    )
  end

  def _deploy_stack(bucket, name, target)
    CloudFormationStack.deploy(
      aws: @aws,
      bucket: bucket,
      name: name,
      target: target
    )
  end

  def _destroy_configuration(bucket, name, target)
    S3Configuration.destroy(
      aws: @aws,
      bucket: bucket,
      name: name,
      target: target
    )
  end

  def _destroy_chef_server_cert(bucket, name, target)
    S3ChefServerCert.destroy(
      aws: @aws,
      bucket: bucket,
      name: name,
      target: target
    )
  end

  def _destroy_template(bucket, name, target)
    S3CloudFormationTemplate.destroy(
      aws: @aws,
      bucket: bucket,
      name: name,
      target: target
    )
  end

  def _destroy_stack(name, target)
    CloudFormationStack.destroy(
      aws: @aws,
      name: name,
      target: target
    )
  end

  def _destroy_instances(target)
    ChefInstances.destroy(
      aws: @aws,
      configuration: @configuration,
      target: target
    )
  end

  private(
    :_deploy_configuration,
    :_deploy_template,
    :_deploy_stack,
    :_destroy_configuration,
    :_destroy_template,
    :_destroy_stack,
    :_destroy_instances
  )
end
# rubocop:enable Metrics/ClassLength
