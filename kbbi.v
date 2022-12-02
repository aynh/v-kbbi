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
		print(results.map(format_result).join('\n'))
	} else {
		println(err)
		exit(1)
	}
}
