require_relative 'formatron/config'
require_relative 'formatron_util/tar'
require 'aws-sdk'
require 'json'
require 'pathname'

VENDOR_DIR = 'vendor'
CREDENTIALS_FILE = 'credentials.json'
CLOUDFORMATION_DIR = 'cloudformation'
OPSWORKS_DIR = 'opsworks'
MAIN_CLOUDFORMATION_JSON = 'main.json'

include FormatronUtil::Tar

class Formatron

  def initialize (dir, target)
    @dir = dir
    @target = target
    credentials_file = File.join(@dir, CREDENTIALS_FILE)
    credentials = JSON.parse(File.read(credentials_file))
    @credentials = Aws::Credentials.new(
      credentials['accessKeyId'],
      credentials['secretAccessKey']
    )
    @config = Formatron::Config.new @dir, @target, @credentials
  end

  def deploy
    s3 = Aws::S3::Client.new(
      region: @config.region,
      signature_version: 'v4',
      credentials: @credentials
    )
    config_remote = "#{@target}/#{@config.name}/config.json"
    response = s3.put_object(
      bucket: @config.s3_bucket,
      key: config_remote,
      body: @config.config.to_json,
      server_side_encryption: 'aws:kms',
      ssekms_key_id: @config.kms_key
    )
    opsworks_dir = File.join(@dir, OPSWORKS_DIR)
    opsworks_s3_key = "#{@target}/#{@config.name}/opsworks"
    if File.directory?(opsworks_dir)
      vendor_dir = File.join(@dir, VENDOR_DIR)
      FileUtils.rm_rf vendor_dir
      Dir.glob(File.join(opsworks_dir, '*')).each do |stack|
        if File.directory?(stack)
          stack_name = File.basename(stack)
          stack_vendor_dir = File.join(vendor_dir, stack_name)
          FileUtils.mkdir_p stack_vendor_dir
          %x(berks vendor -b #{File.join(stack, 'Berksfile')} #{stack_vendor_dir})
          fail "failed to vendor cookbooks for opsworks stack: #{stack_name}" unless $?.success?
          response = s3.put_object(
            bucket: @config.s3_bucket,
            key: "#{opsworks_s3_key}/#{stack_name}.tar.gz",
            body: gzip(tar(stack_vendor_dir))
          )
        end
      end
    end
    if @config._cloudformation
      cloudformation = Aws::CloudFormation::Client.new(
        region: @config.region,
        credentials: @credentials
      )
      cloudformation_dir = File.join(@dir, CLOUDFORMATION_DIR)
      cloudformation_pathname = Pathname.new cloudformation_dir
      cloudformation_s3_key= "#{@target}/#{@config.name}/cloudformation"
      Dir.glob(File.join(cloudformation_dir, '**/*.json')) do |template|
        template_pathname = Pathname.new template
        template_json = File.read template
        response = cloudformation.validate_template(
          template_body: template_json
        )
        response = s3.put_object(
          bucket: @config.s3_bucket,
          key: "#{cloudformation_s3_key}/#{template_pathname.relative_path_from(cloudformation_pathname)}",
          body: template_json,
        )
      end
      cloudformation_s3_root_url = "https://s3.amazonaws.com/#{@config.s3_bucket}/#{cloudformation_s3_key}"
      template_url = "#{cloudformation_s3_root_url}/#{MAIN_CLOUDFORMATION_JSON}"
      capabilities = ["CAPABILITY_IAM"]
      cloudformation_parameters = @config._cloudformation.parameters
      main = JSON.parse File.read(File.join(cloudformation_dir, MAIN_CLOUDFORMATION_JSON))
      main_keys = main['Parameters'].keys
      parameters = main_keys.map do |key|
        case key
        when 'formatronName'
          {
            parameter_key: key,
            parameter_value: @config.name,
            use_previous_value: false
          }
        when 'formatronPrefix'
          {
            parameter_key: key,
            parameter_value: @config.prefix,
            use_previous_value: false
          }
        when 'formatronS3Bucket'
          {
            parameter_key: key,
            parameter_value: @config.s3_bucket,
            use_previous_value: false
          }
        when 'formatronRegion'
          {
            parameter_key: key,
            parameter_value: @config.region,
            use_previous_value: false
          }
        when 'formatronKmsKey'
          {
            parameter_key: key,
            parameter_value: @config.kms_key,
            use_previous_value: false
          }
        when 'formatronConfig'
          {
            parameter_key: key,
            parameter_value: config_remote,
            use_previous_value: false
          }
        when 'formatronCloudformationS3key'
          {
            parameter_key: key,
            parameter_value: cloudformation_s3_key,
            use_previous_value: false
          }
        when 'formatronOpsworksS3Key'
          {
            parameter_key: key,
            parameter_value: opsworks_s3_key,
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
        response = cloudformation.create_stack(
          stack_name: "#{@config.prefix}-#{@config.name}-#{@target}",
          template_url: template_url,
          capabilities: capabilities,
          on_failure: "DO_NOTHING",
          parameters: parameters
        )
      rescue Aws::CloudFormation::Errors::AlreadyExistsException
        begin
          response = cloudformation.update_stack(
            stack_name: "#{@config.prefix}-#{@config.name}-#{@target}",
            template_url: template_url,
            capabilities: capabilities,
            parameters: parameters
          )
        rescue Aws::CloudFormation::Errors::ValidationError => error
          fail error unless error.message.eql?('No updates are to be performed.')
        end
      end
    end
  end

end
