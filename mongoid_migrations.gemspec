require File.join(File.dirname(__FILE__), 'lib', 'mongoid_migrations', 'version')

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'mongoid_migrations'
  s.version     = ::Mongoid::Migrations::VERSION
  s.summary     = 'Data migrations for Mongoid in Active Record style, minus column input.'
  s.license     = 'MIT'
  s.description = 'Migrations for the Mongoid'

  s.required_ruby_version     = '>= 1.9.2'

  s.author            = 'Alexander Simonov'
  s.email             = 'alex@simonov.me'
  s.date              = %q{2014-01-23}
  s.homepage          = 'http://github.com/simonoff/mongoid_migrations'

  s.rubyforge_project = "mongoid_migrations"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency('bundler', '>= 1.0.0')
  s.add_dependency('activesupport',  '>= 3.2.0', '< 5')
  s.add_dependency('mongoid', '>= 3.0.0')
  s.add_development_dependency('railties', '>= 3.2.0', '< 5')
  s.add_development_dependency('minitest', '>= 4')
  s.add_development_dependency('simplecov', '>= 0.8')
  s.add_development_dependency('coveralls')
end