module main

import strings
import term

[params]
struct WrapWordConfig {
	s         string [required]
	prefix    string
	indent    int
	max_width int = 80
}

// wrap_word wraps string `s` with maximum width `max_width`
// while adding `prefix` for each lines and indents them by `indent`
// for each lines after the first one (so 2nd, 3rd, 4th, etc)
fn wrap_word(c WrapWordConfig) string {
	expected_lines := (c.s.len / c.max_width) + 1
	mut builder := strings.new_builder(expected_lines + c.s.len + (c.prefix.len * expected_lines) +
		(c.indent * expected_lines))

	// first line prefix
	builder.write_string(c.prefix)

	// char counter (for current line)
	mut char_counter := 0
	// max_width minus prefix len here because
	// we're adding prefix for each lines
	max_width := c.max_width - c.prefix.len
	// for each word:
	for i, word in c.s.split(' ') {
		// get the actual word width (without ANSI colors)
		word_without_ansi := term.strip_ansi(word)
		// first word won't be needing these
		if i != 0 {
			// if we won't reach max_width (if we add this word)
			if (char_counter + word_without_ansi.len) < max_width {
				// add a space
				builder.write_string(' ')
				char_counter += 1
			} else {
				// or else add a newline and prefix
				builder.write_string('\n' + c.prefix)

				// reset the char counter because
				// we're moving to another line
				char_counter = 0
				if c.indent > 0 {
					// add the indents
					builder.write_string(` `.repeat(c.indent))
					char_counter += c.indent
				}
			}
		}

		// add the actual word (with ANSI)
		builder.write_string(word)
		// but only increment counter with without-ansi one because
		// this is the actual width of what will get displayed
		char_counter += word_without_ansi.len
	}

	return builder.str()
}
