# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "gauthic/version"

Gem::Specification.new do |s|
  s.name        = "gauthic"
  s.version     = Gauthic::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["TODO: Write your name"]
  s.email       = ["TODO: Write your email address"]
  s.homepage    = ""
  s.summary     = %q{TODO: Write a gem summary}
  s.description = %q{TODO: Write a gem description}

  s.rubyforge_project = "gauthic"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_runtime_dependency 'nokogiri', '~>1.4.0'
  s.add_development_dependency 'rspec', '~>2.5.0'
  s.add_development_dependency 'webmock', '~>1.6.0'
  s.add_development_dependency 'mocha', '~>0.9.12'
  s.add_development_dependency 'equivalent-xml', '~>0.2.6'
end
