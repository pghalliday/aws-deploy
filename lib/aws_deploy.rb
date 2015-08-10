relative_require 'aws_deploy/config'
require 'aws-sdk'
require 'json'
require 'pathname'

CREDENTIALS_FILE = 'credentials.json'
CLOUDFORMATION_DIR = 'cloudformation'
OPSWORKS_STACKS_DIR = 'opsworks_stacks'
COOKBOOKS_DIR = 'cookbooks'
MAIN_CLOUDFORMATION_JSON = 'main.json'

class AwsDeploy

  def initialize (dir, target)
    @dir = dir
    @target = target
    credentials_file = File.join(@dir, CREDENTIALS_FILE)
    credentials = JSON.parse(File.read(credentials_file))
    @credentials = Aws::Credentials.new(
      credentials['accessKeyId'],
      credentials['secretAccessKey']
    )
    @config = AwsDeploy::Config.new @dir, @target, @credentials
  end

  def deploy
    s3 = Aws::S3::Client.new(
      region: @config.region,
      signature_version: 'v4',
      credentials: @credentials
    )
    cloudformation = Aws::CloudFormation::Client.new(
      region: @config.region,
      credentials: @credentials
    )
    config_remote = "#{@target}/#{@config.name}/config.json"
    response = s3.put_object(
      bucket: @config.s3_bucket,
      key: config_remote,
      body: @config.config.to_json,
      server_side_encryption: 'aws:kms',
      ssekms_key_id: @config.kms_key[@target]
    )
    if @config.cloudformation
      cloudformation_dir = File.join(dir, CLOUDFORMATION_DIR)
      cloudformation_pathname = Pathname.new cloudformation_dir
      cloudformation_remote_root_relative = "#{@target}/#{@config.name}/cloudformation"
      opsworks_stacks_remote_root_relative = "#{@target}/#{@config.name}/opsworks_stacks"
      Dir.glob(File.join(cloudformation_dir, '**/*.json')) do |template|
        template_pathname = Pathname.new template
        template_json = File.read template
        response = cloudformation.validate_template(
          template_body: template_json
        )
        response = s3.put_object(
          bucket: @config.s3_bucket,
          key: "#{cloudformation_remote_root_relative}/#{template_pathname.relative_path_from(cloudformation_pathname)}",
          body: template,
        )
      end
      cloudformation_remote_root = "https://s3.amazonaws.com/#{@config.s3_bucket}/#{cloudformation_remote_root_relative}"
      template_url = "#{cloudformation_remote_root}/#{MAIN_CLOUDFORMATION_JSON}"
      capabilities = ["CAPABILITY_IAM"]
      cloudformation_parameters = @config.cloudformation.parameters
      main = JSON.parse File.read(File.join(cloudformation_dir, MAIN_CLOUDFORMATION_JSON))
      main_keys = main['Parameters'].keys
      parameters = main_keys.map do |key|
        case key
        when 'name'
          {
            parameter_key: key,
            parameter_value: @config.name,
            use_previous_value: false
          }
        when 's3Bucket'
          {
            parameter_key: key,
            parameter_value: @config.s3_bucket,
            use_previous_value: false
          }
        when 'region'
          {
            parameter_key: key,
            parameter_value: @config.region,
            use_previous_value: false
          }
        when 'config'
          {
            parameter_key: key,
            parameter_value: config_remote,
            use_previous_value: false
          }
        when 'kmsKey'
          {
            parameter_key: key,
            parameter_value: @config.kms_key[@target],
            use_previous_value: false
          }
        when 'cloudformationRoot'
          {
            parameter_key: key,
            parameter_value: cloudformation_remote_root,
            use_previous_value: false
          }
        when 'opsworksStacksRootRelative'
          {
            parameter_key: key,
            parameter_value: opsworks_stacks_remote_root_relative,
            use_previous_value: false
          }
        else
          {
            parameter_key: key,
            parameter_value: cloudformation_parameters[key],
            use_previous_value: false
          }
        end
      end
      begin
        response = cloudformation.update_stack(
          stack_name: "#{@config.prefix}-#{@config.name}-#{@target}",
          template_url: template_url,
          capabilities: capabilities,
          parameters: parameters
        )
      rescue Aws::CloudFormation::Errors::ValidationError
        response = cloudformation.create_stack(
          stack_name: "#{@config.prefix}-#{@config.name}-#{@target}",
          template_url: template_url,
          capabilities: capabilities,
          on_failure: "DO_NOTHING",
          parameters: parameters
        )
      end
    end
  end

end
