module main

import os

fn main() {
	results := search_word(os.args[1]) or {
		println(err)
		exit(1)
	}
	println(results)
}
