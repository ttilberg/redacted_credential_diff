namespace :redacted_credential_diff do
  desc "Assign the redacting diff driver to the credentials files in .gitattributes"
  task :enroll do
    driver = RedactedCredentialDiff::DiffDriver.new(Rails.root)
    driver.enroll
    driver.install

    puts "Credentials files now diff through `#{RedactedCredentialDiff::DiffDriver::COMMAND}`. Commit .gitattributes to enroll the rest of the team."
  end
end
