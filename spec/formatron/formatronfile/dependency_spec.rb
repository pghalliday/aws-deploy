require 'spec_helper'
require 'formatron/formatronfile/dependency_spec'

class Formatron
  # namespacing for tests
  class Formatronfile
    describe Dependency do
      extend DSLTest
      dsl_before_hash
    end
  end
end
