module main

import cli
import client
import format { format_result }
import json
import os
import spinner
import term
import v.vmod

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
				name: 'no-color'
				description: 'Disables output color.'
			},
			cli.Flag{
				flag: cli.FlagType.bool
				name: 'no-cache'
				description: 'Ignores cached response.'
			},
			cli.Flag{
				flag: cli.FlagType.bool
				name: 'no-login'
				description: 'Ignores saved login.'
			},
			cli.Flag{
				flag: cli.FlagType.bool
				name: 'json'
				description: 'Outputs in JSON format.'
			},
		]
		required_args: 1
		execute: fn (cmd cli.Command) ! {
			shared spinner_state := spinner.State{}
			spinner_handle := spawn spinner.create(shared spinner_state)

			no_cache := cmd.flags.get_bool('no-cache')!
			no_login := cmd.flags.get_bool('no-login')!
			c := if no_login {
				client.new_client(use_cache: !no_cache)!
			} else {
				client.new_client_from_cache(use_cache: !no_cache)!
			}

			mut results := []client.KbbiResult{}
			for word in cmd.args {
				w_results := c.entry(word) or {
					println('failed to search `${word}`: ${err}')
					exit(1)
				}

				results << w_results
			}

			out := if cmd.flags.get_bool('json')! {
				json.encode(results)
			} else {
				mut tmp := results.map(format_result).join('\n\n')
				if !cmd.flags.get_bool('no-color')! && term.can_show_color_on_stdout() {
					tmp
				} else {
					term.strip_ansi(tmp)
				}
			}

			lock spinner_state {
				spinner_state.done = true
				spinner_handle.wait()
			}

			println(out)
		}
		commands: [
			cli.Command{
				name: 'login'
				description: 'Logins to kbbi.kemdikbud.go.id account.'
				usage: '<?username> <?password>'
				flags: [
					cli.Flag{
						flag: cli.FlagType.bool
						name: 'from-env'
						abbrev: 'E'
						description: 'Logins from \$VKBBI_USERNAME and \$VKBBI_PASSWORD environment variable.'
					},
					cli.Flag{
						flag: cli.FlagType.string
						name: 'username'
						abbrev: 'u'
						description: 'Logins with this username.'
					},
					cli.Flag{
						flag: cli.FlagType.string
						name: 'password'
						abbrev: 'p'
						description: 'Logins with this password.'
					},
				]
				execute: fn (cmd cli.Command) ! {
					username := cmd.flags.get_string('username')!
					password := cmd.flags.get_string('password')!
					from_env := cmd.flags.get_bool('from-env')!

					// sanity checks
					if from_env && (username != '' || password != '') {
						eprintln("--from-env flag can't be used with --username or --password")
						exit(1)
					} else if from_env && cmd.args.len == 2 {
						eprintln("--from-env flag can't be used with login arguments")
						exit(1)
					} else if (username != '' || password != '') && cmd.args.len == 2 {
						eprintln("login arguments can't be used with --username or --password")
						exit(1)
					}

					user, pass := if username != '' && password != '' {
						username, password
					} else if from_env {
						os.getenv_opt('VKBBI_USERNAME') or {
							return error('\$VKBBI_USERNAME is not set')
						}, os.getenv_opt('VKBBI_PASSWORD') or {
							return error('\$VKBBI_PASSWORD is not set')
						}
					} else if cmd.args.len == 2 {
						cmd.args[0], cmd.args[1]
					} else {
						user := os.input('username: ')
						pass := os.input_password('password: ')!
						user, pass
					}

					shared spinner_state := spinner.State{}
					spinner_handle := spawn spinner.create(shared spinner_state)

					c := client.new_client_from_login(username: user, password: pass)!
					c.save_to_cache()!

					lock spinner_state {
						spinner_state.done = true
						spinner_handle.wait()
					}

					println('Successfully logged in')
				}
			},
		]
	}

	app.setup()
	app.parse(os.args)
}
