module client

import client.cache
import net.http
import net.html
import sqlite

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

[params]
pub struct KbbiClientConfig {
	use_cache bool = true
}

pub fn new_client(c KbbiClientConfig) !KbbiClient {
	cache_db := if c.use_cache {
		cache.cache_db()!
	} else {
		sqlite.DB{}
	}

	return KbbiClient{'', cache_db}
}

[params]
pub struct KbbiClientLoginConfig {
	base     KbbiClientConfig
	username string
	password string
}

pub fn new_client_from_login(c KbbiClientLoginConfig) !KbbiClient {
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

	return error('unable to find `${client.application_cookie}` cookie')
}
