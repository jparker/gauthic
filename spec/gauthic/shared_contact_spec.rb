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
        to raise_error(Gauthic::Session::NoActiveSession, /start new session by calling connect!/)
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

  describe '#id' do
    it 'returns the href value of the "self" link if the contact has been saved' do
      contact = Gauthic::SharedContact.new(fixture('contact.xml'))
      contact.id.should == 'https://www.google.com/m8/feeds/contacts/example.com/full/12345'
    end

    it 'returns nil if the contact does not yet have a "self" link' do
      contact = Gauthic::SharedContact.new
      contact.id.should be_nil
    end
  end

  describe '#new_record?' do
    it 'returns true if the id is nil' do
      contact = Gauthic::SharedContact.new
      contact.should be_new_record
    end

    it 'returns false if the id is not nil' do
      contact = Gauthic::SharedContact.new(fixture('contact.xml'))
      contact.should_not be_new_record
    end
  end

  describe '#to_xml' do
    it 'returns a well-formatted xml document' do
      expected_xml = <<-XML
<?xml version="1.0"?>
<entry xmlns="http://www.w3.org/2005/Atom" xmlns:gd="http://schemas.google.com/g/2005">
  <category scheme="http://schemas.google.com/g/2005#kind" term="http://schemas.google.com/contact/2008#contact"/>
  <gd:name>
    <gd:givenName>Winsome</gd:givenName>
    <gd:additionalName>Danger</gd:additionalName>
    <gd:familyName>Parker</gd:familyName>
  </gd:name>
  <gd:email label="home" address="winnie@example.net"/>
  <gd:email label="work" address="winsome.danger@example.com"/>
  <gd:phoneNumber label="home">
    (619) 555-1212
  </gd:phoneNumber>
  <gd:phoneNumber label="work">
    (206) 555-1234
  </gd:phoneNumber>
  <gd:structuredPostalAddress label="home">
    <gd:street>941 W Hawthorn St</gd:street>
    <gd:city>San Diego</gd:city>
    <gd:region>CA</gd:region>
    <gd:postcode>92101</gd:postcode>
    <gd:country>USA</gd:country>
  </gd:structuredPostalAddress>
  <gd:structuredPostalAddress label="work">
    <gd:agent>c/o John Parker</gd:agent>
    <gd:street>2400 Elliott Ave</gd:street>
    <gd:city>Seattle</gd:city>
    <gd:region>WA</gd:region>
    <gd:postcode>98121</gd:postcode>
    <gd:country>USA</gd:country>
  </gd:structuredPostalAddress>
</entry>
      XML
      contact = Gauthic::SharedContact.new(
        :name => {:givenName => 'Winsome', :additionalName => 'Danger', :familyName => 'Parker'},
        :emails => [{:label => 'work', :address => 'winsome.danger@example.com'}, {:label => 'home', :address => 'winnie@example.net'}],
        :phones => [{:label => 'work', :number => '(206) 555-1234'}, {:label => 'home', :number => '(619) 555-1212'}],
        :addresses => [
          {:label => 'work', :agent => 'c/o John Parker', :street => '2400 Elliott Ave', :city => 'Seattle', :region => 'WA', :postcode => '98121', :country => 'USA'},
          {:label => 'home', :street => '941 W Hawthorn St', :city => 'San Diego', :region => 'CA', :postcode => '92101', :country => 'USA'}
        ]
      )
      contact.to_xml.should be_equivalent_to(expected_xml)
    end
  end

  describe '.find' do
    before do
      stub_request(:post, 'https://www.google.com/accounts/ClientLogin').
        to_return(:body => fixture('successful_authentication.txt'), :status => 200)
      Gauthic::SharedContact.connect!('admin@example.com', 'secret')
    end

    describe 'with the id of an existing contact' do
      before do
        stub_request(:get, 'https://www.google.com/m8/feeds/contacts/example.com/full/12345').
          to_return(:body => '<?xml version="1.0"?>', :status => 200)
      end

      it 'returns a new SharedContact' do
        mock_contact = mock('Gauthic::SharedContact')
        Gauthic::SharedContact.expects(:new).with('<?xml version="1.0"?>').returns(mock_contact)
        Gauthic::SharedContact.find('https://www.google.com/m8/feeds/contacts/example.com/full/12345').
          should eq(mock_contact)
      end
    end

    describe 'with the id of a non-existent contact' do
      before do
        stub_request(:get, 'https://www.google.com/m8/feeds/contacts/example.com/full/12345').
          to_return(:body => 'Contact not found.', :status => 404)
      end

      it 'raises RecordNotFound' do
        expect { Gauthic::SharedContact.find('https://www.google.com/m8/feeds/contacts/example.com/full/12345') }.
          to raise_error(Gauthic::SharedContact::RecordNotFound, /Contact not found/)
      end
    end
  end

  describe '#save' do
    before do
      stub_request(:post, 'https://www.google.com/accounts/ClientLogin').
        to_return(:body => fixture('successful_authentication.txt'), :status => 200)
      Gauthic::SharedContact.connect!('admin@example.com', 'secret')
    end

    describe 'when contact is a new record' do
      it 'submits POST request as XML document to domain contact feed' do
        stub_request(:post, 'https://www.google.com/m8/feeds/contacts/example.com/full').
          to_return(:body => fixture('contact.xml'), :status => 201)
        contact = Gauthic::SharedContact.new
        contact.stubs(:to_xml).returns('xml')
        contact.save.should be_true
        WebMock.should have_requested(:post, 'https://www.google.com/m8/feeds/contacts/example.com/full').
          with(:body => 'xml', :headers => {'Content-Type' => 'application/atom+xml'})
      end
    end

    describe 'when contact is not a new record' do
      it "submits PUT request as XML document to contact's edit link" do
        stub_request(:put, 'https://www.google.com/m8/feeds/contacts/example.com/full/12345/1204224422303000').
          to_return(:body => fixture('contact.xml'), :status => 201)
        contact = Gauthic::SharedContact.new(fixture('contact.xml'))
        contact.stubs(:to_xml).returns('xml')
        contact.save.should be_true
        WebMock.should have_requested(:put, 'https://www.google.com/m8/feeds/contacts/example.com/full/12345/1204224422303000').
          with(:body => 'xml', :headers => {'Content-Type' => 'application/atom+xml'})
      end
    end
  end

  describe '#update_attributes' do
    it 'updates contact with given attribute values' do
      contact = Gauthic::SharedContact.new
      contact.expects(:save).returns(true)
      contact.update_attributes(:name => {:givenName => 'John', :familyName => 'Parker'},
                                 :emails => [{:label => 'work', :address => 'jparker@urgetopunt.com'}],
                                 :organization => {:orgName => 'Urgetopunt Technologies LLC', :orgTitle => 'Owner'})
      contact.name.givenName.should == 'John'
      contact.name.familyName.should == 'Parker'
      contact.emails.first.label.should == 'work'
      contact.emails.first.address.should == 'jparker@urgetopunt.com'
      contact.organization.orgName.should == 'Urgetopunt Technologies LLC'
      contact.organization.orgTitle.should == 'Owner'
    end
  end

  describe '#destroy' do
    before do
      stub_request(:post, 'https://www.google.com/accounts/ClientLogin').
        to_return(:body => fixture('successful_authentication.txt'), :status => 200)
      Gauthic::SharedContact.connect!('admin@example.com', 'secret')
    end

    it "submits DELETE request to contact's edit link" do
      stub_request(:delete, 'https://www.google.com/m8/feeds/contacts/example.com/full/12345/1204224422303000').
        to_return(:status => 201)
      contact = Gauthic::SharedContact.new(fixture('contact.xml'))
      contact.destroy.should be_true
      WebMock.should have_requested(:delete, 'https://www.google.com/m8/feeds/contacts/example.com/full/12345/1204224422303000').
        with(:headers => {'If-Match' => '*'})
    end
  end

  describe 'name' do
    it 'assigns prefixes' do
      contact = Gauthic::SharedContact.new
      contact.name.namePrefix = 'Rt. Hon.'
      contact.document.at_xpath('//gd:name/gd:namePrefix').content.should == 'Rt. Hon.'
    end

    it 'assigns given names' do
      contact = Gauthic::SharedContact.new
      contact.name.givenName = 'Winsome'
      contact.document.at_xpath('//gd:name/gd:givenName').content.should == 'Winsome'
    end

    it 'assigns middle names' do
      contact = Gauthic::SharedContact.new
      contact.name.additionalName = 'Danger'
      contact.document.at_xpath('//gd:name/gd:additionalName').content.should == 'Danger'
    end

    it 'assigns family names' do
      contact = Gauthic::SharedContact.new
      contact.name.familyName = 'Parker'
      contact.document.at_xpath('//gd:name/gd:familyName').content.should == 'Parker'
    end

    it 'assigns suffixes' do
      contact = Gauthic::SharedContact.new
      contact.name.nameSuffix = 'Esq.'
      contact.document.at_xpath('//gd:name/gd:nameSuffix').content.should == 'Esq.'
    end
  end

  describe 'organization' do
    it 'assigns organization name' do
      contact = Gauthic::SharedContact.new
      contact.organization.orgName = 'Urgetopunt Technologies LLC'
      contact.document.at_xpath('//gd:organization/gd:orgName').content.should == 'Urgetopunt Technologies LLC'
    end

    it 'assigns department name' do
      contact = Gauthic::SharedContact.new
      contact.organization.orgDepartment = 'Operations'
      contact.document.at_xpath('//gd:organization/gd:orgDepartment').content.should == 'Operations'
    end

    it 'assigns job title' do
      contact = Gauthic::SharedContact.new
      contact.organization.orgTitle = 'Owner'
      contact.document.at_xpath('//gd:organization/gd:orgTitle').content.should == 'Owner'
    end
  end

  describe 'addresses' do
    it 'assigns label' do
      contact = Gauthic::SharedContact.new(:addresses => [{:label => 'other'}])
      contact.addresses.first.label = 'home'
      contact.document.at_xpath('//gd:structuredPostalAddress')['label'].should == 'home'
    end

    it 'assigns agent' do
      contact = Gauthic::SharedContact.new(:addresses => [{:label => 'other'}])
      contact.addresses.first.street = 'c/o John Parker'
      contact.document.at_xpath('//gd:structuredPostalAddress/gd:street').content.should == 'c/o John Parker'
    end

    it 'assigns street' do
      contact = Gauthic::SharedContact.new(:addresses => [{:label => 'other'}])
      contact.addresses.first.street = '941 W Hawthorn St'
      contact.document.at_xpath('//gd:structuredPostalAddress/gd:street').content.should == '941 W Hawthorn St'
    end

    it 'assigns city' do
      contact = Gauthic::SharedContact.new(:addresses => [{:label => 'other'}])
      contact.addresses.first.city = 'San Diego'
      contact.document.at_xpath('//gd:structuredPostalAddress/gd:city').content.should == 'San Diego'
    end

    it 'assigns region' do
      contact = Gauthic::SharedContact.new(:addresses => [{:label => 'other'}])
      contact.addresses.first.region = 'CA'
      contact.document.at_xpath('//gd:structuredPostalAddress/gd:region').content.should == 'CA'
    end

    it 'assigns postcode' do
      contact = Gauthic::SharedContact.new(:addresses => [{:label => 'other'}])
      contact.addresses.first.postcode = '92101'
      contact.document.at_xpath('//gd:structuredPostalAddress/gd:postcode').content.should == '92101'
    end

    it 'assigns country' do
      contact = Gauthic::SharedContact.new(:addresses => [{:label => 'other'}])
      contact.addresses.first.country = 'USA'
      contact.document.at_xpath('//gd:structuredPostalAddress/gd:country').content.should == 'USA'
    end
  end

  describe 'emails' do
    it 'assigns label' do
      contact = Gauthic::SharedContact.new(:emails => [{:label => 'other'}])
      contact.emails.first.label = 'work'
      contact.document.at_xpath('//gd:email')['label'].should == 'work'
    end

    it 'assigns address' do
      contact = Gauthic::SharedContact.new(:emails => [{:label => 'other'}])
      contact.emails.first.address = 'jparker@urgetopunt.com'
      contact.document.at_xpath('//gd:email')['address'].should == 'jparker@urgetopunt.com'
    end
  end

  describe 'phones' do
    it 'assigns label' do
      contact = Gauthic::SharedContact.new(:phones => [{:label => 'other'}])
      contact.phones.first.label = 'work'
      contact.document.at_xpath('//gd:phoneNumber')['label'].should == 'work'
    end

    it 'assigns number' do
      contact = Gauthic::SharedContact.new(:phones => [{:label => 'other'}])
      contact.phones.first.number = '619-555-1212'
      contact.document.at_xpath('//gd:phoneNumber').content.should == '619-555-1212'
    end
  end

  describe 'initialization with an attribute hash' do
    it 'assigns name' do
      contact = Gauthic::SharedContact.new(:name => {:givenName=>'Winsome', :additionalName=>'Danger', :familyName=>'Parker'})
      contact.name.givenName.should == 'Winsome'
      contact.name.additionalName.should == 'Danger'
      contact.name.familyName.should == 'Parker'
    end

    it 'assigns organization' do
      contact = Gauthic::SharedContact.new(:organization => {:orgName=>'Urgetopunt Technologies LLC', :orgTitle=>'Owner'})
      contact.organization.orgName.should == 'Urgetopunt Technologies LLC'
      contact.organization.orgTitle.should == 'Owner'
    end

    it 'assigns postal address' do
      contact = Gauthic::SharedContact.new(:addresses => [{:label=>'work', :agent=>'c/o John Parker', :street=>'941 W Hawthorn St', :city=>'San Diego', :region=>'CA', :postcode=>'92101', :country=>'USA'}])
      contact.addresses.first.label.should == 'work'
      contact.addresses.first.agent.should == 'c/o John Parker'
      contact.addresses.first.street.should == '941 W Hawthorn St'
      contact.addresses.first.city.should == 'San Diego'
      contact.addresses.first.region.should == 'CA'
      contact.addresses.first.postcode.should == '92101'
      contact.addresses.first.country.should == 'USA'
    end

    it 'assigns email address' do
      contact = Gauthic::SharedContact.new(:emails => [{:label=>'home', :address=>'john.c.parker@gmail.com'},
                                                       {:label=>'work', :address=>'jparker@urgetopunt.com'}])
      contact.emails.first.label.should == 'home'
      contact.emails.first.address.should == 'john.c.parker@gmail.com'
      contact.emails.last.label.should == 'work'
      contact.emails.last.address.should == 'jparker@urgetopunt.com'
    end

    it 'assigns phone number attributes' do
      contact = Gauthic::SharedContact.new(:phones => [{:label=>'home', :number=>'619-555-1212'},
                                                       {:label=>'work', :number=>'206-555-1111'}])
      contact.phones.first.label.should == 'home'
      contact.phones.first.number.should == '619-555-1212'
      contact.phones.last.label.should == 'work'
      contact.phones.last.number.should == '206-555-1111'
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
      @contact.emails.first.label.should == 'home'
      @contact.emails.first.address.should == 'winnie@example.net'
      @contact.emails.last.label.should == 'work'
      @contact.emails.last.address.should == 'winsome.parker@example.com'
    end

    it 'parses XML for phone numbers' do
      @contact.phones.first.label.should == 'home'
      @contact.phones.first.number.should == '(619) 555-1212'
      @contact.phones.last.label.should == 'work'
      @contact.phones.last.number.should == '(206) 555-1111'
    end

    it 'parses XML for postal addresses' do
      @contact.addresses.first.label.should == 'work'
      @contact.addresses.first.agent.should == 'c/o John Parker'
      @contact.addresses.first.street.should == '941 W Hawthorn St'
      @contact.addresses.first.city.should == 'San Diego'
      @contact.addresses.first.region.should == 'CA'
      @contact.addresses.first.postcode.should == '92101'
      @contact.addresses.first.country.should == 'USA'
    end
  end

  describe 'initialization with an empty document' do
    it 'defaults to a blank slate XML document' do
      expected_xml = <<-XML
<?xml version="1.0"?>
<entry xmlns="http://www.w3.org/2005/Atom" xmlns:gd="http://schemas.google.com/g/2005">
  <category scheme="http://schemas.google.com/g/2005#kind" term="http://schemas.google.com/contact/2008#contact"/>
</entry>
      XML
      contact = Gauthic::SharedContact.new('<?xml version="1.0"?>')
      contact.to_xml.should be_equivalent_to(expected_xml)
    end
  end
end
