require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe Gauthic::Session do
  describe 'successful authentication' do
    before do
      stub_request(:post, 'https://www.google.com/accounts/ClientLogin').
        to_return(:body => "SID=DQAAAGgA...7Zg8CTN\nLSID=DQAAAGsA...lk8BBbG\nAuth=DQAAAGgA...dk3fA5N\n", :status => 200)
    end

    it 'stores the authentication token' do
      session = Gauthic::Session.new('john@example.com', 'secret', 'cp')
      session.token.should == 'DQAAAGgA...dk3fA5N'
    end

    it 'stores the Google Apps domain' do
      session = Gauthic::Session.new('john@example.com', 'secret', 'cp')
      session.domain.should == 'example.com'
    end
  end

  describe 'unsuccessful authentication' do
    before do
      stub_request(:post, 'https://www.google.com/accounts/ClientLogin').
        to_return(:body => "Error=BadAuthentication\n", :status => 403)
    end

    it 'raises AuthenticationError' do
      expect { Gauthic::Session.new('john@example.com', 'secret', 'cp') }.
        to raise_error(Gauthic::Session::AuthenticationError, /Error=BadAuthentication/)
    end
  end

  describe '.new' do
    before do
      stub_request(:post, 'https://www.google.com/accounts/ClientLogin').
        to_return(:body => fixture('successful_authentication.txt'), :status => 200)
    end

    it 'submits POST to Google' do
      Gauthic::Session.new('john@example.com', 'secret', 'cp')
      WebMock.should have_requested(:post, 'https://www.google.com/accounts/ClientLogin')
    end

    it 'includes accountType parameter in post' do
      Gauthic::Session.new('john@example.com', 'secret', 'cp')
      WebMock.should have_requested(:post, 'https://www.google.com/accounts/ClientLogin').
        with(:body => /\baccountType=HOSTED\b/)
    end

    it 'includes Email parameter in post' do
      Gauthic::Session.new('john@example.com', 'secret', 'cp')
      WebMock.should have_requested(:post, 'https://www.google.com/accounts/ClientLogin').
        with(:body => /\bEmail=john%40example\.com\b/)
    end

    it 'includes Passwd parameter in post' do
      Gauthic::Session.new('john@example.com', 'secret', 'cp')
      WebMock.should have_requested(:post, 'https://www.google.com/accounts/ClientLogin').
        with(:body => /\bPasswd=secret\b/)
    end

    it 'includes service parameter in post' do
      Gauthic::Session.new('john@example.com', 'secret', 'cp')
      WebMock.should have_requested(:post, 'https://www.google.com/accounts/ClientLogin').
        with(:body => /\bservice=cp\b/)
    end

    it 'includes source parameter in post' do
      Gauthic::Session.new('john@example.com', 'secret', 'cp')
      WebMock.should have_requested(:post, 'https://www.google.com/accounts/ClientLogin').
        with(:body => /\bsource=urgetopunt-gauthic-#{Gauthic::VERSION}\b/)
    end
  end

  describe 'after successful authentication' do
    before do
      stub_request(:post, 'https://www.google.com/accounts/ClientLogin').
        to_return(:body => fixture('successful_authentication.txt'), :status => 200)
      @session = Gauthic::Session.new('john@example.com', 'secret', 'cp')
      @session.stubs(:token).returns('my-awesome-token')
    end

    describe '#get' do
      before do
        stub_request(:get, 'https://www.google.com/foo').
          to_return(:body => 'Hello, nurse!', :status => 200)
      end

      it 'performs a GET request to the given uri with authorization and gdata-version headers' do
        @session.get('https://www.google.com/foo')
        WebMock.should have_requested(:get, 'https://www.google.com/foo').
          with(:headers => {'Authorization' => 'GoogleLogin auth=my-awesome-token', 'GData-Version' => '3.0'})
      end

      it 'returns the HTTPResponse' do
        @session.get('https://www.google.com/foo').should be_kind_of(Net::HTTPResponse)
      end
    end

    describe '#post' do
      before do
        stub_request(:post, 'https://www.google.com/foo').
          to_return(:body => 'Hello, nurse!', :status => 200)
      end

      it 'performs a POST request to the given uri with authorization and gdata-version headers' do
        @session.post('https://www.google.com/foo')
        WebMock.should have_requested(:post, 'https://www.google.com/foo').
          with(:headers => {'Authorization' => 'GoogleLogin auth=my-awesome-token', 'GData-Version' => '3.0'})
      end

      it 'returns the HTTPResponse' do
        @session.post('https://www.google.com/foo').should be_kind_of(Net::HTTPResponse)
      end

      it 'includes additional headers with request if passed as arguments' do
        @session.post('https://www.google.com/foo', :headers => {'Content-Type' => 'application/atom+xml'})
        WebMock.should have_requested(:post, 'https://www.google.com/foo').
          with(:headers => {'Content-Type' => 'application/atom+xml'})
      end

      it 'includes request body if passed as argument' do
        @session.post('https://www.google.com/foo', :body => 'Hello, nurse!')
        WebMock.should have_requested(:post, 'https://www.google.com/foo').with(:body => 'Hello, nurse!')
      end
    end

    describe '#put' do
      before do
        stub_request(:put, 'https://www.google.com/foo').
          to_return(:body => 'Hello, nurse!', :status => 200)
      end

      it 'performs a PUT request to the given uri with authorization and gdata-version headers' do
        @session.put('https://www.google.com/foo')
        WebMock.should have_requested(:put, 'https://www.google.com/foo').
          with(:headers => {'Authorization' => 'GoogleLogin auth=my-awesome-token', 'GData-Version' => '3.0'})
      end

      it 'returns the HTTPResponse' do
        @session.put('https://www.google.com/foo').should be_kind_of(Net::HTTPResponse)
      end

      it 'includes additional headers with request if passed as arguments' do
        @session.put('https://www.google.com/foo', :headers => {'Content-Type' => 'application/atom+xml'})
        WebMock.should have_requested(:put, 'https://www.google.com/foo').
          with(:headers => {'Content-Type' => 'application/atom+xml'})
      end

      it 'includes request body if passed as argument' do
        @session.put('https://www.google.com/foo', :body => 'Hello, nurse!')
        WebMock.should have_requested(:put, 'https://www.google.com/foo').with(:body => 'Hello, nurse!')
      end
    end

    describe '#delete' do
      before do
        stub_request(:delete, 'https://www.google.com/foo').
          to_return(:body => 'Hello, nurse!', :status => 200)
      end

      it 'performs a DELETE request to the given uri with authorization and gdata-version headers' do
        @session.delete('https://www.google.com/foo')
        WebMock.should have_requested(:delete, 'https://www.google.com/foo').
          with(:headers => {'Authorization' => 'GoogleLogin auth=my-awesome-token', 'GData-Version' => '3.0'})
      end

      it 'returns the HTTPResponse' do
        @session.delete('https://www.google.com/foo').should be_kind_of(Net::HTTPResponse)
      end

      it 'includes additional headers with request if passed as arguments' do
        @session.delete('https://www.google.com/foo', :headers => {'If-Match' => '*'})
        WebMock.should have_requested(:delete, 'https://www.google.com/foo').with(:headers => {'If-Match' => '*'})
      end
    end
  end
end
