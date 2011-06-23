spec_dir = File.dirname(__FILE__)
lib_dir  = File.expand_path(File.join(spec_dir, '..', 'lib'))

$:.unshift(lib_dir)
$:.uniq!

module HelperMethods
  private
  def fixture(file)
    File.open(File.expand_path(File.join(File.dirname(__FILE__), 'fixtures', file)))
  end

  def stub_connect!
    stub_request(:post, 'https://www.google.com/accounts/ClientLogin').
      to_return(:body => fixture('successful_authentication.txt'), :status => 200)
    Gauthic::SharedContact.connect!('admin@example.com', 'secret')
  end
end

RSpec.configure do |config|
  config.include HelperMethods
  config.mock_with :mocha
end

require 'webmock/rspec'
require 'mocha'
require 'equivalent-xml/rspec_matchers'

require 'gauthic'
