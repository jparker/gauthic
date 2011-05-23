require 'nokogiri'
require 'net/https'

Dir[File.expand_path(File.join(File.dirname(__FILE__), 'gauthic', '**', '*.rb'))].each do |file|
  require file
end
