module main

import cli
import client
import format { format_result }
import os
import term
import v.vmod

fn create_client() ?client.KbbiClient {
	return client.new_client_from_login(
		username: os.getenv_opt('KBBI_USERNAME')?
		password: os.getenv_opt('KBBI_PASSWORD')?
	)!
}

fn main() {
	vm := vmod.decode(@VMOD_FILE) or { panic(err) }
	mut app := cli.Command{
		name: vm.name
		usage: '<word>...'
		description: vm.description
		version: vm.version
		required_args: 1
		execute: fn (cmd cli.Command) ! {
			c := create_client() or { client.new_client()! }

			mut results := []string{cap: cmd.args.len}
			for word in cmd.args {
				w_results := c.entry(word) or {
					println('failed to search `${word}`: ${err}')
					exit(1)
				}

				results << w_results.map(format_result).join('\n')
			}

			mut out := results.join('\n')
			if !term.can_show_color_on_stdout() {
				out = term.strip_ansi(out)
			}

			print(out)
		}
	}

	app.setup()
	app.parse(os.args)
}
