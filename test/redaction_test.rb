require "test_helper"

class RedactionTest < Minitest::Test
  MASK = /<redacted \h{8}>/

  def test_keeps_keys_and_nesting_and_masks_values
    assert_match(/\Atop:\n  secret: #{MASK}\n\z/, redact("top:\n  secret: hunter2\n"))
  end

  def test_output_never_contains_a_value
    yaml = <<~YAML
      # aws_secret: hunter2-in-a-comment
      plain: hunter2-plain # hunter2-trailing
      "quoted key": "hunter2 # quoted"
      single: 'hunter2-single'
      number: 5432
      block: |
        hunter2-block-one
        hunter2-block-two
      folded: >-
        hunter2-folded
        hunter2-more

      multi: hunter2-first
        hunter2-continued
      anchored: &shared hunter2-anchored
      aliased: *shared
      tagged: !!str hunter2-tagged
      list:
        - hunter2-item
        - nested: hunter2-deep
      flow: [hunter2-a, "hunter2-b", {c: hunter2-d}]
      unicode: "hünter2 ✓" # hunter2-after-multibyte
      last: hunter2-last
    YAML

    redacted = redact(yaml)

    refute_match(/h[uü]nter2|5432/, redacted)
    %w[plain "quoted\ key" single number block folded multi anchored aliased tagged list nested flow c unicode last].each do |key|
      assert_includes redacted, "#{key}:"
    end
    assert_equal YAML.load(yaml, aliases: true).keys, YAML.load(redacted, aliases: true).keys
  end

  def test_keeps_one_line_per_single_line_entry
    yaml = "a: one\nb: two # note\n\n# heading\nc:\n  d: three\n"

    assert_equal yaml.lines.count, redact(yaml).lines.count
  end

  def test_same_value_has_the_same_fingerprint_and_a_changed_value_does_not
    assert_equal redact("token: abc\n"), redact("token: abc\n")
    refute_equal redact("token: abc\n"), redact("token: abd\n")
  end

  def test_fingerprints_depend_on_the_key
    refute_equal redact("token: abc\n"), redact("token: abc\n", key: "another key")
  end

  def test_leaves_empty_values_and_aliases_alone
    assert_equal "empty:\nalso: *ref\n", redact("empty:\nalso: *ref\n")
  end

  def test_keeps_anchors_so_aliases_still_resolve
    assert_match(/\Abase: &base #{MASK}\ncopy: \*base\n\z/, redact("base: &base secret\ncopy: *base\n"))
  end

  def test_masks_comments
    assert_match(/\A# #{MASK}\nkey: #{MASK} # #{MASK}\n\z/, redact("# old_token: abc123\nkey: value # was xyz\n"))
  end

  def test_masks_every_line_of_content_that_is_not_yaml
    redacted = redact("key: [unclosed\nsecret: hunter2\n")

    assert_match(/\A#{MASK}\n#{MASK}\n\z/, redacted)
  end

  def test_empty_content
    assert_equal "", redact("")
  end

  def test_crlf_line_endings
    assert_match(/\Aa: #{MASK}\r\nb: #{MASK}\r\n\z/, redact("a: one\r\nb: two\r\n"))
  end

  def test_counts_line_breaks_as_the_parser_does
    [ "\r", "\u0085", "\u2028", "\u2029" ].each do |line_break|
      redacted = redact("a: \"hunter2#{line_break}hunter2\"\nb: hunter2 # hunter2\nc: hunter2\n")

      assert_match(/\Aa: #{MASK}\nb: #{MASK} # #{MASK}\nc: #{MASK}\n\z/, redacted, line_break.inspect)
    end
  end

  def test_lone_carriage_returns_as_line_endings
    assert_match(/\Aa: #{MASK}\rb: #{MASK} # #{MASK}\r\z/, redact("a: hunter2\rb: hunter2 # hunter2\r"))
  end

  def test_masks_every_line_when_masking_would_leave_part_of_a_value
    misaligned = Class.new(RedactedCredentialDiff::Redaction) do
      def span_of(node)
        super.then { |span| span.begin...(span.end - 1) }
      end
    end

    assert_match(/\A#{MASK}\n#{MASK}\n\z/, misaligned.new("token: hunter2\nother: hunter2\n", key: "0123456789abcdef").to_s)
  end

  private
    def redact(yaml, key: "0123456789abcdef")
      RedactedCredentialDiff::Redaction.new(yaml, key: key).to_s
    end
end
