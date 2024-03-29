module client

import kbbi
import db.sqlite

[heap]
pub struct IClient {
	kbbi.Client
pub:
	cache_db sqlite.DB
}

[params]
pub struct NewClientConfig {
	no_cache bool
	no_login bool
}

pub fn new_kbbi_client(c NewClientConfig) IClient {
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

	return IClient{client, db}
}
