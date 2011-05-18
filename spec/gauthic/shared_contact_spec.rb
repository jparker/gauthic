require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe Gauthic::SharedContact do
  describe '.connect!' do
    it 'creates a new Shared Contacts API session' do
      Gauthic::Session.expects(:new).with('john@example.com', 'secret', 'cp')
      Gauthic::SharedContact.connect!('john@example.com', 'secret')
    end
  end

  describe '.disconnect!' do
    it 'destroys the existing Shared Contacts API session' do
      Gauthic::SharedContact.disconnect!
      # FIXME: this test looks brittle (to me)
      Gauthic::SharedContact.instance_variable_get(:@session).should be_nil
    end
  end

  describe '.session' do
    it 'returns @session if a session has been established' do
      mock_session = mock
      Gauthic::Session.stubs(:new).returns(mock_session)
      Gauthic::SharedContact.connect!('john@example.com', 'secret')
      Gauthic::SharedContact.session.should eq(mock_session)
    end

    it 'raises NoActiveSession if a session has not been established' do
      Gauthic::SharedContact.disconnect!
      expect { Gauthic::SharedContact.session }.
        to raise_error(Gauthic::NoActiveSession, /start new session by calling connect!/)
    end
  end

  describe '#session' do
    it 'delegates to the SharedContact.session' do
      mock_session = mock
      Gauthic::Session.stubs(:new).returns(mock_session)
      Gauthic::SharedContact.connect!('john@example.com', 'secret')
      contact = Gauthic::SharedContact.new
      contact.session.should eq(mock_session)
    end
  end

  describe 'initialization with an attribute hash' do
    it 'assigns name attributes' do
      contact = Gauthic::SharedContact.new(:name => {:givenName=>'Winsome', :additionalName=>'Danger', :familyName=>'Parker'})
      doc = Nokogiri.XML(contact.to_xml)
      doc.at_xpath('//gd:name/gd:givenName').content.should == 'Winsome'
      doc.at_xpath('//gd:name/gd:additionalName').content.should == 'Danger'
      doc.at_xpath('//gd:name/gd:familyName').content.should == 'Parker'
    end

    it 'assigns organization attributes' do
      contact = Gauthic::SharedContact.new(:organization => {:orgName=>'Danger LLP', :orgTitle=>'President'})
      doc = Nokogiri.XML(contact.to_xml)
      doc.at_xpath('//gd:organization/gd:orgName').content.should == 'Danger LLP'
      doc.at_xpath('//gd:organization/gd:orgTitle').content.should == 'President'
    end

    it 'assigns postal address attributes' do
      contact = Gauthic::SharedContact.new(:address => [{:label=>'work', :agent=>'c/o John Parker', :street=>'941 W Hawthorn St', :city=>'San Diego', :region=>'CA', :postcode=>'92101', :country=>'USA'}])
      doc = Nokogiri.XML(contact.to_xml)
      node = doc.at_xpath('//gd:structuredPostalAddress')

      node.attribute('label').value.should == 'work'
      node.at_xpath('//gd:agent').content.should == 'c/o John Parker'
      node.at_xpath('//gd:street').content.should == '941 W Hawthorn St'
      node.at_xpath('//gd:city').content.should == 'San Diego'
      node.at_xpath('//gd:region').content.should == 'CA'
      node.at_xpath('//gd:postcode').content.should == '92101'
      node.at_xpath('//gd:country').content.should == 'USA'
    end

    it 'assigns email address attributes' do
      contact = Gauthic::SharedContact.new(:email => [{:label=>'home', :address=>'winnie@example.net'},
                                                      {:label=>'work', :address=>'winsome.parker@example.com'}])
      doc = Nokogiri.XML(contact.to_xml)
      nodes = doc.xpath('//gd:email')
      nodes.first.attribute('label').value.should == 'home'
      nodes.first.attribute('address').value.should == 'winnie@example.net'
      nodes.last.attribute('label').value.should == 'work'
      nodes.last.attribute('address').value.should == 'winsome.parker@example.com'
    end

    it 'assigns phone number attributes' do
      contact = Gauthic::SharedContact.new(:phone => [{:label=>'home', :number=>'619-555-1212'},
                                                      {:label=>'work', :number=>'206-555-1111'}])
      doc = Nokogiri.XML(contact.to_xml)
      nodes = doc.xpath('//gd:phoneNumber')
      nodes.first.attribute('label').value.should == 'home'
      nodes.first.content.should == '619-555-1212'
      nodes.last.attribute('label').value.should == 'work'
      nodes.last.content.should == '206-555-1111'
    end
  end

  describe 'initialization with an xml document' do
    before do
      @contact = Gauthic::SharedContact.new(fixture('contact.xml'))
    end

    it 'parses XML for name' do
      @contact.name.givenName.should == 'Winsome'
      @contact.name.additionalName.should == 'Danger'
      @contact.name.familyName.should == 'Parker'
    end

    it 'parses XML for organization' do
      @contact.organization.orgName.should == 'Danger LLP'
      @contact.organization.orgTitle.should == 'President'
    end

    it 'parses XML for email addresses' do
      @contact.email.first.label.should == 'home'
      @contact.email.first.address.should == 'winnie@example.net'
      @contact.email.last.label.should == 'work'
      @contact.email.last.address.should == 'winsome.parker@example.com'
    end

    it 'parses XML for phone numbers' do
      @contact.phone.first.label.should == 'home'
      @contact.phone.first.number.should == '(619) 555-1212'
      @contact.phone.last.label.should == 'work'
      @contact.phone.last.number.should == '(206) 555-1111'
    end

    it 'parses XML for postal addresses' do
      @contact.address.first.label.should == 'work'
      @contact.address.first.agent.should == 'c/o John Parker'
      @contact.address.first.street.should == '941 W Hawthorn St'
      @contact.address.first.city.should == 'San Diego'
      @contact.address.first.region.should == 'CA'
      @contact.address.first.postcode.should == '92101'
      @contact.address.first.country.should == 'USA'
    end
  end
end