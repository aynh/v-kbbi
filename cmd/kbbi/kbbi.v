module main

import cli
import cached_client { new_cached_client }
import kbbi
import format { format_entry }
import json
import os
import spinner { Spinner }
import term
import v.vmod

fn main() {
	spinner := spinner.new_spinner()

	pre_execute := fn [spinner] (cmd cli.Command) ! {
		// stop spinner if --no-spinner or stderr is not a terminal
		if cmd.root().flags.get_bool('no-spinner')! || os.is_atty(2) <= 0 {
			spinner.stop()
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
		pre_execute: pre_execute
		execute: spinner.wrap_command_callback(fn (spinner Spinner, cmd cli.Command) !string {
			spinner.start()

			client := new_cached_client(
				no_cache: cmd.flags.get_bool('no-cache')!
				no_login: cmd.flags.get_bool('no-login')!
			)

			words := cmd.args
			mut results := []kbbi.Entry{cap: words.len * 5}
			for word in words {
				results << client.get_cache_or_init(word, fn (c kbbi.Client, word string) ![]kbbi.Entry {
					return c.entry(word)!
				})!
			}

			return process_entries(results, cmd)!
		})
	}

	app.add_command(cli.Command{
		name: 'cache'
		description: 'Searches cached words.'
		usage: '<?word>...'
		pre_execute: pre_execute
		execute: spinner.wrap_command_callback(fn (spinner Spinner, cmd cli.Command) !string {
			spinner.start()

			client := new_cached_client()

			words := if cmd.args.len > 0 {
				cmd.args
			} else {
				client.get_cache_keys()
			}

			mut results := []kbbi.Entry{cap: words.len * 5}
			for word in words {
				results << client.get_cache[[]kbbi.Entry](word) or {
					return error('word `${word}` not cached')
				}
			}

			return process_entries(results, cmd)!
		})
	})

	app.add_command(cli.Command{
		name: 'login'
		description: 'Logins to kbbi.kemdikbud.go.id account.'
		usage: '<?username> <?password>'
		flags: [
			cli.Flag{
				flag: cli.FlagType.bool
				name: 'check'
				abbrev: 'C'
				description: 'Checks cached login session.'
			},
			cli.Flag{
				flag: cli.FlagType.bool
				name: 'from-env'
				abbrev: 'E'
				description: 'Logins with \$KBBI_USERNAME and \$KBBI_PASSWORD environment variable.'
			},
		]
		pre_execute: pre_execute
		execute: spinner.wrap_command_callback(fn (spinner Spinner, cmd cli.Command) !string {
			if cmd.flags.get_bool('check')! {
				spinner.start()

				client := new_cached_client()
				return if client.inner.is_logged_in()! {
					'You are logged in'
				} else {
					'You are not logged in'
				}
			}

			from_env := cmd.flags.get_bool('from-env')!

			// sanity check
			if from_env && cmd.args.len == 2 {
				return error("--from-env can't be used with login arguments")
			}

			user, pass := match true {
				from_env {
					getenv := fn (k string) !string {
						return os.getenv_opt(k) or { return error('\$${k} is not set') }
					}

					getenv('KBBI_USERNAME')!, getenv('KBBI_PASSWORD')!
				}
				cmd.args.len == 2 {
					cmd.args[0], cmd.args[1]
				}
				else {
					user := os.input('username: ')
					pass := os.input_password('password: ')!
					user, pass
				}
			}

			spinner.start()

			client := new_cached_client()
			inner_client := kbbi.new_client_from_login(username: user, password: pass)!
			client.set_cache(cached_client.login_key, inner_client.cookie)

			return 'Successfully logged in'
		})
	})

	app.setup()
	app.parse(os.args)
}

fn process_entries(results []kbbi.Entry, cmd &cli.Command) !string {
	root_cmd := cmd.root()

	return if root_cmd.flags.get_bool('json')! {
		json.encode(results)
	} else {
		mut output := results.map(format_entry).join('\n\n')
		if root_cmd.flags.get_bool('no-color')! || !term.can_show_color_on_stdout() {
			term.strip_ansi(output)
		} else {
			output
		}
	}
}
