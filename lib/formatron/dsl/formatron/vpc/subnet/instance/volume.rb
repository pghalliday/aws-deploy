require 'formatron/util/dsl'

class Formatron
  class DSL
    class Formatron
      class VPC
        class Subnet
          class Instance
            # Instance volume attachments
            class Volume
              extend Util::DSL
              dsl_initialize_block
              dsl_property :device
              dsl_property :size
              dsl_property :type
              dsl_property :iops
            end
          end
        end
      end
    end
  end
end
