require "pathname"
require "active_support"
require "active_support/encrypted_configuration"

module RedactedCredentialDiff
  # One side of a credentials diff as git hands it to the driver: the working
  # tree file, or an old revision written to a temp file that keeps only the
  # original basename.
  #
  # The key is found by Rails' file naming convention rather than by loading
  # the app, so a key kept at a custom `config.credentials.key_path` is not found.
  class CredentialsFile
    def initialize(path, root: Dir.pwd)
      @path = Pathname(path)
      @root = Pathname(root)
    end

    # The decrypted contents with values redacted. A file that cannot be
    # decrypted is returned as stored, which is what git diffs with no driver.
    def redacted
      return stored if yaml.empty?

      Redaction.new(yaml, key: encrypted.key).to_s
    rescue ActiveSupport::MessageEncryptor::InvalidMessage
      stored
    end

    private
      # Rails stores credentials as written by a binary read, so they decrypt
      # as ASCII-8BIT. Redaction works in characters and needs them as text.
      def yaml
        @yaml ||= encrypted.read.dup.force_encoding(Encoding::UTF_8)
      end

      def stored
        @path.read
      end

      def encrypted
        @encrypted ||= ActiveSupport::EncryptedConfiguration.new \
          config_path: @path, key_path: key_path, env_key: "RAILS_MASTER_KEY", raise_if_missing_key: false
      end

      # config/credentials/production.yml.enc is encrypted with
      # config/credentials/production.key when that exists; everything else,
      # including config/credentials.yml.enc, with config/master.key.
      def key_path
        return environment_key_path if environment_key_path.exist?

        @root.join("config/master.key")
      end

      def environment_key_path
        @root.join("config/credentials", "#{@path.basename(".yml.enc")}.key")
      end
  end
end
