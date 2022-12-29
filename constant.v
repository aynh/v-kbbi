module kbbi

import net.urllib

pub const (
	entry_url = urllib.parse('https://kbbi.kemdikbud.go.id/entri') or { panic(err) }
	login_url = urllib.parse('https://kbbi.kemdikbud.go.id/Account/Login') or { panic(err) }
)

const (
	cookie_key = '.AspNet.ApplicationCookie'
	verification_token = '__RequestVerificationToken'
)
