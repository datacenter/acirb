require './lib/acirb/version'

Gem::Specification.new do |s|
  s.name        = 'acirb'
  s.version     = ACIrb::VERSION
  s.date        = Time.new().strftime('%Y-%m-%d')
  s.summary     = 'ACIrb - Cisco APIC Ruby SDK'
  s.description = 'Cisco APIC Ruby SDK'
  s.authors     = ['Paul Lesiak', 'Jerrod Carpenter']
  s.email       = 'palesiak@cisco.com'
  s.files       = Dir.glob('{lib}/*')
  s.files       = Dir.glob('{lib}/**/*')
  s.homepage    = 'http://github.com/datacenter/acirb'
  s.license     = 'Private'
  s.add_runtime_dependency 'httpclient', '~> 2.6', '>= 2.6.0.1'
  s.add_runtime_dependency 'nokogiri', '~> 1.6', '>= 1.6.0'
  s.add_runtime_dependency 'json', '~> 1.8', '>= 1.8.0'
  s.add_runtime_dependency 'websocket', '~> 1.0'
  s.add_development_dependency 'simplecov', '~> 0'
  s.add_development_dependency 'rspec', '~> 0'
end
