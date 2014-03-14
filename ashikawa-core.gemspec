# -*- encoding: utf-8 -*-
$:.push File.expand_path('../lib', __FILE__)
require 'ashikawa-core/version'

Gem::Specification.new do |gem|
  gem.name        = 'ashikawa-core'
  gem.version     = Ashikawa::Core::VERSION
  gem.authors     = ['moonglum']
  gem.email       = ['me@moonglum.net']
  gem.homepage    = 'http://triagens.github.com/ashikawa-core'
  gem.summary     = 'Ashikawa Core is a wrapper around the ArangoDB REST API'
  gem.description = 'Ashikawa Core is a wrapper around the ArangoDB REST API. It provides low level access and is intended to be used in ArangoDB ODMs and other tools.'
  gem.license = 'Apache License 2.0'

  gem.required_ruby_version = '>= 1.9.3'
  gem.requirements << 'ArangoDB, v1.4 or v2.0'

  gem.rubyforge_project = 'ashikawa-core'

  gem.files         = `git ls-files`.split('\n')
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split('\n')
  gem.executables   = `git ls-files -- bin/*`.split('\n').map{ |f| File.basename(f) }
  gem.require_paths = ['lib']

  # Runtime Dependencies
  gem.add_dependency 'faraday', '~> 0.8.8'
  gem.add_dependency 'faraday_middleware', '~> 0.9.0'
  gem.add_dependency 'json', '~> 1.8.1'
  gem.add_dependency 'null_logger', '~> 0.0.1'
  gem.add_dependency 'equalizer', '~> 0.0.8'

  # Development Dependencies
  gem.add_development_dependency 'rake', '~> 10.1.1'
  gem.add_development_dependency 'rspec', '~> 2.99.0.beta2'

  # Rubinius specific dependencies
  if RUBY_ENGINE == 'rbx'
    gem.add_dependency 'rubysl-base64'
    gem.add_dependency 'rubysl-singleton'
  end

  # JRuby specific dependencies
end
