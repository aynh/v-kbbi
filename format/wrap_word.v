module format

import strings
import term

[params]
struct WrapWordConfig {
	s         string
	prefix    string
	indent    int
	max_width int = 80
}

fn wrap_word(c WrapWordConfig) string {
	expected_lines := (c.s.len / c.max_width) + 1
	mut builder := strings.new_builder(expected_lines + c.s.len + (c.prefix.len * expected_lines) +
		(c.indent * expected_lines))

	builder.write_string(c.prefix)

	mut char_count := 0
	max_width := c.max_width - c.prefix.len
	for word in c.s.split(' ') {
		word_without_ansi := term.strip_ansi(word)
		if (char_count + word_without_ansi.len) < max_width {
			builder.write_string(' ')
			char_count += 1
		} else {
			builder.write_string('\n' + c.prefix)

			char_count = 0
			if c.indent > 0 {
				builder.write_string(` `.repeat(c.indent))
				char_count += c.indent
			}
		}

		builder.write_string(word)
		char_count += word_without_ansi.len
	}

	return builder.str()
}
