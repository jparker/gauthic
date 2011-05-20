require 'nokogiri'
require 'net/https'

module Gauthic
  # TODO: move to Gauthic::Session namespace
  class AuthenticationError < StandardError
  end

  # TODO: move to Gauthic::Session namespace
  class NoActiveSession < StandardError
  end
end

Dir[File.expand_path(File.join(File.dirname(__FILE__), 'gauthic', '**', '*.rb'))].each do |file|
  require file
end
