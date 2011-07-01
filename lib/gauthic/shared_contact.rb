require 'gauthic/shared_contact/abstract_node'
require 'gauthic/shared_contact/name'
require 'gauthic/shared_contact/organization'
require 'gauthic/shared_contact/address'
require 'gauthic/shared_contact/phone'
require 'gauthic/shared_contact/email'

module Gauthic
  class SharedContact
    class RecordNotFound < StandardError
    end

    class RecordNotSaved < StandardError
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
      tag = document.at_xpath('.//xmlns:link[@rel="self"]')
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
      url = document.at_xpath('.//xmlns:link[@rel="edit"]').attribute('href').value
      result = session.delete(url, :headers => {'If-Match' => '*'})
      if Net::HTTPSuccess === result
        return true
      else
        raise Gauthic::SharedContact::RecordNotSaved, result.body
      end
    end

    def xml
      document.to_xml
    end
    alias to_xml xml
    alias to_s xml

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

    # FIXME: This isn't quite working. It returns SharedContacts with documents
    # that are Elements rather than full-fledged Documents.
    def self.all
      result = session.get("https://www.google.com/m8/feeds/contacts/#{session.domain}/full")
      if Net::HTTPSuccess === result
        feed = Nokogiri.XML(result.body)
        feed.xpath('//xmlns:feed/xmlns:entry').map { |node| new(node) }
      else
        raise Gauthic::SharedContact::RecordNotFound, result.body
      end
    end

    def session
      self.class.session
    end

    def name
      node = document.at_xpath('.//gd:name')
      if node.nil?
        node = Nokogiri::XML::Node.new('name', document)
        node.namespace = namespace('gd')
        document.root << node
      end
      Name.new(node)
    end

    def name=(parts)
      document.xpath('.//gd:name').remove
      parts.each { |attr, value| name.send("#{attr}=", value) }
    end

    def organization
      node = document.at_xpath('.//gd:organization')
      if node.nil?
        node = Nokogiri::XML::Node.new('organization', document)
        node.namespace = namespace('gd')
        document.root << node
      end
      Organization.new(node)
    end

    def organization=(parts)
      document.xpath('.//gd:organization').remove
      parts.each { |attr, value| organization.send("#{attr}=", value) }
    end

    def addresses
      document.xpath('.//gd:structuredPostalAddress').map { |node| Address.new(node) }
    end

    def addresses=(addresses)
      document.xpath('.//gd:structuredPostalAddress').remove
      addresses.map do |parts|
        node = Nokogiri::XML::Node.new('structuredPostalAddress', document)
        node.namespace = namespace('gd')
        document.root << node
        Address.new(node, parts)
      end
    end

    def emails
      document.xpath('.//gd:email').map { |node| Email.new(node) }
    end

    def emails=(addresses)
      document.xpath('.//gd:email').remove
      addresses.map do |parts|
        node = Nokogiri::XML::Node.new('email', document)
        node.namespace = namespace('gd')
        document.root << node
        Email.new(node, parts)
      end
    end

    def phones
      document.xpath('.//gd:phoneNumber').map { |node| Phone.new(node) }
    end

    def phones=(numbers)
      document.xpath('.//gd:phoneNumber').remove
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
      result = session.post(url, :headers => {'Content-Type' => 'application/atom+xml'}, :body => xml)
      if Net::HTTPSuccess === result
        self.xml = result.body
        return debug ? result.body : true
      else
        raise Gauthic::SharedContact::RecordNotSaved, result.body
      end
    end

    def update_existing_record(debug=false)
      url = document.at_xpath('.//xmlns:link[@rel="edit"]').attribute('href').value
      result = session.put(url, :headers => {'Content-Type' => 'application/atom+xml'}, :body => xml)
      if Net::HTTPSuccess === result
        self.xml = result.body
        return debug ? result.body : true
      else
        raise Gauthic::SharedContact::RecordNotSaved, result.body
      end
    end

    def xml=(xml)
      if xml.respond_to?(:document)
        self.document = xml
      else
        self.document = Nokogiri.XML(xml)
        self.document = default_document if document.root.nil?
      end
    end
  end
end
