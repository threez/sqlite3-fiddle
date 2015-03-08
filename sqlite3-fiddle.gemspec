# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'sqlite3/version'

Gem::Specification.new do |spec|
  spec.name          = "sqlite3-fiddle"
  spec.version       = SQLite3::VERSION
  spec.authors       = ["Vincent Landgraf"]
  spec.email         = ["vilandgr+sqlite@googlemail.com"]

  spec.summary       = %q{Ruby bindings for the SQLite3 embedded database - without compiling}
  spec.description   = %q{Ruby bindings for the SQLite3 embedded database - without compiling}
  spec.homepage      = "https://github.com/threez/sqlite3-fiddle"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.8"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5.0"
end
