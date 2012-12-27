# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'reverse-tunnel/version'

Gem::Specification.new do |gem|
  gem.name          = "reverse-tunnel"
  gem.version       = ReverseTunnel::VERSION
  gem.authors       = ["Alban Peignier", "Florent Peyraud"]
  gem.email         = ["alban@tryphon.eu", "florent@tryphon.eu"]
  gem.description   = %q{Create easily a tunnel to forward connection (like a ssh) to the client host}
  gem.summary       = %q{Forward a tcp connection to client host}
  gem.homepage      = "http://projects.tryphon.eu/projects/reverse-tunnel"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_runtime_dependency "eventmachine"
  gem.add_runtime_dependency "msgpack"
  gem.add_runtime_dependency "eventmachine_httpserver"
  gem.add_runtime_dependency "json"
  gem.add_runtime_dependency "trollop"
  gem.add_runtime_dependency "SyslogLogger"

  gem.add_development_dependency "simplecov"
  gem.add_development_dependency "rspec"
  gem.add_development_dependency "guard"
  gem.add_development_dependency "guard-rspec"
  gem.add_development_dependency "rake"
  gem.add_development_dependency "rest-client"
end
