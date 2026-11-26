require "pathname"

module RedactedCredentialDiff
  # The git diff driver that renders credentials files through
  # `bundle exec redacted_credential_diff`.
  #
  # Git splits a diff driver in two. The .gitattributes file is committed and
  # names the driver for each credentials file; the driver's command lives in
  # each clone's own git config and cannot be committed. A checkout that has
  # not installed the command diffs the encrypted file as-is.
  class DiffDriver
    NAME = "redacted_credentials"

    # Rails' own driver prints decrypted credentials. It is pointed at the same
    # command so that branches still naming it in .gitattributes are covered.
    NAMES = [ NAME, "rails_credentials" ]

    COMMAND = "bundle exec redacted_credential_diff"

    ATTRIBUTES = <<~END
      config/credentials/*.yml.enc diff=#{NAME}
      config/credentials.yml.enc diff=#{NAME}
    END

    def initialize(root)
      @root = Pathname(root)
    end

    # Defines the driver in this clone's git config.
    def install
      return unless checkout?

      NAMES.each { |name| git "config", "diff.#{name}.textconv", COMMAND }
    end

    def installed?
      NAMES.all? { |name| git("config", "--get", "diff.#{name}.textconv").strip == COMMAND }
    end

    # Names the driver for the credentials files in .gitattributes, replacing
    # any driver already assigned to them.
    def enroll
      gitattributes.write(unassigned_attributes + ATTRIBUTES)
    end

    def enrolled?
      gitattributes.file? && gitattributes.read.include?(ATTRIBUTES)
    end

    private
      def checkout?
        @root.join(".git").exist?
      end

      # The existing .gitattributes without any diff driver for credentials files.
      def unassigned_attributes
        return "" unless gitattributes.file?

        gitattributes.read.lines(chomp: true).grep_v(%r{\Aconfig/credentials\S*\.yml\.enc\s+diff=}).map { |line| "#{line}\n" }.join
      end

      def gitattributes
        @root.join(".gitattributes")
      end

      def git(*arguments)
        IO.popen([ "git", *arguments ], chdir: @root.to_s, err: File::NULL, &:read)
      rescue Errno::ENOENT
        ""
      end
  end
end
