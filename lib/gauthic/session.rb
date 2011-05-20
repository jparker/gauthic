module Gauthic
  # Gauthic::SharedContact::Session authenticates as a domain administrator for the
  # Shared Contacts API using the ClientLogin method. Upon authentication Google
  # returns a token which must be included in the headers of all subsequent requests.
  # This is handled automatically when using the #get, #post, #put and #delete
  # methods.
  class Session
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
        raise AuthenticationError, result.body
      end
    end

    # Issues a GET request for +uri+. Wraps Net::HTTP::Get adding the required
    # Authorization and GData-Version headers.
    def get(uri)
      uri = URI.parse(uri)
      request = Net::HTTP::Get.new(uri.path)
      add_gdata_headers!(request)
      send_request(uri, request)
    end

    # Issues a POST request for +uri+. Wraps Net::HTTP::Post adding the required
    # Authorization and GData-Version headers.
    def post(uri, options={})
      uri = URI.parse(uri)
      request = Net::HTTP::Post.new(uri.path)
      add_gdata_headers!(request)
      apply_options!(request, options)
      send_request(uri, request)
    end

    # Issues a PUT request for +uri+. Wraps Net::HTTP::Put adding the required
    # Authorization and GData-Version headers.
    def put(uri, options={})
      uri = URI.parse(uri)
      request = Net::HTTP::Put.new(uri.path)
      add_gdata_headers!(request)
      apply_options!(request, options)
      send_request(uri, request)
    end

    # Issues a DELETE request for +uri+. Wraps Net::HTTP::Delete adding the required
    # Authorization and GData-Version headers.
    def delete(uri, options={})
      uri = URI.parse(uri)
      request = Net::HTTP::Delete.new(uri.path)
      add_gdata_headers!(request)
      apply_options!(request, options)
      send_request(uri, request)
    end

    private
    def send_request(uri, request)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      http.request(request)
    end

    def add_gdata_headers!(request)
      request.add_field('Authorization', "GoogleLogin auth=#{token}")
      request.add_field('GData-Version', '3.0')
    end

    def apply_options!(request, options)
      options[:headers].each do |key, value|
        request.add_field(key, value)
      end if options[:headers]
      request.body = options[:body] if options[:body]
    end
  end
end
