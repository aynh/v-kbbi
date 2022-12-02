module main

import os
import client { KbbiClient, new_client_from_login }

fn create_client() ?KbbiClient {
	return new_client_from_login(
		username: os.getenv_opt('KBBI_USERNAME')?
		password: os.getenv_opt('KBBI_PASSWORD')?
	)!
}

fn main() {
	c := create_client() or { KbbiClient{''} }
	results := c.entry(os.args[1]) or {
		println(err)
		exit(1)
	}
	println(results)
}
