require "rails/railtie"

module RedactedCredentialDiff
  class Railtie < Rails::Railtie
    # Runs as soon as the application is defined, which includes
    # `credentials:edit`: that command installs Rails' decrypting driver unless
    # one is already defined.
    config.before_configuration do
      driver = DiffDriver.new(Rails.root)
      driver.install if (Rails.env.development? || Rails.env.test?) && !driver.installed?
    end

    rake_tasks do
      load "redacted_credential_diff/tasks.rake"
    end
  end
end
