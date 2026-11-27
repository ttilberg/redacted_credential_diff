require "test_helper"
require "tmpdir"

class DiffDriverTest < Minitest::Test
  def setup
    @root = Pathname(Dir.mktmpdir)
    system "git", "init", "--quiet", @root.to_s
    @driver = RedactedCredentialDiff::DiffDriver.new(@root)
  end

  def teardown
    @root.rmtree
  end

  def test_install_defines_the_driver_under_both_names
    refute @driver.installed?

    @driver.install

    assert @driver.installed?
    assert_equal "bundle exec redacted_credential_diff", config("diff.redacted_credentials.textconv")
    assert_equal "bundle exec redacted_credential_diff", config("diff.rails_credentials.textconv")
  end

  def test_install_replaces_the_decrypting_rails_driver
    system "git", "-C", @root.to_s, "config", "diff.rails_credentials.textconv", "bin/rails credentials:diff"

    refute @driver.installed?
    @driver.install

    assert_equal "bundle exec redacted_credential_diff", config("diff.rails_credentials.textconv")
  end

  def test_install_does_nothing_outside_a_git_checkout
    Dir.mktmpdir do |directory|
      driver = RedactedCredentialDiff::DiffDriver.new(directory)
      driver.install

      refute driver.installed?
    end
  end

  def test_enroll_replaces_the_rails_entries
    @root.join(".gitattributes").write <<~END
      db/schema.rb linguist-generated
      config/credentials/*.yml.enc diff=rails_credentials
      config/credentials.yml.enc diff=rails_credentials
    END

    @driver.enroll

    assert_equal <<~END, @root.join(".gitattributes").read
      db/schema.rb linguist-generated
      config/credentials/*.yml.enc diff=redacted_credentials
      config/credentials.yml.enc diff=redacted_credentials
    END
  end

  def test_enroll_is_idempotent_and_creates_the_file
    2.times { @driver.enroll }

    assert_equal RedactedCredentialDiff::DiffDriver::ATTRIBUTES, @root.join(".gitattributes").read
  end

  def test_enroll_adds_a_missing_final_newline
    @root.join(".gitattributes").write "vendor/* linguist-vendored"

    @driver.enroll

    assert_equal "vendor/* linguist-vendored\n#{RedactedCredentialDiff::DiffDriver::ATTRIBUTES}", @root.join(".gitattributes").read
  end

  private
    def config(name)
      `git -C #{@root} config --get #{name}`.strip
    end
end
