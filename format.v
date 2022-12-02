module format

import client { KbbiEntry, KbbiResult }
import strings
import term

pub fn format_result(r KbbiResult) string {
	mut builder := strings.new_builder(0)

	builder.writeln('  ' + term.bold(r.title))

	entry_prefix := '   '
	entries := r.entries.map(format_entry)
	if entries.len == 1 {
		builder.write_string(entry_prefix + entries[0])
	} else if entries.len > 1 {
		// add numbering if entries count is greater than 1
		for i, entry in entries {
			builder.write_string('${entry_prefix}${i + 1}. ${entry}')

			if i < (entries.len - 1) {
				builder.write_string('\n')
			}
		}
	}

	return builder.str()
}

fn format_entry(e KbbiEntry) string {
	mut builder := strings.new_builder(0)

	for kind in e.kind {
		builder.write_string(term.italic(term.red(kind.abbreviation)) + ' ')
	}

	builder.write_string(e.description)

	if e.examples.len > 0 {
		builder.write_string(':')
		for i, example in e.examples {
			builder.write_string(' ' + term.italic(term.dim(example.value)))

			if example.description != '' {
				builder.write_string(' ' + term.red(term.italic(term.dim(example.description))))
			}

			if i < (e.examples.len - 1) {
				builder.write_string(term.dim(';'))
			}
		}
	}

	return builder.str()
}
