module Gauthic
  class SharedContact
    class RecordNotFound < StandardError
    end

    class RecordNotSaved < StandardError
    end

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

    class Name < AbstractNode
      def_attributes :namePrefix, :givenName, :additionalName, :familyName, :nameSuffix
    end

    class Organization < AbstractNode
      def_attributes :orgName, :orgDepartment, :orgTitle
    end

    class Address < AbstractNode
      def_attributes :agent, :housename, :street, :pobox, :neighborhood, :city, :region, :postcode, :country
      def label()         root['label'] end
      def label=(value)   root['label'] = value end
    end

    class Email < AbstractNode
      def label()         root['label'] end
      def label=(value)   root['label'] = value end
      def address()       root['address'] end
      def address=(value) root['address'] = value end
    end

    class Phone < AbstractNode
      def label()         root['label'] end
      def label=(value)   root['label'] = value end
      def number()        root.content end
      def number=(value)  root.content = value end
    end

    attr_accessor :document

    def initialize(attrs_or_xml=nil)
      if attrs_or_xml.is_a?(Hash)
        self.document = default_document
        attrs_or_xml.each do |key, value|
          send("#{key}=", value)
        end
      else
        self.xml = attrs_or_xml
      end
    end

    def id
      tag = document.at_xpath('//xmlns:link[@rel="self"]')
      tag.attribute('href').value unless tag.nil?
    end

    def new_record?
      id.nil?
    end

    def save(debug=false)
      if new_record?
        create_new_record(debug)
      else
        update_existing_record(debug)
      end
    end

    def update_attributes(attributes = {})
      attributes.each do |key, value|
        send("#{key}=", value)
      end
      save
    end

    def destroy
      url = document.at_xpath('//xmlns:link[@rel="edit"]').attribute('href').value
      result = session.delete(url, :headers => {'If-Match' => '*'})
      if Net::HTTPSuccess === result
        return true
      else
        raise Gauthic::SharedContact::RecordNotSaved, result.body
      end
    end

    def to_xml
      document.to_xml
    end
    alias to_s to_xml

    def self.connect!(email, password)
      @session = Gauthic::Session.new(email, password, 'cp')
    end

    def self.disconnect!
      remove_instance_variable :@session
    end

    def self.session
      raise Gauthic::Session::NoActiveSession, 'start new session by calling connect!' unless defined?(@session)
      @session
    end

    def self.find(id)
      result = session.get(id)
      if Net::HTTPSuccess === result
        new(result.body)
      else
        raise Gauthic::SharedContact::RecordNotFound, result.body
      end
    end

    def session
      self.class.session
    end

    def name
      node = document.at_xpath('//gd:name')
      if node.nil?
        node = Nokogiri::XML::Node.new('name', document)
        node.namespace = namespace('gd')
        document.root << node
      end
      Name.new(node)
    end

    def name=(parts)
      parts.each { |attr, value| name.send("#{attr}=", value) }
    end

    def organization
      node = document.at_xpath('//gd:organization')
      if node.nil?
        node = Nokogiri::XML::Node.new('organization', document)
        node.namespace = namespace('gd')
        document.root << node
      end
      Organization.new(node)
    end

    def organization=(parts)
      parts.each { |attr, value| organization.send("#{attr}=", value) }
    end

    def addresses
      document.xpath('//gd:structuredPostalAddress').map { |node| Address.new(node) }
    end

    def addresses=(addresses)
      addresses.map do |parts|
        node = Nokogiri::XML::Node.new('structuredPostalAddress', document)
        node.namespace = namespace('gd')
        document.root << node
        Address.new(node, parts)
      end
    end

    def emails
      document.xpath('//gd:email').map { |node| Email.new(node) }
    end

    def emails=(addresses)
      addresses.map do |parts|
        node = Nokogiri::XML::Node.new('email', document)
        node.namespace = namespace('gd')
        document.root << node
        Email.new(node, parts)
      end
    end

    def phones
      document.xpath('//gd:phoneNumber').map { |node| Phone.new(node) }
    end

    def phones=(numbers)
      numbers.map do |parts|
        node = Nokogiri::XML::Node.new('phoneNumber', document)
        node.namespace = namespace('gd')
        document.root << node
        Phone.new(node, parts)
      end
    end

    private
    def default_document
      Nokogiri::XML::Builder.new do |builder|
        builder.entry('xmlns' => 'http://www.w3.org/2005/Atom', 'xmlns:gd' => schema) do
          builder.category('scheme' => schema('#kind'), 'term' => schema('/contact/2008#contact'))
        end
      end.doc
    end

    def namespace(prefix)
      document.root.namespace_definitions.detect {|ns| ns.prefix == prefix}
    end

    def schema(suffix=nil)
      'http://schemas.google.com' + (suffix.nil? ? '/g/2005' : (suffix =~ /^#/ ? "/g/2005#{suffix}" : suffix))
    end

    def create_new_record(debug=false)
      url = "https://www.google.com/m8/feeds/contacts/#{session.domain}/full"
      result = session.post(url, :headers => {'Content-Type' => 'application/atom+xml'}, :body => to_xml)
      if Net::HTTPSuccess === result
        self.xml = result.body
        return debug ? result.body : true
      else
        raise Gauthic::SharedContact::RecordNotSaved, result.body
      end
    end

    def update_existing_record(debug=false)
      url = document.at_xpath('//xmlns:link[@rel="edit"]').attribute('href').value
      result = session.put(url, :headers => {'Content-Type' => 'application/atom+xml'}, :body => to_xml)
      if Net::HTTPSuccess === result
        self.xml = result.body
        return debug ? result.body : true
      else
        raise Gauthic::SharedContact::RecordNotSaved, result.body
      end
    end

    def xml=(xml)
      self.document = Nokogiri.XML(xml)
      self.document = default_document if document.root.nil?
    end
  end
end
