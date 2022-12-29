module spinner

import cli
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
	ch chan SpinnerState
	// the thread this Spinner's spawned
	handle thread
}

enum SpinnerState {
	paused
	started
	stopped
}

// new_spinner creates a new Spinner.
// the the spinner is paused by default, so you need to call Spinner.start() first.
pub fn new_spinner() Spinner {
	ch := chan SpinnerState{cap: 1}

	return Spinner{
		ch: ch
		handle: spawn fn (ch chan SpinnerState) {
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
		}(ch)
	}
}

// pause pauses the spinner
pub fn (s Spinner) pause() {
	if !s.ch.closed {
		s.ch <- SpinnerState.paused
		// wait until the spinner actually stops
		time.sleep(spinner.interval)
	}
}

// start starts the spinner
pub fn (s Spinner) start() {
	if !s.ch.closed {
		s.ch <- SpinnerState.started
	}
}

// stop stops the spinner
//
// the spinner is unusable after calling this
pub fn (s Spinner) stop() {
	if !s.ch.closed {
		s.ch <- SpinnerState.stopped
		s.handle.wait()
		s.ch.close()
	}
}

// wrap_command_callback wraps the command's callback
// adds spinner as parameter; stops the spinner before printing any errors
pub fn (s Spinner) wrap_command_callback(cb fn (Spinner, cli.Command) !string) cli.FnCommandCallback {
	return fn [cb, s] (cmd cli.Command) ! {
		output := cb(s, cmd) or {
			s.stop()
			return err
		}

		s.stop()
		println(output)
	}
}
