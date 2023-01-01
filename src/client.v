module kbbi

import net.html
import net.http

pub struct Client {
pub mut:
	cookie string
}

fn (c Client) fetch(config http.FetchConfig) !http.Response {
	return http.fetch(http.FetchConfig{
		...config
		cookies: {
			cookie_key: c.cookie
		}
	})!
}

// is_logged_in returns true if cookies is valid (implies logged in)
pub fn (c Client) is_logged_in() !bool {
	response := c.fetch(method: .get, url: login_url.str())!.body

	document := html.parse(response)
	forms := document.get_tag('form')
	return forms.any(it.attributes['id'] == 'logoutForm'
		&& it.attributes['action'] == '/Account/LogOff')
}

[params]
pub struct ClientFromLoginConfig {
	username string [required]
	password string [required]
}

// new_client_from_login creates a client by simulating a login using username and password
pub fn new_client_from_login(c ClientFromLoginConfig) !Client {
	if c.username == '' || c.password == '' {
		return error("new_client_from_login: login username or password can't be empty")
	}

	init_response := http.get(login_url.str())!
	login_dom := html.parse(init_response.body)
	verification_tag := login_dom.get_tag('input').filter(it.attributes['name'] == verification_token)[0]!

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
		url: login_url.str()
		cookies: {
			verification_token: token_cookie.value
		}
		header: http.new_header(key: .content_type, value: 'application/x-www-form-urlencoded')
		data: http.url_encode_form_data(form)
		allow_redirect: false
	)!

	for cookie in response.cookies() {
		if cookie.name == cookie_key {
			return Client{
				cookie: cookie.value
			}
		}
	}

	return error('new_client_from_login: unable to find login cookie, login may be invalid')
}
