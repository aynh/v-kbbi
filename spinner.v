module spinner

import time

pub struct State {
pub mut:
	done bool
}

pub fn create(shared state State) {
	// table flip spinner
	chars := "___-``'´-___".runes()
	interval := 70 * time.millisecond

	mut i := 0
	for !state.done {
		eprintln(' ' + chars[i % chars.len].str() + ' loading')
		time.sleep(interval)

		// term.clear_previous_line()
		eprint('\r\x1b[1A\x1b[2K')
		flush_stderr()

		i += 1
	}
}
