module main

import arrays
import cli
import client
import json
import os
import spinner
import term
import v.vmod

fn main() {
	spin := spinner.new()

	pre_exec := fn [spin] (cmd cli.Command) ! {
		// stop spinner if --no-spinner or stderr is not a terminal
		if cmd.root().flags.get_bool('no-spinner')! || os.is_atty(2) <= 0 {
			spin.stop()
		}
	}

	// wraps the command's callback; stops the spinner before printing errors
	wrap_cb := fn [spin] (cb cli.FnCommandCallback) cli.FnCommandCallback {
		return fn [cb, spin] (cmd cli.Command) ! {
			cb(cmd) or {
				spin.stop()
				return err
			}
		}
	}

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
				name: 'no-spinner'
				description: 'Disables spinner.'
			},
			cli.Flag{
				flag: cli.FlagType.bool
				name: 'json'
				description: 'Outputs in JSON format.'
			},
		]
		required_args: 1
		pre_execute: pre_exec
		execute: wrap_cb(fn [spin] (cmd cli.Command) ! {
			spin.start()

			no_cache := cmd.flags.get_bool('no-cache')!
			c := if cmd.flags.get_bool('no-login')! {
				client.new_client(no_cache: no_cache)!
			} else {
				client.new_client_from_cache(no_cache: no_cache)!
			}

			results := arrays.flatten(cmd.args.map(c.entry(word: it)!))
			output := process_results(results, cmd)!

			spin.stop()

			println(output)
		})
		commands: [
			cli.Command{
				name: 'cache'
				description: 'Searches cached words.'
				usage: '<?word>...'
				pre_execute: pre_exec
				execute: wrap_cb(fn [spin] (cmd cli.Command) ! {
					spin.start()

					c := client.new_client()!

					words := if cmd.args.len > 0 {
						cmd.args
					} else {
						c.cache_get_all_keys()
					}

					results := arrays.flatten(words.map(c.entry(word: it, cached_only: true)!))
					output := process_results(results, cmd.root())!

					spin.stop()

					println(output)
				})
			},
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
				pre_execute: pre_exec
				execute: wrap_cb(fn [spin] (cmd cli.Command) ! {
					username := cmd.flags.get_string('username')!
					password := cmd.flags.get_string('password')!
					from_env := cmd.flags.get_bool('from-env')!

					// sanity checks
					if from_env && (username != '' || password != '') {
						return error("--from-env can't be used with --username or --password")
					} else if from_env && cmd.args.len == 2 {
						return error("--from-env can't be used with login arguments")
					} else if (username != '' || password != '') && cmd.args.len == 2 {
						return error("login arguments can't be used with --username or --password")
					} else if (username != '') != (password != '') {
						return error('both --username and --password are needed')
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

					spin.start()

					c := client.new_client_from_login(username: user, password: pass)!
					c.save_session()!

					spin.stop()

					println('Successfully logged in')
				})
			},
		]
	}

	app.setup()
	app.parse(os.args)
}

fn process_results(results []client.KbbiResult, root_cmd &cli.Command) !string {
	return if root_cmd.flags.get_bool('json')! {
		json.encode(results)
	} else {
		mut output := results.map(format_result).join('\n\n')
		if !root_cmd.flags.get_bool('no-color')! && term.can_show_color_on_stdout() {
			output
		} else {
			term.strip_ansi(output)
		}
	}
}
