module main

import net.http
import net.html

const (
	login_url          = 'https://kbbi.kemdikbud.go.id/Account/Login'
	application_cookie = '.AspNet.ApplicationCookie'
	verification_token = '__RequestVerificationToken'
)

[noinit]
pub struct KbbiClient {
	application_cookie string
}

[params]
pub struct KbbiClientLoginConfig {
	username string
	password string
}

pub fn new_client_from_login(c KbbiClientLoginConfig) !KbbiClient {
	init_response := http.get(login_url)!
	login_document := html.parse(init_response.body)
	verification_tag := login_document.get_tag('input').filter(it.attributes['name'] == verification_token)[0]!

	token_cookie := init_response.cookies()[0]!
	token_form := verification_tag.attributes['value']

	form := {
		verification_token: token_form
		'Posel':            c.username
		'KataSandi':        c.password
		'IngatSaya':        'true'
	}

	response := http.fetch(
		method: .post
		url: login_url
		cookies: {
			verification_token: token_cookie.value
		}
		header: http.new_header(key: .content_type, value: 'application/x-www-form-urlencoded')
		data: http.url_encode_form_data(form)
		allow_redirect: false
	)!

	for cookie in response.cookies() {
		if cookie.name == application_cookie {
			return KbbiClient{cookie.value}
		}
	}

	return error('unable to find `${application_cookie}` cookie')
}
