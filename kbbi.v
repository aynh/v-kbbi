module main

import scraper
import os

fn main() {
	results := scraper.search_word(os.args[1]) or {
		println(err)
		exit(1)
	}
	println(results)
}
