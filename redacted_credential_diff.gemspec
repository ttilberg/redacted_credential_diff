require_relative "lib/redacted_credential_diff/version"

Gem::Specification.new do |spec|
  spec.name = "redacted_credential_diff"
  spec.version = RedactedCredentialDiff::VERSION
  spec.authors = [ "Tim Tilberg" ]
  spec.summary = "Git diffs of Rails encrypted credentials that show which keys changed without printing their values."
  spec.description = <<~END
    A git diff driver for Rails encrypted credentials. Replaces the decrypting driver Rails installs, so that
    git diff, git show and git log -p render each credentials file with its keys intact and every value and
    comment replaced by a keyed fingerprint.
  END
  spec.homepage = "https://github.com/ttilberg/redacted_credential_diff"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata = {
    "source_code_uri" => spec.homepage,
    "bug_tracker_uri" => "#{spec.homepage}/issues",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir["lib/**/*", "exe/*", "README.md", "LICENSE.txt"]
  spec.bindir = "exe"
  spec.executables = [ "redacted_credential_diff" ]

  spec.add_dependency "activesupport", ">= 7.0"
  spec.add_dependency "railties", ">= 7.0"
end
