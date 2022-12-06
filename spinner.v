module spinner

import time

const (
	// table flip spinner
	chars    = "___-``'´-___".runes()
	interval = 70 * time.millisecond
)

[noinit]
pub struct Spinner {
	ch     chan SpinnerState
	handle thread
}

enum SpinnerState {
	paused
	started
	stopped
}

pub fn new() Spinner {
	ch := chan SpinnerState{cap: 1}
	return Spinner{
		ch: ch
		handle: spawn run(ch)
	}
}

pub fn (s Spinner) pause() {
	s.ch <- SpinnerState.paused
	// wait until the spinner actually stops
	time.sleep(spinner.interval)
}

pub fn (s Spinner) start() {
	s.ch <- SpinnerState.started
}

pub fn (s Spinner) stop() {
	s.ch <- SpinnerState.stopped
	s.handle.wait()
}

fn run(ch chan SpinnerState) {
	mut state := SpinnerState.paused
	for i := 0; state != .stopped; {
		select {
			msg := <-ch {
				state = msg
			}
			else {
				if state == .paused {
					continue
				}

				c := spinner.chars[i % spinner.chars.len].str()
				eprintln(' ${c} loading')
				time.sleep(spinner.interval)

				// term.clear_previous_line()
				eprint('\r\x1b[1A\x1b[2K')
				flush_stderr()

				i += 1
			}
		}
	}
}
