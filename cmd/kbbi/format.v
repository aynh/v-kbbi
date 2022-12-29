module main

import arrays { map_indexed }
import kbbi { Entry, EntryExampleItem, EntryItem }
import math
import strings
import term

fn format_entry(e Entry) string {
	mut builder := strings.new_builder(0)

	heading := if e.original_word == '' {
		e.title
	} else {
		e.original_word + ' >> ' + e.title
	}
	builder.writeln('  ' + term.bold(heading))

	terminal_width, _ := term.get_terminal_size()
	entry_prefix := '   '
	if e.entries.len == 1 {
		builder.write_string(wrap_word(
			s: format_entry_item(e.entries[0])
			prefix: entry_prefix
			max_width: terminal_width
		))
	} else if e.entries.len > 1 {
		entries := e.entries.map(format_entry_item)
		numbered_entries := map_indexed(entries, fn (i int, entry string) string {
			return '${i + 1}. ${entry}'
		})

		wrapped_entries := numbered_entries.map(wrap_word(
			s: it
			indent: 2 + math.count_digits(it.before('.').int())
			prefix: entry_prefix
			max_width: terminal_width
		)).join('\n')
		builder.write_string(wrapped_entries)
	}

	return builder.str()
}

fn format_entry_item(e EntryItem) string {
	mut builder := strings.new_builder(0)

	kinds := e.kinds.map(it.abbreviation + ' ').join('')
	builder.write_string(term.italic(term.red(kinds)))

	builder.write_string(e.description)

	if e.examples.len > 0 {
		builder.write_string(':')

		examples := e.examples.map(format_entry_example_item).join(';')
		builder.write_string(term.italic(term.dim(examples)))
	}

	return builder.str()
}

fn format_entry_example_item(e EntryExampleItem) string {
	mut builder := strings.new_builder(0)

	builder.write_string(' ' + e.value)

	if e.description != '' {
		builder.write_string(' ' + term.red(e.description))
	}

	return builder.str()
}
