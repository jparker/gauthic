require 'ostruct'

module Gauthic
  class SharedContact
    def self.connect!(email, password)
      @session = Gauthic::Session.new(email, password, 'cp')
    end

    def self.disconnect!
      remove_instance_variable :@session
    end

    def self.session
      raise NoActiveSession, 'start new session by calling connect!' unless defined?(@session)
      @session
    end

    def initialize(attrs_or_xml=nil)
      if attrs_or_xml.is_a?(Hash)
        self.document = default_document.doc
        attrs_or_xml.each do |key, value|
          send("#{key}=", value)
        end
      else
        self.document = Nokogiri.XML(attrs_or_xml)
      end
    end

    def to_xml
      document.to_xml
    end

    def session
      self.class.session
    end

    def name
      node = document.at_xpath('//gd:name')
      OpenStruct.new(node.element_children.inject({}) {|hsh, el| hsh[el.name] = el.content; hsh})
    end

    def name=(attributes)
      namespace = find_namespace(document, 'gd')
      parent = document.at_xpath('//gd:name')
      if parent.nil?
        parent = Nokogiri::XML::Node.new('name', document)
        parent.namespace = namespace
        document.root << parent
      else
        parent.children.remove
      end

      attributes.each do |key, value|
        node = Nokogiri::XML::Node.new(key.to_s, parent)
        node.namespace = namespace
        node.content = value
        parent << node
      end
    end

    def organization
      node = document.at_xpath('//gd:organization')
      OpenStruct.new(node.element_children.inject({}) {|hsh, el| hsh[el.name] = el.content; hsh})
    end

    def organization=(attributes)
      namespace = find_namespace(document, 'gd')
      parent = document.at_xpath('//gd:organization')
      if parent.nil?
        parent = Nokogiri::XML::Node.new('organization', document)
        parent.namespace = namespace
        document.root << parent
      else
        parent.children.remove
      end

      attributes.each do |key, value|
        node = Nokogiri::XML::Node.new(key.to_s, parent)
        node.namespace = namespace
        node.content = value
        parent << node
      end
    end

    def address
      addresses = document.xpath('//gd:structuredPostalAddress')
      addresses.map do |node|
        kids = node.element_children.inject({}) {|hsh, el| hsh[el.name] = el.content; hsh}
        OpenStruct.new(kids.merge(:label => node['label']))
      end
    end

    def address=(addresses)
      namespace = find_namespace(document, 'gd')
      document.xpath('//gd:structuredPostalAddress').remove
      addresses.each do |address|
        parent = Nokogiri::XML::Node.new('structuredPostalAddress', document)
        parent.namespace = namespace
        parent['label'] = address.delete(:label)
        document.root << parent

        address.each do |key, value|
          node = Nokogiri::XML::Node.new(key.to_s, parent)
          node.namespace = namespace
          node.content = value
          parent << node
        end
      end
    end

    def email
      nodes = document.xpath('//gd:email')
      nodes.map {|node| OpenStruct.new(:label => node['label'], :address => node['address'])}
    end

    def email=(addresses)
      namespace = find_namespace(document, 'gd')
      document.xpath('//gd:email').remove
      addresses.each do |email|
        node = Nokogiri::XML::Node.new('email', document)
        node.namespace = namespace
        node['label'] = email[:label]
        node['address'] = email[:address]
        document.root << node
      end
    end

    def phone
      nodes = document.xpath('//gd:phoneNumber')
      nodes.map {|node| OpenStruct.new(:label => node['label'], :number => node.content)}
    end

    def phone=(numbers)
      namespace = find_namespace(document, 'gd')
      document.xpath('//gd:phoneNumber').remove
      numbers.each do |phone|
        node = Nokogiri::XML::Node.new('phoneNumber', document)
        node.namespace = namespace
        node['label'] = phone[:label]
        node.content = phone[:number]
        document.root << node
      end
    end

    private
    attr_accessor :document

    def default_document
      Nokogiri::XML::Builder.new do |builder|
        builder.entry('xmlns:atom' => 'http://www.w3.org/2005/Atom', 'xmlns:gd' => schema) do
          # builder.document.root.namespace = find_namespace(builder.document, 'atom')
          builder['atom'].category('scheme' => schema('#kind'), 'term' => schema('/contact/2008#contact'))
        end
      end
    end

    def find_namespace(document, prefix)
      document.root.namespace_definitions.detect {|ns| ns.prefix == prefix}
    end

    def schema(suffix=nil)
      'http://schema.google.com' + (suffix.nil? ? '/g/2005' : (suffix =~ /^#/ ? "/g/2005#{suffix}" : suffix))
    end
  end
end
