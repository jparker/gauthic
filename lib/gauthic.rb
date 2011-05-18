require 'nokogiri'
require 'net/https'

module Gauthic
  class AuthenticationError < StandardError
  end

  class NoActiveSession < StandardError
  end
end

Dir[File.expand_path(File.join(File.dirname(__FILE__), 'gauthic', '**', '*.rb'))].each do |file|
  require file
end
