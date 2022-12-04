module main

import cli
import client
import format { format_result }
import os
import term
import v.vmod

fn create_client(c client.KbbiClientConfig) ?client.KbbiClient {
	return client.new_client_from_login(
		base: c
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
		posix_mode: true
		flags: [
			cli.Flag{
				flag: cli.FlagType.bool
				name: 'color'
				description: 'Colors the output.'
				global: true
				default_value: ['true']
			},
			cli.Flag{
				flag: cli.FlagType.bool
				name: 'no-cache'
				description: 'Ignores cached response.'
				global: true
			},
		]
		required_args: 1
		execute: fn (cmd cli.Command) ! {
			no_cache := cmd.flags.get_bool('no-cache')!
			c := create_client(use_cache: !no_cache) or { client.new_client(use_cache: !no_cache)! }

			mut results := []string{cap: cmd.args.len}
			for word in cmd.args {
				w_results := c.entry(word) or {
					println('failed to search `${word}`: ${err}')
					exit(1)
				}

				results << w_results.map(format_result).join('\n')
			}

			mut out := results.join('\n')
			if !(cmd.flags.get_bool('color')! && term.can_show_color_on_stdout()) {
				out = term.strip_ansi(out)
			}

			print(out)
		}
	}

	app.setup()
	app.parse(os.args)
}
