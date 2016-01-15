Gem::Specification.new do |s|
  s.name        = 'parse-uk-addresses'
  s.version     = '0.0.1'
  s.date        = '2016-01-15'
  s.summary     = "Code for parsing UK addresses"
  s.description = "This project includes code that aims to help the parsing of UK addresses, as well as adding useful information to those addresses. It uses open data sources stored within a CouchDB database to provide geographical data that informs the address parsing and validation."
  s.authors     = ["Phil Cowans", "Open Data Institute"]
  s.email       = 'phil@philcowans.com'
  s.files       = ["lib/parse-uk-addresses.rb", "lib/parse.rb"]
  s.homepage    = 'https://github.com/theodi/parse-uk-addresses'
  s.license     = 'MIT'
  s.add_runtime_dependency 'couchrest', ['= 2.0.0.rc2']
  s.add_runtime_dependency 'dotenv'
  s.add_runtime_dependency 'rest-client'
end