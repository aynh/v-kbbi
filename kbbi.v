module main

import os
import client { KbbiClient, new_client_from_login }
import format { format_result }

fn create_client() ?KbbiClient {
	return new_client_from_login(
		username: os.getenv_opt('KBBI_USERNAME')?
		password: os.getenv_opt('KBBI_PASSWORD')?
	)!
}

fn main() {
	c := create_client() or { KbbiClient{''} }

	if results := c.entry(os.args[1]) {
		for i, result in results {
			print(format_result(result))
			if i < (results.len - 1) {
				print('\n\n')
			} else {
				print('\n')
			}
		}
	} else {
		println(err)
		exit(1)
	}
}
