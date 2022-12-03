module format

import arrays { map_indexed }
import client { KbbiEntry, KbbiEntryExample, KbbiResult }
import math
import strings
import term

pub fn format_result(e KbbiResult) string {
	mut builder := strings.new_builder(0)

	builder.writeln('  ' + term.bold(e.title))

	terminal_width, _ := term.get_terminal_size()
	entry_prefix := '   '
	if e.entries.len == 1 {
		builder.writeln(wrap_word(
			s: format_entry(e.entries[0])
			prefix: entry_prefix
			max_width: terminal_width
		))
	} else if e.entries.len > 1 {
		entries := e.entries.map(format_entry)
		numbered_entries := map_indexed(entries, fn (i int, entry string) string {
			return '${i + 1}. ${entry}'
		})

		wrapped_entries := numbered_entries.map(wrap_word(
			s: it
			indent: 2 + math.count_digits(it.before('.').int())
			prefix: entry_prefix
			max_width: terminal_width
		)).join('\n')
		builder.writeln(wrapped_entries)
	}

	return builder.str()
}

fn format_entry(e KbbiEntry) string {
	mut builder := strings.new_builder(0)

	kinds := e.kind.map(it.abbreviation + ' ').join('')
	builder.write_string(term.italic(term.red(kinds)))

	builder.write_string(e.description)

	if e.examples.len > 0 {
		builder.write_string(':')

		examples := e.examples.map(format_entry_example).join(';')
		builder.write_string(term.italic(term.dim(examples)))
	}

	return builder.str()
}

fn format_entry_example(e KbbiEntryExample) string {
	mut builder := strings.new_builder(0)

	builder.write_string(' ' + e.value)

	if e.description != '' {
		builder.write_string(' ' + term.red(e.description))
	}

	return builder.str()
}
