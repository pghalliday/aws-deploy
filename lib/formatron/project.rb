require 'formatron/config'
require 'formatron/dependency'
require 'formatron/aws'
require 'formatron/cloudformation'
require 'formatron/formatronfile'
require 'formatron/opscode'

class Formatron
  # The Formatron project loader
  class Project
    attr_reader :config, :cloudformation, :opscode

    FORMATRON_FILE = 'Formatronfile'
    CONFIG_DIR = 'config'
    CREDENTIALS_JSON = 'credentials.json'
    CLOUDFORMATION_DIR = 'cloudformation'

    def initialize(dir, target)
      @dir = dir
      @target = target
      _create_aws
      _load_formatronfile
      _create_config
      _create_cloudformation if _has_cloudformation_stack
      _create_opscode
    end

    def _create_aws
      @aws = Formatron::Aws.new(
        File.join(@dir, CREDENTIALS_JSON)
      )
    end

    def _load_formatronfile
      _create_formatronfile
      @name = @formatronfile.name
      @s3_bucket = @formatronfile.s3_bucket
      @prefix = @formatronfile.prefix
      @kms_key = @formatronfile.kms_key
    end

    def _create_formatronfile
      @formatronfile = Formatron::Formatronfile.new(
        File.join(@dir, FORMATRON_FILE)
      )
    end

    def _has_cloudformation_stack
      cloudformation_dir = File.join(@dir, CLOUDFORMATION_DIR)
      File.directory?(cloudformation_dir)
    end

    def _create_config
      @config = Formatron::Config.new(
        _config_params,
        File.join(@dir, CONFIG_DIR),
        _dependencies,
        _has_cloudformation_stack
      )
    end

    def _config_params
      {
        name: @name,
        target: @target,
        s3_bucket: @s3_bucket,
        prefix: @prefix,
        kms_key: @kms_key
      }
    end

    def _dependencies
      @formatronfile.depends.map do |dependency|
        Formatron::Dependency.new(
          @aws,
          name: dependency,
          target: @target,
          s3_bucket: @s3_bucket,
          prefix: @prefix
        )
      end
    end

    def _create_cloudformation
      @cloudformation = Formatron::Cloudformation.new(
        @config, @formatronfile.cloudformation
      )
    end

    def _create_opscode
      opscode = @formatronfile.opscode
      @opscode = Formatron::Opscode.new(
        @config, opscode
      ) unless opscode.nil?
    end

    private(
      :_create_aws,
      :_load_formatronfile,
      :_create_formatronfile,
      :_has_cloudformation_stack,
      :_create_config,
      :_config_params,
      :_dependencies,
      :_create_cloudformation,
      :_create_opscode
    )
  end
end