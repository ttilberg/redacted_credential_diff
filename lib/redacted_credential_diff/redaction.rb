require "openssl"
require "psych"

module RedactedCredentialDiff
  # Credentials YAML with every value and comment replaced by a fingerprint.
  # Keys, nesting and line layout are left as written, so a diff of two
  # redactions shows which entries were added, removed or changed without
  # printing what they hold.
  class Redaction
    MASK = /\A<redacted \h{8}>\z/
    COMMENT_MASK = /\A# <redacted \h{8}>\z/

    # Line breaks as libyaml counts them, which is more than "\n". Line numbers
    # from the parser only map back to the text when both agree.
    LINE_BREAK = /\r\n|[\r\n\u0085\u2028\u2029]/
    COMMENT = /#[^\r\n\u0085\u2028\u2029]*/

    # +key+ is the credentials encryption key. Fingerprints are keyed with it so
    # they are stable across both sides of a diff but cannot be reversed by
    # guessing values offline.
    def initialize(yaml, key:)
      @yaml = yaml
      @key = key
    end

    def to_s
      return masked_line_by_line unless verified?

      masked
    rescue Psych::SyntaxError
      masked_line_by_line
    end

    protected
      def key_names
        keys.map(&:value)
      end

      # True when every value and comment is already a fingerprint.
      def masked?
        values.all? { |node| MASK.match?(node.value) } && comments.all? { |span| COMMENT_MASK.match?(@yaml[span]) }
      end

    private
      # Masking depends on the parser's source positions lining up with the
      # text. The result is checked rather than trusted: it must parse to the
      # same keys and hold nothing else but fingerprints.
      def verified?
        result = Redaction.new(masked, key: @key)
        result.key_names == key_names && result.masked?
      end

      def masked
        @masked ||= masks.sort_by { |span, _| -span.begin }.each_with_object(@yaml.dup) do |(span, mask), text|
          text[span] = mask
        end
      end

      def masks
        value_masks.merge(comment_masks)
      end

      def value_masks
        values.to_h { |node| [ span_of(node), [ anchor_of(node), fingerprint(source_of(node)) ].compact.join(" ") ] }
      end

      def comment_masks
        comments.to_h { |span| [ span, "# #{fingerprint(@yaml[span])}" ] }
      end

      # Scalars holding credentials: everything that is not a mapping key.
      def values
        scalars.reject { |node| keys.include?(node) || span_of(node).size.zero? }
      end

      def keys
        @keys ||= mappings.flat_map { |mapping| mapping.children.each_slice(2).map(&:first) }.grep(Psych::Nodes::Scalar).to_set
      end

      def scalars
        @scalars ||= document.grep(Psych::Nodes::Scalar)
      end

      def mappings
        document.grep(Psych::Nodes::Mapping)
      end

      def document
        @document ||= Psych.parse_stream(@yaml)
      end

      # Comments can hold commented-out credentials, so they are masked too. A
      # "#" inside a scalar is part of that scalar, not a comment.
      def comments
        @yaml.enum_for(:scan, COMMENT).map { Regexp.last_match.begin(0)...Regexp.last_match.end(0) }.reject do |comment|
          scalar_spans.any? { |scalar| scalar.cover?(comment.begin) }
        end
      end

      def scalar_spans
        @scalar_spans ||= scalars.map { |node| span_of(node) }
      end

      # Character range of a scalar in the source. Block scalars are reported as
      # running to the start of the following line; the trailing whitespace is
      # left in place so the line structure survives.
      def span_of(node)
        first = offset(node.start_line, node.start_column)
        first...(first + @yaml[first...offset(node.end_line, node.end_column)].rstrip.length)
      end

      def source_of(node)
        @yaml[span_of(node)]
      end

      def anchor_of(node)
        "&#{node.anchor}" if node.anchor
      end

      def offset(line, column)
        line_offsets.fetch(line, @yaml.length) + column
      end

      def line_offsets
        @line_offsets ||= [ 0 ] + @yaml.enum_for(:scan, LINE_BREAK).map { Regexp.last_match.end(0) }
      end

      # Content that is not valid YAML has no keys to preserve.
      def masked_line_by_line
        @yaml.lines(chomp: true).map { |line| fingerprint(line) unless line.strip.empty? }.join("\n") + "\n"
      end

      def fingerprint(text)
        "<redacted #{OpenSSL::HMAC.hexdigest("SHA256", @key, text)[0, 8]}>"
      end
  end
end
