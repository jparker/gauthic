module Gauthic
  class SharedContact
    class Name < AbstractNode
      def_attributes :namePrefix, :givenName, :additionalName, :familyName, :nameSuffix, :fullName
    end
  end
end
