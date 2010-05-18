require 'rake'

Gem::Specification.new do |s|
  s.name = "fastprowl"
  s.version = "0.2"
  s.date = Time.now
  s.authors = ["Matthew Riley MacPherson"]
  s.email = "matt@lonelyvegan.com"
  s.has_rdoc = true
  s.rdoc_options << '--title' << "FastProwl - Ruby Prowl library that uses libcurl-multi for parallel requests" << '--main' << 'README.markdown' << '--line-numbers'
  s.summary = "Ruby Prowl library that uses libcurl-multi for parallel requests"
  s.homepage = "http://github.com/tofumatt/FastProwl"
  s.files = FileList['lib/*.rb', '[A-Z]*', 'fastprowl.gemspec', 'test/*.rb'].to_a
  s.test_file = 'test/fastprowl_test.rb'
  s.add_dependency('typhoeus', '>= 0.1.0')
  s.add_development_dependency('mocha') # Used to run the tests, that's all...
end
