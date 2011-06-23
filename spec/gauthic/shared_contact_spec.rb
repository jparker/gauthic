require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe Gauthic::SharedContact do
  describe '.connect!' do
    it 'creates a new Shared Contacts API session' do
      Gauthic::Session.expects(:new).with('john@example.com', 'secret', 'cp')
      Gauthic::SharedContact.connect!('john@example.com', 'secret')
    end
  end

  describe '.session' do
    it 'returns @session if a session has been established' do
      mock_session = mock('Gauthic::Session')
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

  describe '.find' do
    before { stub_connect! }

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

  describe '.all' do
    before do
      stub_request(:get, 'https://www.google.com/m8/feeds/contacts/example.com/full').
        to_return(:body => fixture('feed.xml'), :status => 200)
    end

    it 'returns an array of SharedContacts' do
      contacts = Gauthic::SharedContact.all
      contacts.first.should be_kind_of(Gauthic::SharedContact)
      contacts.last.should be_kind_of(Gauthic::SharedContact)
    end

    it 'parses individual entries returned in feed' do
      contacts = Gauthic::SharedContact.all
      contacts.first.name.fullName.should == 'Winsome Danger Parker'
      contacts.last.name.fullName.should == 'John Parker'
    end
  end

  describe '#session' do
    it 'delegates to the SharedContact.session' do
      mock_session = mock('Gauthic::Session')
      Gauthic::SharedContact.expects(:session).returns(mock_session)
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

  describe '#xml' do
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
  </gd:structuredPostalAddress>
  <gd:structuredPostalAddress label="work">
    <gd:street>2400 Elliott Ave</gd:street>
    <gd:city>Seattle</gd:city>
    <gd:region>WA</gd:region>
    <gd:postcode>98121</gd:postcode>
  </gd:structuredPostalAddress>
</entry>
      XML
      contact = Gauthic::SharedContact.new
      contact.name = {:givenName => 'Winsome', :additionalName => 'Danger', :familyName => 'Parker'}
      contact.emails = [
        {:label => 'work', :address => 'winsome.danger@example.com'},
        {:label => 'home', :address => 'winnie@example.net'}
      ]
      contact.phones = [
        {:label => 'work', :number => '(206) 555-1234'},
        {:label => 'home', :number => '(619) 555-1212'}
      ]
      contact.addresses = [
        {:label => 'work', :street => '2400 Elliott Ave', :city => 'Seattle', :region => 'WA', :postcode => '98121'},
        {:label => 'home', :street => '941 W Hawthorn St', :city => 'San Diego', :region => 'CA', :postcode => '92101'}
      ]
      contact.xml.should be_equivalent_to(expected_xml)
    end
  end

  describe '#to_xml' do
    it 'delegates to #xml' do
      contact = Gauthic::SharedContact.new(fixture('contact.xml'))
      contact.to_xml.should == contact.xml
    end
  end

  describe '#to_s' do
    it 'delegates to #xml' do
      contact = Gauthic::SharedContact.new(fixture('contact.xml'))
      contact.to_s.should == contact.xml
    end
  end

  describe '#save' do
    before { stub_connect! }

    describe 'when contact is a new record' do
      before do
        stub_request(:post, 'https://www.google.com/m8/feeds/contacts/example.com/full').
          to_return(:body => fixture('contact.xml'), :status => 201)
      end

      it 'submits POST request as XML document to domain contact feed' do
        contact = Gauthic::SharedContact.new
        contact.stubs(:xml).returns('xml')
        contact.save.should be_true
        WebMock.should have_requested(:post, 'https://www.google.com/m8/feeds/contacts/example.com/full').
          with(:body => 'xml', :headers => {'Content-Type' => 'application/atom+xml'})
      end

      it 'updates the contact with the xml returned by google' do
        contact = Gauthic::SharedContact.new
        contact.save
        contact.id.should == 'https://www.google.com/m8/feeds/contacts/example.com/full/12345'
        contact.document.at_xpath('//xmlns:link[@rel="edit"]').should_not be_nil
      end
    end

    describe 'when contact is not a new record' do
      it "submits PUT request as XML document to contact's edit link" do
        stub_request(:put, 'https://www.google.com/m8/feeds/contacts/example.com/full/12345/1204224422303000').
          to_return(:body => fixture('contact.xml'), :status => 201)
        contact = Gauthic::SharedContact.new(fixture('contact.xml'))
        contact.stubs(:xml).returns('xml')
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
    before { stub_connect! }

    it "submits DELETE request to contact's edit link" do
      stub_request(:delete, 'https://www.google.com/m8/feeds/contacts/example.com/full/12345/1204224422303000').
        to_return(:status => 201)
      contact = Gauthic::SharedContact.new(fixture('contact.xml'))
      contact.destroy.should be_true
      WebMock.should have_requested(:delete, 'https://www.google.com/m8/feeds/contacts/example.com/full/12345/1204224422303000').
        with(:headers => {'If-Match' => '*'})
    end
  end

  describe 'name proxy' do
    it 'can assign prefix' do
      contact = Gauthic::SharedContact.new
      contact.name.namePrefix = 'Rt. Hon.'
      contact.document.at_xpath('//gd:name/gd:namePrefix').content.should == 'Rt. Hon.'
    end

    it 'can assign given name' do
      contact = Gauthic::SharedContact.new
      contact.name.givenName = 'Winsome'
      contact.document.at_xpath('//gd:name/gd:givenName').content.should == 'Winsome'
    end

    it 'can assign additional names' do
      contact = Gauthic::SharedContact.new
      contact.name.additionalName = 'Danger'
      contact.document.at_xpath('//gd:name/gd:additionalName').content.should == 'Danger'
    end

    it 'can assign family name' do
      contact = Gauthic::SharedContact.new
      contact.name.familyName = 'Parker'
      contact.document.at_xpath('//gd:name/gd:familyName').content.should == 'Parker'
    end

    it 'can assign suffix' do
      contact = Gauthic::SharedContact.new
      contact.name.nameSuffix = 'Esq.'
      contact.document.at_xpath('//gd:name/gd:nameSuffix').content.should == 'Esq.'
    end

    it 'resets all fields on bulk assignment' do
      contact = Gauthic::SharedContact.new(:name => {:givenName => 'Winsome', :additionalName => 'Danger', :familyName => 'Parker'})
      contact.name = {:givenName => 'Winnie', :familyName => 'Parker'}
      contact.document.at_xpath('//gd:name/gd:givenName').content.should == 'Winnie'
      contact.document.at_xpath('//gd:name/gd:additionalName').should be_nil
      contact.document.at_xpath('//gd:name/gd:familyName').content.should == 'Parker'
    end
  end

  describe 'organization proxy' do
    it 'can assign organization name' do
      contact = Gauthic::SharedContact.new
      contact.organization.orgName = 'Urgetopunt Technologies LLC'
      contact.document.at_xpath('//gd:organization/gd:orgName').content.should == 'Urgetopunt Technologies LLC'
    end

    it 'can assign department name' do
      contact = Gauthic::SharedContact.new
      contact.organization.orgDepartment = 'Operations'
      contact.document.at_xpath('//gd:organization/gd:orgDepartment').content.should == 'Operations'
    end

    it 'can assign job title' do
      contact = Gauthic::SharedContact.new
      contact.organization.orgTitle = 'Owner'
      contact.document.at_xpath('//gd:organization/gd:orgTitle').content.should == 'Owner'
    end

    it 'resets all fields on bulk assignment' do
      contact = Gauthic::SharedContact.new(:organization => {:orgName => 'Urgetopunt Technologies', :orgTitle => 'Owner'})
      contact.organization = {:orgName => 'Urgetopunt Technologies LLC'}
      contact.document.at_xpath('//gd:organization/gd:orgName').content.should == 'Urgetopunt Technologies LLC'
      contact.document.at_xpath('//gd:organization/gd:orgTitle').should be_nil
    end
  end

  describe 'addresses proxy' do
    it 'can assign address label' do
      contact = Gauthic::SharedContact.new(:addresses => [{:label => 'other'}])
      contact.addresses.first.label = 'home'
      contact.document.at_xpath('//gd:structuredPostalAddress')['label'].should == 'home'
    end

    it 'can assign address agent' do
      contact = Gauthic::SharedContact.new(:addresses => [{:label => 'other'}])
      contact.addresses.first.street = 'c/o John Parker'
      contact.document.at_xpath('//gd:structuredPostalAddress/gd:street').content.should == 'c/o John Parker'
    end

    it 'can assign address street' do
      contact = Gauthic::SharedContact.new(:addresses => [{:label => 'other'}])
      contact.addresses.first.street = '941 W Hawthorn St'
      contact.document.at_xpath('//gd:structuredPostalAddress/gd:street').content.should == '941 W Hawthorn St'
    end

    it 'can assign address city' do
      contact = Gauthic::SharedContact.new(:addresses => [{:label => 'other'}])
      contact.addresses.first.city = 'San Diego'
      contact.document.at_xpath('//gd:structuredPostalAddress/gd:city').content.should == 'San Diego'
    end

    it 'can assign address region' do
      contact = Gauthic::SharedContact.new(:addresses => [{:label => 'other'}])
      contact.addresses.first.region = 'CA'
      contact.document.at_xpath('//gd:structuredPostalAddress/gd:region').content.should == 'CA'
    end

    it 'can assign address postcode' do
      contact = Gauthic::SharedContact.new(:addresses => [{:label => 'other'}])
      contact.addresses.first.postcode = '92101'
      contact.document.at_xpath('//gd:structuredPostalAddress/gd:postcode').content.should == '92101'
    end

    it 'can assign address country' do
      contact = Gauthic::SharedContact.new(:addresses => [{:label => 'other'}])
      contact.addresses.first.country = 'USA'
      contact.document.at_xpath('//gd:structuredPostalAddress/gd:country').content.should == 'USA'
    end

    it 'clears the existing addresses on bulk assignment' do
      contact = Gauthic::SharedContact.new(:addresses => [{:label => 'home', :country => 'USA'}])
      contact.addresses = [{:label => 'work', :country => 'United States'}]
      contact.addresses.map(&:country).should == ['United States']
    end
  end

  describe 'emails proxy' do
    it 'can assign email label' do
      contact = Gauthic::SharedContact.new(:emails => [{:label => 'other'}])
      contact.emails.first.label = 'work'
      contact.document.at_xpath('//gd:email')['label'].should == 'work'
    end

    it 'can assign email address' do
      contact = Gauthic::SharedContact.new(:emails => [{:label => 'other'}])
      contact.emails.first.address = 'jparker@urgetopunt.com'
      contact.document.at_xpath('//gd:email')['address'].should == 'jparker@urgetopunt.com'
    end

    it 'clears the existing addresses on bulk assignment' do
      contact = Gauthic::SharedContact.new(:emails => [{:label => 'work', :address => 'jparker@urgetopunt.com'},
                                                       {:label => 'home', :address => 'john@urgetopunt.org'}])
      contact.emails = [{:label => 'home', :address => 'john.c.parker@gmail.com'}]
      contact.emails.map(&:address).should == ['john.c.parker@gmail.com']
    end
  end

  describe 'phones proxy' do
    it 'can assign phone label' do
      contact = Gauthic::SharedContact.new(:phones => [{:label => 'other'}])
      contact.phones.first.label = 'work'
      contact.document.at_xpath('//gd:phoneNumber')['label'].should == 'work'
    end

    it 'can assign phone number' do
      contact = Gauthic::SharedContact.new(:phones => [{:label => 'other'}])
      contact.phones.first.number = '619-555-1212'
      contact.document.at_xpath('//gd:phoneNumber').content.should == '619-555-1212'
    end

    it 'clears the existing numbers on bulk assignment' do
      contact = Gauthic::SharedContact.new(:phones => [{:label => 'home', :number => '555-1212'},
                                                       {:label => 'work', :number => '555-1213'}])
      contact.phones = [{:label => 'home', :number => '555-1234'}]
      contact.phones.map(&:number).should == ['555-1234']
    end
  end

  describe 'initialization with an attribute hash' do
    it 'assigns name' do
      contact = Gauthic::SharedContact.new(:name => {
        :givenName => 'Winsome',
        :additionalName => 'Danger',
        :familyName => 'Parker'
      })
      contact.name.givenName.should == 'Winsome'
      contact.name.additionalName.should == 'Danger'
      contact.name.familyName.should == 'Parker'
    end

    it 'assigns organization' do
      contact = Gauthic::SharedContact.new(:organization => {:orgName => 'Urgetopunt Technologies LLC', :orgTitle => 'Owner'})
      contact.organization.orgName.should == 'Urgetopunt Technologies LLC'
      contact.organization.orgTitle.should == 'Owner'
    end

    it 'assigns postal address' do
      contact = Gauthic::SharedContact.new(:addresses => [{
        :label => 'work',
        :agent => 'c/o John Parker',
        :street => '941 W Hawthorn St',
        :city => 'San Diego',
        :region => 'CA',
        :postcode => '92101',
        :country => 'USA'
      }])
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
    it 'parses XML for name' do
      contact = Gauthic::SharedContact.new(fixture('contact.xml'))
      contact.name.givenName.should == 'Winsome'
      contact.name.additionalName.should == 'Danger'
      contact.name.familyName.should == 'Parker'
    end

    it 'parses XML for organization' do
      contact = Gauthic::SharedContact.new(fixture('contact.xml'))
      contact.organization.orgName.should == 'Danger LLP'
      contact.organization.orgTitle.should == 'President'
    end

    it 'parses XML for email addresses' do
      contact = Gauthic::SharedContact.new(fixture('contact.xml'))
      contact.emails.first.label.should == 'home'
      contact.emails.first.address.should == 'winnie@example.net'
      contact.emails.last.label.should == 'work'
      contact.emails.last.address.should == 'winsome.parker@example.com'
    end

    it 'parses XML for phone numbers' do
      contact = Gauthic::SharedContact.new(fixture('contact.xml'))
      contact.phones.first.label.should == 'home'
      contact.phones.first.number.should == '(619) 555-1212'
      contact.phones.last.label.should == 'work'
      contact.phones.last.number.should == '(206) 555-1111'
    end

    it 'parses XML for postal addresses' do
      contact = Gauthic::SharedContact.new(fixture('contact.xml'))
      contact.addresses.first.label.should == 'work'
      contact.addresses.first.agent.should == 'c/o John Parker'
      contact.addresses.first.street.should == '941 W Hawthorn St'
      contact.addresses.first.city.should == 'San Diego'
      contact.addresses.first.region.should == 'CA'
      contact.addresses.first.postcode.should == '92101'
      contact.addresses.first.country.should == 'USA'
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
      contact.xml.should be_equivalent_to(expected_xml)
    end
  end
end
