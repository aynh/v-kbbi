module client

import net.http
import net.html
import sqlite
import time

const (
	login_url          = 'https://kbbi.kemdikbud.go.id/Account/Login'
	application_cookie = '.AspNet.ApplicationCookie'
	verification_token = '__RequestVerificationToken'
)

[noinit]
pub struct KbbiClient {
	application_cookie string
	cache_db           sqlite.DB
}

// check_session returns true if session is valid (logged in)
pub fn (c KbbiClient) check_session() !bool {
	response := http.fetch(
		method: .get
		url: client.login_url
		cookies: {
			client.application_cookie: c.application_cookie
		}
	)!.body

	document := html.parse(response)
	forms := document.get_tag('form')
	return forms.any(it.attributes['id'] == 'logoutForm'
		&& it.attributes['action'] == '/Account/LogOff')
}

// save_session saves this `KbbiClient` session (`application_cookie`) into it's `cache_db`
//
// afterwards, `KbbiClient` created with `new_client_from_cache` will use this session
pub fn (c KbbiClient) save_session() ! {
	if !c.cache_db.is_open {
		return error('unable to save login cache')
	}

	sql c.cache_db {
		delete from CacheEntry where key == login_cache_key
	}

	cache := CacheEntry{
		key: login_cache_key
		value: c.application_cookie
		created_at: time.now()
	}

	sql c.cache_db {
		insert cache into CacheEntry
	}
}

[params]
pub struct KbbiClientConfig {
	no_cache bool
}

// new_client creates a default client
pub fn new_client(c KbbiClientConfig) !KbbiClient {
	cache_db := if !c.no_cache {
		new_cache_db()!
	} else {
		sqlite.DB{}
	}

	return KbbiClient{
		cache_db: cache_db
	}
}

// new_client_from_cache creates a client from cache database
//
// you need to save a session beforehand using `save_session`
pub fn new_client_from_cache(c KbbiClientConfig) !KbbiClient {
	cache_db := new_cache_db()!
	cookie := sql cache_db {
		select from CacheEntry where key == login_cache_key limit 1
	}

	return if !c.no_cache {
		KbbiClient{
			cache_db: cache_db
			application_cookie: cookie.value
		}
	} else {
		KbbiClient{
			application_cookie: cookie.value
		}
	}
}

[params]
pub struct KbbiClientLoginConfig {
	base     KbbiClientConfig
	username string           [required]
	password string           [required]
}

// new_client_from_login creates a client by simulating a login using username and password
pub fn new_client_from_login(c KbbiClientLoginConfig) !KbbiClient {
	if c.username == '' || c.password == '' {
		return error("login username or password can't be empty")
	}

	init_response := http.get(client.login_url)!
	login_document := html.parse(init_response.body)
	verification_tag := login_document.get_tag('input').filter(it.attributes['name'] == client.verification_token)[0]!

	token_cookie := init_response.cookies()[0]!
	token_form := verification_tag.attributes['value']

	form := {
		client.verification_token: token_form
		'Posel':                   c.username
		'KataSandi':               c.password
		'IngatSaya':               'true'
	}

	response := http.fetch(
		method: .post
		url: client.login_url
		cookies: {
			client.verification_token: token_cookie.value
		}
		header: http.new_header(key: .content_type, value: 'application/x-www-form-urlencoded')
		data: http.url_encode_form_data(form)
		allow_redirect: false
	)!

	for cookie in response.cookies() {
		if cookie.name == client.application_cookie {
			client := new_client(c.base)!

			return KbbiClient{
				...client
				application_cookie: cookie.value
			}
		}
	}

	return error('unable to find `${client.application_cookie}` cookie, login may be invalid')
}
