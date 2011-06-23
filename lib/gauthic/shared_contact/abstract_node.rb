module Gauthic
  class SharedContact
    class AbstractNode
      def initialize(root, attributes = {})
        self.root = root
        attributes.each { |attr, value| send("#{attr}=", value) }
      end

      class << self
        private
        def def_attributes(*attributes)
          attributes.each do |attribute|
            def_attribute(attribute)
          end
        end

        def def_attribute(attribute)
          class_eval <<-END, __FILE__, __LINE__
            def #{attribute}
              node = root.at_xpath(".//gd:#{attribute}")
              node.content if node
            end

            def #{attribute}=(value)
              node = root.at_xpath(".//gd:#{attribute}")
              if node.nil?
                node = Nokogiri::XML::Node.new('#{attribute}', root)
                node.namespace = root.namespace
                root << node
              end
              node.content = value
            end
          END
        end
      end

      private
      attr_accessor :root
    end
  end
end
