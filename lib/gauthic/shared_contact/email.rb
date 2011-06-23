module Gauthic
  class SharedContact
    class Email < AbstractNode
      def label()         root['label'] end
      def label=(value)   root['label'] = value end
      def address()       root['address'] end
      def address=(value) root['address'] = value end
    end
  end
end
