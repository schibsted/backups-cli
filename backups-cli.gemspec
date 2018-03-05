$:.push File.expand_path("../lib", __FILE__)

require "backups/version"

Gem::Specification.new do |spec|
  spec.name          = "backups-cli"
  spec.version       = Backups::VERSION
  spec.description   = "This tool backups different data sources to S3."
  spec.summary       = "This tool backups different data sources to S3"
  spec.authors       = ["jpedro"]
  spec.email         = ["jpedro.barbosa@gmail.com"]
  spec.homepage      = "https://github.com/schibsted/backups-cli"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split $/
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename f }

  spec.add_dependency "thor"
  spec.add_dependency "json"
  spec.add_dependency "mysql2"
  spec.add_dependency "dogapi"
  spec.add_dependency "slack-notifier"
  spec.add_dependency "tablelize"
  spec.add_development_dependency "rake"
end
