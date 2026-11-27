require "test_helper"
require "tmpdir"

class CredentialsFileTest < Minitest::Test
  MASK = /<redacted \h{8}>/

  def setup
    @root = Pathname(Dir.mktmpdir)
    @root.join("config/credentials").mkpath
    @master_key = write_key("config/master.key")
  end

  def teardown
    @root.rmtree
  end

  def test_redacts_the_main_file_with_the_master_key
    encrypt "config/credentials.yml.enc", "token: hunter2\n", key: @master_key

    assert_match(/\Atoken: #{MASK}\n\z/, redacted("config/credentials.yml.enc"))
  end

  def test_redacts_an_environment_file_with_its_own_key
    encrypt "config/credentials/production.yml.enc", "token: hunter2\n", key: write_key("config/credentials/production.key")

    assert_match(/\Atoken: #{MASK}\n\z/, redacted("config/credentials/production.yml.enc"))
  end

  def test_redacts_an_environment_file_that_shares_the_master_key
    encrypt "config/credentials/staging.yml.enc", "token: hunter2\n", key: @master_key

    assert_match(/\Atoken: #{MASK}\n\z/, redacted("config/credentials/staging.yml.enc"))
  end

  def test_finds_the_key_for_an_old_revision_in_a_temp_file
    key = write_key("config/credentials/production.key")

    Dir.mktmpdir("git-blob-") do |directory|
      blob = encrypt File.join(directory, "production.yml.enc"), "token: hunter2\n", key: key

      assert_match(/\Atoken: #{MASK}\n\z/, redacted(blob))
    end
  end

  def test_fingerprints_match_across_the_working_tree_file_and_an_old_revision
    encrypt "config/credentials.yml.enc", "token: hunter2\n", key: @master_key

    Dir.mktmpdir("git-blob-") do |directory|
      blob = encrypt File.join(directory, "credentials.yml.enc"), "token: hunter2\n", key: @master_key

      assert_equal redacted("config/credentials.yml.enc"), redacted(blob)
    end
  end

  def test_redacts_values_with_multibyte_characters_in_full
    encrypt "config/credentials.yml.enc", "pass: \"日本語-hunter2\" # café hunter2\nclé: hunter2\n", key: @master_key

    assert_match(/\Apass: #{MASK} # #{MASK}\nclé: #{MASK}\n\z/, redacted("config/credentials.yml.enc"))
  end

  def test_empty_credentials_are_not_mistaken_for_a_missing_key
    encrypt "config/credentials.yml.enc", "", key: @master_key

    assert_equal "", redacted("config/credentials.yml.enc")
  end

  def test_returns_the_stored_file_without_a_key
    stored = encrypt("config/credentials.yml.enc", "token: hunter2\n", key: @master_key).read
    @root.join("config/master.key").delete

    assert_equal stored, redacted("config/credentials.yml.enc")
  end

  def test_returns_the_stored_file_when_encrypted_under_another_key
    stored = encrypt("config/credentials.yml.enc", "token: hunter2\n", key: ActiveSupport::EncryptedConfiguration.generate_key).read

    assert_equal stored, redacted("config/credentials.yml.enc")
  end

  private
    def redacted(path)
      RedactedCredentialDiff::CredentialsFile.new(@root.join(path), root: @root).redacted
    end

    def write_key(path)
      ActiveSupport::EncryptedConfiguration.generate_key.tap { |key| @root.join(path).write(key) }
    end

    # Writes the YAML as binary, which is how `credentials:edit` stores it.
    def encrypt(path, yaml, key:)
      @root.join(path).tap do |file|
        key_file = @root.join("encrypting.key")
        key_file.write(key)
        ActiveSupport::EncryptedConfiguration.new(config_path: file, key_path: key_file, env_key: "UNUSED_KEY", raise_if_missing_key: true).write(yaml.b)
        key_file.delete
      end
    end
end
