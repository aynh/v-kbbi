module wrap_word

fn test_wrap_word() {
	text := 'Lorem ipsum dolor sit amet consectetur adipiscing elit nascetur fusce at commodo, himenaeos nam rutrum nec torquent malesuada iaculis imperdiet diam ullamcorper, tellus suscipit euismod risus habitant aliquet ad faucibus sagittis dictumst. Cursus hendrerit purus cras fermentum non viverra semper, pulvinar tempor ridiculus aliquam posuere auctor cubilia vel, mauris sapien massa aenean mattis id. Vitae varius libero habitasse leo scelerisque porta dui ornare accumsan, condimentum magna sociosqu feugiat ultrices parturient mi pretium, erat sem urna lectus quam per sociis eros. Ligula eget laoreet tristique donec nisi pellentesque maecenas, eleifend arcu tincidunt praesent rhoncus quis, dignissim nullam molestie senectus inceptos nunc.'

	w1 := wrap_word(s: text, max_width: 50)
	assert w1.split('\n').all(it.len <= 50)

	prefix := '   '
	w2 := wrap_word(s: text, prefix: prefix)
	assert w2.split('\n').all(it.starts_with(prefix))

	indent := 4
	w3 := wrap_word(s: text, indent: indent)
	for i, w in w3.split('\n') {
		if i == 0 {
			continue
		}

		assert w.starts_with(` `.repeat(indent))
	}

	w4 := wrap_word(s: text, prefix: prefix, indent: indent, max_width: 20)
	for i, w in w4.split('\n') {
		assert w.len <= 20
		if i == 0 {
			assert w.starts_with(prefix)
		} else {
			assert w.starts_with(prefix + ` `.repeat(indent))
		}
	}
}
