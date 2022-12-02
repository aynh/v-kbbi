module format

import arrays { map_indexed }
import client { KbbiEntry, KbbiEntryExample, KbbiResult }
import strings
import term

pub fn format_result(e KbbiResult) string {
	mut builder := strings.new_builder(0)

	builder.writeln('  ' + term.bold(e.title))

	entry_prefix := '   '
	if e.entries.len == 1 {
		builder.writeln(entry_prefix + format_entry(e.entries[0]))
	} else if e.entries.len > 1 {
		entries := e.entries.map(format_entry)
		numbered_entries := map_indexed(entries, fn (i int, entry string) string {
			return '${i + 1}. ${entry}'
		})
		builder.writeln(numbered_entries.map(entry_prefix + it).join('\n'))
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
