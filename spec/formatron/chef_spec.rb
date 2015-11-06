require 'spec_helper'
require 'formatron/chef'

# namespacing for tests
# rubocop:disable Metrics/ClassLength
class Formatron
  describe Chef do
    before :each do
      @aws = instance_double 'Formatron::AWS'
      @name = 'name'
      @server_stack = 'server_stack'
      @hosted_zone_name = 'hosted_zone_name'
      @cookbook_name = 'cookbook'
      @cookbook = "directory/cookbooks/#{@cookbook_name}"
      @sub_domain = 'sub_domain'
      @hostname = "#{@sub_domain}.#{@hosted_zone_name}"
      @bastion_sub_domain = 'bastion_sub_domain'
      @bastion_hostname = "#{@bastion_sub_domain}.#{@hosted_zone_name}"
      @target = 'target'
      @bucket = 'bucket'
      @chef_sub_domain = 'chef_sub_domain'
      @organization = 'organization'
      @username = 'username'
      @ssl_verify = 'ssl_verify'
      @private_key = 'private_key'
      @chef_server_url = "https://#{@chef_sub_domain}.#{@hosted_zone_name}" \
                         "/organizations/#{@organization}"
      @cloud_formation = class_double(
        'Formatron::CloudFormation'
      ).as_stubbed_const
      @keys_class = class_double(
        'Formatron::Chef::Keys'
      ).as_stubbed_const
      @keys = instance_double 'Formatron::Chef::Keys'
      allow(@keys_class).to receive(:new) { @keys }
      @berkshelf_class = class_double(
        'Formatron::Chef::Berkshelf'
      ).as_stubbed_const
      @berkshelf = instance_double 'Formatron::Chef::Berkshelf'
      allow(@berkshelf_class).to receive(:new) do
        puts 'hello'
        @berkshelf
      end
      allow(@berkshelf).to receive(:upload)
      @knife_class = class_double(
        'Formatron::Chef::Knife'
      ).as_stubbed_const
      @knife = instance_double 'Formatron::Chef::Knife'
      allow(@knife_class).to receive(:new) { @knife }
      allow(@knife).to receive(:create_environment)
      allow(@knife).to receive(:bootstrap)
    end

    context 'when the Chef Server CloudFormation stack is not ready' do
      before :each do
        expect(@cloud_formation).to receive(:stack_ready!).once.with(
          aws: @aws,
          name: @server_stack,
          target: @target
        ) { fail 'not ready' }
      end

      it 'should error' do
        expect do
          @chef = Chef.new(
            aws: @aws,
            bucket: @bucket,
            name: @name,
            target: @target,
            username: @username,
            organization: @organization,
            ssl_verify: @ssl_verify,
            chef_sub_domain: @chef_sub_domain,
            private_key: @private_key,
            bastion_sub_domain: @bastion_sub_domain,
            hosted_zone_name: @hosted_zone_name,
            server_stack: @server_stack
          )
        end.to raise_error 'not ready'
      end
    end

    context 'when the Chef Server CloudFormation stack is ready' do
      before :each do
        expect(@cloud_formation).to receive(:stack_ready!).once.with(
          aws: @aws,
          name: @server_stack,
          target: @target
        )
        @chef = Chef.new(
          aws: @aws,
          bucket: @bucket,
          name: @name,
          target: @target,
          username: @username,
          organization: @organization,
          ssl_verify: @ssl_verify,
          chef_sub_domain: @chef_sub_domain,
          private_key: @private_key,
          bastion_sub_domain: @bastion_sub_domain,
          hosted_zone_name: @hosted_zone_name,
          server_stack: @server_stack
        )
      end

      it 'should download the chef keys' do
        expect(@keys_class).to have_received(:new).once.with(
          aws: @aws,
          bucket: @bucket,
          name: @server_stack,
          target: @target
        )
      end

      it 'should create a knife client' do
        expect(@knife_class).to have_received(:new).once.with(
          keys: @keys,
          chef_server_url: @chef_server_url,
          username: @username,
          organization: @organization,
          ssl_verify: @ssl_verify
        )
      end

      it 'should create a berkshelf client' do
        expect(@berkshelf_class).to have_received(:new).once.with(
          keys: @keys,
          chef_server_url: @chef_server_url,
          username: @username,
          ssl_verify: @ssl_verify
        )
      end

      describe '::provision' do
        context 'when the CloudFormation stack is not ready' do
          before :each do
            expect(@cloud_formation).to receive(:stack_ready!).once.with(
              aws: @aws,
              name: @name,
              target: @target
            ) { fail 'not ready' }
          end

          it 'should error' do
            expect do
              @chef.provision(
                sub_domain: @sub_domain,
                cookbook: @cookbook
              )
            end.to raise_error 'not ready'
          end
        end

        context 'when the CloudFormation stack is ready' do
          before :each do
            expect(@cloud_formation).to receive(:stack_ready!).once.with(
              aws: @aws,
              name: @name,
              target: @target
            )
            @chef.provision(
              sub_domain: @sub_domain,
              cookbook: @cookbook
            )
          end

          it 'should create the instance environments' do
            expect(@knife).to have_received(:create_environment).once.with(
              environment: @sub_domain
            )
          end

          it 'should deploy the instance cookbooks' do
            expect(@berkshelf).to have_received(:upload).once.with(
              environment: @sub_domain,
              cookbook: @cookbook
            )
          end

          it 'should bootstrap the instance' do
            expect(@knife).to have_received(:bootstrap).once.with(
              bastion_hostname: @bastion_hostname,
              environment: @sub_domain,
              cookbook: @cookbook_name,
              hostname: @hostname,
              private_key: @private_key
            )
          end
        end
      end

      describe '::destroy' do
        before :each do
          @chef.destroy(
            sub_domain: @sub_domain
          )
        end

        it 'should do something useful' do
          pending
          fail
        end
      end
    end
  end
end
# rubocop:enable Metrics/ClassLength