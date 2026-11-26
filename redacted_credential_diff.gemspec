require_relative "lib/redacted_credential_diff/version"

Gem::Specification.new do |spec|
  spec.name = "redacted_credential_diff"
  spec.version = RedactedCredentialDiff::VERSION
  spec.authors = [ "Tim Tilberg" ]
  spec.summary = "Git diffs of Rails encrypted credentials that show which keys changed without printing their values."
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.files = Dir["lib/**/*", "exe/*", "README.md"]
  spec.bindir = "exe"
  spec.executables = [ "redacted_credential_diff" ]

  spec.add_dependency "railties", ">= 6.1"
end
