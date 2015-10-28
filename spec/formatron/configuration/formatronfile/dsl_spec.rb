require 'spec_helper'
require 'formatron/configuration/formatronfile/dsl'

describe Formatron::Configuration::Formatronfile::DSL do
  include FakeFS::SpecHelpers

  file = 'Formatronfile'
  target = 'target'
  config = {}

  before(:each) do
    File.write(
      file,
      <<-EOH.gsub(/^ {8}/, '')
        name 'name'
        bucket 'bucket'
        bootstrap do
          'bootstrap'
        end
      EOH
    )
    @dsl = Formatron::Configuration::Formatronfile::DSL.new(
      target,
      config,
      file
    )
  end

  describe '#bootstrap' do
    it 'should set the bootstrap property' do
      expect(@dsl.bootstrap.call).to eql 'bootstrap'
    end
  end

  describe '#name' do
    it 'should set the name property' do
      expect(@dsl.name).to eql 'name'
    end
  end

  describe '#bucket' do
    it 'should set the bucket property' do
      expect(@dsl.bucket).to eql 'bucket'
    end
  end
end