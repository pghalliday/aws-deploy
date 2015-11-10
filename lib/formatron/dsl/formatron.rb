require_relative 'formatron/global'
require_relative 'formatron/dependency'
require_relative 'formatron/vpc'
require 'formatron/util/dsl'

class Formatron
  class DSL
    # formatron top level DSL object
    class Formatron
      extend Util::DSL
      dsl_initialize_block
      dsl_property :name
      dsl_property :bucket
      dsl_block :global, 'Global'
      dsl_hash :dependency, 'Dependency'
      dsl_hash :vpc, 'VPC'
    end
  end
end
