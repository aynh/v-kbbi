module main

import kbbi
import sqlite

[params]
struct NewClientConfig {
	no_cache bool
	no_login bool
}

fn new_client(c NewClientConfig) (kbbi.Client, sqlite.DB) {
	db := if c.no_cache {
		sqlite.DB{}
	} else {
		new_cache_db() or { panic(err) }
	}

	client := if c.no_login {
		kbbi.Client{}
	} else {
		cookie := get_cache_str(db, login_cache_key) or { '' }
		kbbi.Client{
			cookie: cookie
		}
	}

	return client, db
}
