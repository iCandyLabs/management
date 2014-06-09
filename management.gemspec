# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "management/version"

Gem::Specification.new do |s|
  s.name          = 'management'
  s.version       = Management::VERSION
  s.email         = 'steven@cleancoders.com'
  s.authors       = ["Steven Degutis"]
  s.homepage      = 'https://github.com/sdegutis/management'
  s.license       = 'MIT'
  s.summary       =
  s.description   = "Minimalist EC2 configuration & deployment tool."
  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- spec/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency 'fog'
  s.add_dependency 'unf' # just to shut up the warnings

  s.add_development_dependency 'rake'
  s.add_development_dependency 'pry'
  s.add_development_dependency 'fakefs'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'guard-rspec'
end
