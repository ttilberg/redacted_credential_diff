# redacted_credential_diff

A git diff driver for Rails encrypted credentials that shows which keys changed without printing their values.

```diff
 top:
-  secret: <redacted efb7dccb>
+  secret: <redacted 75d634fb>
+  token: <redacted 1c0e77a2>
```

Rails' built-in driver (`bin/rails credentials:diff`) decrypts both sides of a diff, so `git diff`, `git show` and `git log -p` print credentials in full. That output ends up in terminal scrollback, CI logs and the transcripts of any tool that ran the command. This gem replaces the decrypted text with a redacted rendering of the same file.

## Setup

```ruby
# Gemfile
gem "redacted_credential_diff"
```

```
bin/rails redacted_credential_diff:enroll
git commit .gitattributes
```

`enroll` is run once per project. Nothing is run per developer.

## How it works

Git splits a diff driver into two parts.

- `.gitattributes` is committed and names the driver for each credentials file. `enroll` assigns `diff=redacted_credentials`, replacing Rails' `diff=rails_credentials` entries.
- The driver's command lives in each clone's `.git/config`, which cannot be committed. A Railtie writes it whenever the app loads in a development or test checkout.

Git then calls `bundle exec redacted_credential_diff <path>` once for each side of a diff and compares the two outputs itself. The command never sees both sides; it only renders one file.

The command does not load the Rails app. It decrypts with `ActiveSupport::EncryptedConfiguration` and finds the key by Rails' naming convention: `config/credentials/<name>.key` for `config/credentials/<name>.yml.enc` when that key exists, otherwise `config/master.key`. `RAILS_MASTER_KEY` takes precedence, as in Rails.

### What a redacted file looks like

Keys, nesting and line layout are kept. Every value and every comment is replaced by `<redacted xxxxxxxx>`, where the eight hex digits are a truncated HMAC-SHA256 of the original text, keyed with the credentials encryption key.

- A changed value produces a different fingerprint, so the line shows as changed.
- The same value produces the same fingerprint on both sides, so unchanged lines stay out of the diff.
- Without the encryption key, a fingerprint cannot be checked against guessed values.

Comments are masked because credentials files commonly hold commented-out entries. Values are located by source position from the YAML parser, so multi-line and block scalars are masked in full. Content that does not parse as YAML is masked line by line.

### What each checkout shows

| State of the checkout | `git diff` of a credentials file |
| --- | --- |
| Gem installed, app loaded at least once | Redacted |
| Fresh clone, app never loaded | Encrypted file as stored |
| No encryption key available | Encrypted file as stored |
| Branch that predates the gem | `fatal: unable to read files to diff` |

No state prints decrypted credentials. The last row holds because the Railtie also points Rails' `rails_credentials` driver at the redacting command; on a branch where that command does not exist, git aborts the diff. Having the driver defined also stops `bin/rails credentials:edit` from installing the decrypting one.

## Limits

- This covers git's diff output only. `bin/rails credentials:show` and `credentials:edit` are unchanged.
- `git diff --no-textconv` and hosted diff views bypass the driver and show the encrypted file.
- Identical values under different keys share a fingerprint.
- A key kept at a custom `config.credentials.key_path` is not found, so those files diff as stored.
- The command assumes the Gemfile is at the top of the git working tree, where git runs it.
