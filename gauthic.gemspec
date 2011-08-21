# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "gauthic/version"

Gem::Specification.new do |s|
  s.name        = "gauthic"
  s.version     = Gauthic::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["John Parker"]
  s.email       = ["jparker@urgetopunt.com"]
  s.homepage    = "https://github.com/jparker/gauthic"
  s.summary     = %q{Ruby interface to Google GData APIs}
  s.description = %q{Ruby interface to Google GData APIs such as Shared Contacts, etc.}

  s.rubyforge_project = "gauthic"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_runtime_dependency 'nokogiri', '~>1.5.0'
  s.add_development_dependency 'rake', '~>0.9.2'
  s.add_development_dependency 'rspec', '~>2.6.0'
  s.add_development_dependency 'webmock', '~>1.6.0'
  s.add_development_dependency 'mocha', '~>0.9.12'
  s.add_development_dependency 'equivalent-xml', '~>0.2.6'
end
