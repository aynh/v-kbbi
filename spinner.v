module spinner

import term
import time

pub struct State {
pub mut:
	done bool
}

pub fn create(shared state State) {
	// table flip spinner
	chars := "___-``'´-___".runes()
	interval := 70000000 // 70ms in ns

	term.hide_cursor()
	defer {
		term.show_cursor()
	}

	mut i := 0
	for !state.done {
		println(' ' + chars[i % chars.len].str() + ' loading')
		time.sleep(interval)
		term.clear_previous_line()
		i += 1
	}
}
