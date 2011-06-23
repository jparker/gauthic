module Gauthic
  class SharedContact
    class Address < AbstractNode
      def_attributes :agent, :housename, :street, :pobox, :neighborhood, :city, :region, :postcode, :country
      def label()         root['label'] end
      def label=(value)   root['label'] = value end
    end
  end
end
