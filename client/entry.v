module client

import net.html
import net.http

pub struct KbbiResult {
pub:
	title            string
	word             string
	nonstandard_word string
	original_word    string
	entries          []KbbiEntry
}

pub struct KbbiEntry {
pub:
	description string
	examples    []KbbiEntryExample
	kind        []KbbiEntryKind
}

pub struct KbbiEntryExample {
pub:
	value       string
	description string
}

pub struct KbbiEntryKind {
pub:
	abbreviation string
	description  string
}

pub fn (c KbbiClient) entry(word string) ![]KbbiResult {
	response := http.fetch(
		method: .get
		url: 'https://kbbi.kemdikbud.go.id/entri/${word.to_lower()}'
		cookies: {
			application_cookie: c.application_cookie
		}
	)!

	document := html.parse(response.body)
	document_tags := document.get_tags()

	for tag in document_tags {
		content := tag.content
		if content.contains('Pencarian Anda telah mencapai batas maksimum dalam sehari') {
			return error("today's search limit reached")
		} else if content.contains('Entri tidak ditemukan.') {
			return error('word `${word}` not found')
		}
	}

	container_tags := document_tags.filter(it.name == 'ol'
		|| (it.name == 'ul' && it.attributes['class'] == 'adjusted-par'))
	map_closure := fn [container_tags] (heading_tag &html.Tag) !KbbiResult {
		container_tag := container_tags.filter(it.position_in_parent > heading_tag.position_in_parent)[0]

		heading_texts := heading_tag.get_tags('text')
		mut title := if heading_texts.len > 0 {
			heading_texts.last()
		} else {
			heading_tag
		}.content.trim_space()
		if superscript_tag := heading_tag.get_tags('sup')[0] {
			title = '${title} (${superscript_tag.content})'
		}

		word := title.replace('.', '')
		nonstandard_word := if tag := heading_tag.get_tags('b')[0] {
			tag.content.trim_space()
		} else {
			''
		}
		original_word := if tag := heading_tag.get_tags_by_attribute_value('class', 'rootword')[0] {
			tag.get_tags('a')[0].content.trim_space()
		} else {
			''
		}

		entries := parse_entries(container_tag)!

		return KbbiResult{title, word, nonstandard_word, original_word, entries}
	}

	return document_tags.filter(it.name == 'h2').map(map_closure(it) or {
		// re-return the error, but replace
		// the {} placeholder with actual word
		return error(err.msg().replace_once('{}', word))
	})
}

pub fn entry(word string) ![]KbbiResult {
	return KbbiClient{''}.entry(word)!
}

fn parse_entries(container_tag &html.Tag) ![]KbbiEntry {
	return container_tag.get_tags('li').map(parse_entry(it)!)
}

fn parse_entry(li_tag &html.Tag) !KbbiEntry {
	description := li_tag.get_tags('text')[0].content.trim_space().trim_right(':')
	if description == '&rarr;' { // &rarr; is →
		suggestion := li_tag.get_tags('a')[0].content.trim_space()
		// we will replace {} placeholder with actual word
		// when the caller (fn entry) propagates this error
		return error('word `{}` not found, did you mean ${suggestion}?')
	}

	return KbbiEntry{
		description: description
		examples: parse_entry_examples(li_tag)
		kind: parse_entry_kinds(li_tag)
	}
}

fn parse_entry_kinds(li_tag &html.Tag) []KbbiEntryKind {
	return li_tag.get_tags('span').map(KbbiEntryKind{
		abbreviation: it.content.trim_space()
		description: it.attributes['title']
	})
}

fn parse_entry_examples(li_tag &html.Tag) []KbbiEntryExample {
	contents := li_tag.get_tags('i').map(it.content.trim_space()).filter(it != '')

	if contents.len == 0 {
		return []
	}

	// we use 2-dimensional array here because
	// an example may also have description, so
	// inner_array[0] is the actual example and
	// inner_array[1] is the description (might be none)
	mut example_entries := [][]string{len: 1, init: []string{}}
	for content in contents {
		// examples and their descriptions are divided by a single ';'
		if content == ';' {
			// append another empty inner_array into the outer_array
			example_entries << []string{}
		} else {
			// append the content to the last inner_array
			example_entries.last() << content
		}
	}

	return example_entries.map(KbbiEntryExample{it[0], it[1] or { '' }})
}
