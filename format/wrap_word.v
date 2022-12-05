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
	mut builder := strings.new_builder(0)

	builder.write_string(c.prefix)

	mut char_count := 0
	max_width := c.max_width - c.prefix.len - 1
	for i, word in c.s.split(' ') {
		if char_count != 0 && i > 0 {
			builder.write_string(' ')
			char_count += 1
		}

		word_without_ansi := term.strip_ansi(word)
		if (char_count + word_without_ansi.len) > max_width {
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
