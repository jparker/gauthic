module Gauthic
  class SharedContact
    class Organization < AbstractNode
      def_attributes :orgName, :orgDepartment, :orgTitle
    end
  end
end
