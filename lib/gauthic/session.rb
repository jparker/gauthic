module Gauthic
  # Gauthic::SharedContact::Session authenticates as a domain administrator for the
  # Shared Contacts API using the ClientLogin method. Upon authentication Google
  # returns a token which must be included in the headers of all subsequent requests.
  # This is handled automatically when using the #get, #post, #put and #delete
  # methods.
  class Session
    class AuthenticationError < StandardError
    end

    class NoActiveSession < StandardError
    end

    attr_accessor :token, :domain

    # Initiates a new Shared Contacts API session. +email+ and +password+ are the
    # credentails of the administrator account used to publish shared contacts to
    # Google. Returns a new Gauthic::SharedContact::Session object on success.
    # Raises Gauthic::SharedContact::AuthenticationError on failure.
    def initialize(email, password, service)
      uri = URI.parse('https://www.google.com/accounts/ClientLogin')
      request = Net::HTTP::Post.new(uri.path)
      request.set_form_data(
        :accountType => 'HOSTED',
        :Email       => email,
        :Passwd      => password,
        :service     => service,
        :source      => "urgetopunt-gauthic-#{Gauthic::VERSION}"
      )
      result = send_request(uri, request)

      if Net::HTTPSuccess === result
        self.token = result.body.match(/\bAuth=(.*)\b/)[1]
        self.domain = email.split('@').last
      else
        raise Gauthic::Session::AuthenticationError, result.body
      end
    end

    # Issues a GET request for +uri+.
    def get(uri, options={})
      uri = URI.parse(uri)
      request = Net::HTTP::Get.new(uri.path)
      gdata_headers!(request)
      send_request(uri, request, options)
    end

    # Issues a POST request for +uri+.
    def post(uri, options={})
      uri = URI.parse(uri)
      request = Net::HTTP::Post.new(uri.path)
      gdata_headers!(request)
      send_request(uri, request, options)
    end

    # Issues a PUT request for +uri+.
    def put(uri, options={})
      uri = URI.parse(uri)
      request = Net::HTTP::Put.new(uri.path)
      gdata_headers!(request)
      send_request(uri, request, options)
    end

    # Issues a DELETE request for +uri+.
    def delete(uri, options={})
      uri = URI.parse(uri)
      request = Net::HTTP::Delete.new(uri.path)
      gdata_headers!(request)
      send_request(uri, request, options)
    end

    private
    def send_request(uri, request, options={})
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      headers!(request, options[:headers])
      body!(request, options[:body])
      http.request(request)
    end

    def gdata_headers!(request)
      request.add_field('Authorization', "GoogleLogin auth=#{token}")
      request.add_field('GData-Version', '3.0')
    end

    def headers!(request, headers)
      headers.each do |key, value|
        request.add_field(key, value)
      end if headers
    end

    def body!(request, body)
      request.body = body if body
    end
  end
end
