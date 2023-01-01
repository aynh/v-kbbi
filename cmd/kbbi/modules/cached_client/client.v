module cached_client

import kbbi
import sqlite

[heap]
pub struct CachedClient {
pub:
	inner   kbbi.Client
	cache_db sqlite.DB
}

[params]
pub struct NewClientConfig {
	no_cache bool
	no_login bool
}

pub fn new_cached_client(c NewClientConfig) CachedClient {
	db := if c.no_cache {
		sqlite.DB{}
	} else {
		new_cache_db() or { panic(err) }
	}

	client := if c.no_login {
		kbbi.Client{}
	} else {
		cookie := get_cache_str(db, login_key) or { '' }
		kbbi.Client{
			cookie: cookie
		}
	}

	return CachedClient{client, db}
}
