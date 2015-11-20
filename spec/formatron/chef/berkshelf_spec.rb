require 'spec_helper'
require 'formatron/chef/berkshelf'

class Formatron
  # rubocop:disable Metrics/ClassLength
  class Chef
    describe Berkshelf do
      before(:each) do
        @config = 'config'
        @tempfile = instance_double('Tempfile')
        allow(@tempfile).to receive(:write)
        allow(@tempfile).to receive(:close)
        allow(@tempfile).to receive(:unlink)
        allow(@tempfile).to receive(:path) { @config }
        @tempfile_class = class_double('Tempfile').as_stubbed_const
        allow(@tempfile_class).to receive(:new) { @tempfile }
        @keys = instance_double 'Formatron::Chef::Keys'
        @chef_server_url = 'chef_server_url'
        @username = 'username'
        @user_key = 'user_key'
        allow(@keys).to receive(:user_key) { @user_key }
        @ssl_verify = 'ssl_verify'
        @berkshelf = Berkshelf.new(
          keys: @keys,
          chef_server_url: @chef_server_url,
          username: @username,
          ssl_verify: @ssl_verify
        )
        @berkshelf.init
      end

      describe '#init' do
        it 'should create a config file' do
          expect(@tempfile_class).to have_received(:new).once.with(
            'formatron-berkshelf-'
          )
          expect(@tempfile).to have_received(:write).once.with(
            <<-EOH.gsub(/^ {14}/, '')
              {
                "chef": {
                  "chef_server_url": "#{@chef_server_url}",
                  "node_name": "#{@username}",
                  "client_key": "#{@user_key}"
                },
                "ssl": {
                  "verify": #{@ssl_verify}
                }
              }
            EOH
          )
          expect(@tempfile).to have_received :close
        end
      end

      describe '#unlink' do
        before(:each) do
          @berkshelf.unlink
        end

        it 'should delete the Berkshelf config file' do
          expect(@tempfile).to have_received(:unlink).with(no_args).once
        end
      end

      describe '#upload' do
        before :each do
          @cookbook = 'cookbook'
          @environment = 'environment'
          @shell = class_double(
            'Formatron::Util::Shell'
          ).as_stubbed_const
        end

        context 'when the berks install fails' do
          before(:each) do
            allow(@shell).to receive(:exec).with(
              "berks install -b #{@cookbook}/Berksfile"
            ) { false }
          end

          it 'should fail' do
            expect do
              @berkshelf.upload(
                cookbook: @cookbook, environment: @environment
              )
            end.to raise_error(
              'failed to download cookbooks for opscode ' \
              "environment: #{@environment}"
            )
          end
        end

        context 'when the berks upload fails' do
          before(:each) do
            allow(@shell).to receive(:exec).with(
              "berks install -b #{@cookbook}/Berksfile"
            ) { true }
            allow(@shell).to receive(:exec).with(
              "berks upload -c #{@config} -b #{@cookbook}/Berksfile"
            ) { false }
          end

          it 'should fail' do
            expect do
              @berkshelf.upload(
                cookbook: @cookbook, environment: @environment
              )
            end.to raise_error(
              'failed to upload cookbooks for opscode ' \
              "environment: #{@environment}"
            )
          end
        end

        context 'when the berks apply fails' do
          before(:each) do
            allow(@shell).to receive(:exec).with(
              "berks install -b #{@cookbook}/Berksfile"
            ) { true }
            allow(@shell).to receive(:exec).with(
              "berks upload -c #{@config} -b #{@cookbook}/Berksfile"
            ) { true }
            allow(@shell).to receive(:exec).with(
              "berks apply #{@environment} -c #{@config} " \
              "-b #{@cookbook}/Berksfile.lock"
            ) { false }
          end

          it 'should fail' do
            expect do
              @berkshelf.upload(
                cookbook: @cookbook, environment: @environment
              )
            end.to raise_error(
              'failed to apply cookbooks to opscode ' \
              "environment: #{@environment}"
            )
          end
        end

        context 'when all the berks commands succeed' do
          before(:each) do
            allow(@shell).to receive(:exec) { true }
            @berkshelf.upload(
              cookbook: @cookbook, environment: @environment
            )
          end

          it 'should install cookbooks' do
            expect(@shell).to have_received(:exec).with(
              "berks install -b #{@cookbook}/Berksfile"
            ).once
          end

          it 'should upload cookbooks' do
            expect(@shell).to have_received(:exec).with(
              "berks upload -c #{@config} " \
              "-b #{@cookbook}/Berksfile"
            ).once
          end

          it 'should apply cookbooks to the environment' do
            expect(@shell).to have_received(:exec).with(
              "berks apply #{@environment} -c #{@config} " \
              "-b #{@cookbook}/Berksfile.lock"
            ).once
          end
        end
      end
    end
  end
  # rubocop:enable Metrics/ClassLength
end