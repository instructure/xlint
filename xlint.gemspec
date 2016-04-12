require_relative 'lib/xlint/version'

Gem::Specification.new do |spec|
  spec.name          = 'xlint'
  spec.version       = Xlint::VERSION
  spec.authors       = ['Taylor Wilson']
  spec.email         = ['twilson@instructure.com']
  spec.summary       = 'Command-line tool for linting Xcode project files.'
  spec.description   = 'Checks for deployment target changes in Xcode project files.'
  spec.license       = 'Apache-2.0'
  spec.homepage      = 'https://github.com/mobile-qa/xlint'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']
  spec.bindir        = 'bin'

  spec.required_ruby_version = '>= 2.0.0'

  spec.add_dependency 'git', '~> 1.3', '>= 1.3.0'
  spec.add_dependency 'git_diff_parser', '~> 2.2', '>= 2.2.0'
  spec.add_dependency 'json', '~> 1.8.3', '>= 1.8.3'
  spec.add_dependency 'octokit', '~> 4.3', '>= 4.3.0'
  spec.add_dependency 'gergich', '~> 0.1.0', '>= 0.1.0'

  spec.add_development_dependency 'bundler', '~> 1.11', '>= 1.11.0'
  spec.add_development_dependency 'byebug', '~> 8.2.2', '>= 8.2.2'
  spec.add_development_dependency 'rake', '~> 11.1.1', '>= 11.1.1'
  spec.add_development_dependency 'rspec', '~> 3.4', '>= 3.4.0'
  spec.add_development_dependency 'rubocop', '~> 0.38', '>= 0.38'
  spec.add_development_dependency 'simplecov', '~> 0.11.2', '>= 0.11.2'
  spec.add_development_dependency 'coveralls', '~> 0.8.13', '>= 0.8.3'
end
