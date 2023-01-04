module spinner

import cli
import term
import time

const (
	// table flip spinner
	chars    = "___-``'´-___".runes()
	// spinner's interval
	interval = 70 * time.millisecond
)

[noinit]
pub struct Spinner {
	// the channel used to communicate with this Spinner's thread
	ch chan SpinnerMessage
	// the thread this Spinner's spawned
	handle thread
}

enum SpinnerState {
	paused
	started
	stopped
}

type SpinnerMessage = SpinnerState | string

// new_spinner creates a new Spinner.
// the the spinner is paused by default, so you need to call Spinner.start() first.
pub fn new_spinner() Spinner {
	ch := chan SpinnerMessage{cap: 1}

	return Spinner{
		ch: ch
		handle: spawn fn (ch chan SpinnerMessage) {
			mut state := SpinnerState.paused
			mut message := 'loading'
			for i := 0; state != .stopped; {
				select {
					received := <-ch {
						match received {
							SpinnerState { state = received }
							string { message = received }
						}
					}
					else {
						if state == .paused {
							continue
						}

						c := spinner.chars[i % spinner.chars.len].str()
						eprintln(' ${c} ${message}')
						time.sleep(spinner.interval)

						// term.clear_previous_line()
						eprint('\r\x1b[1A\x1b[2K')
						flush_stderr()

						i += 1
					}
				}
			}
		}(ch)
	}
}

// pause pauses the spinner
pub fn (s Spinner) pause() {
	if s.set_state(.paused) {
		// wait until the spinner actually stops
		time.sleep(spinner.interval)
	}
}

// start starts the spinner
pub fn (s Spinner) start() {
	s.set_state(.started)
}

// stop stops the spinner
//
// the spinner is unusable after calling this
pub fn (s Spinner) stop() {
	if s.set_state(.stopped) {
		s.handle.wait()
		s.ch.close()
	}
}

// set_message sets the message of the Spinner
pub fn (s Spinner) set_message(ss string) bool {
	return s.send(SpinnerMessage(ss))
}

fn (s Spinner) set_state(state SpinnerState) bool {
	return s.send(SpinnerMessage(state))
}

fn (s Spinner) send(v SpinnerMessage) bool {
	if s.ch.closed {
		return false
	}

	s.ch <- v
	return true
}

// wrap_command_callback wraps the command's callback
// adds spinner as parameter; stops the spinner before printing any errors
pub fn (s Spinner) wrap_command_callback(cb fn (Spinner, cli.Command) !string) cli.FnCommandCallback {
	return fn [cb, s] (cmd cli.Command) ! {
		output := cb(s, cmd) or {
			error := term.ecolorize(term.bright_red, 'ERROR:')
			'${error} ${err.msg()}'
		}

		s.stop()
		println(output)
	}
}
