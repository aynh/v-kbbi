module kbbi

import net.html
import os

pub struct Entry {
pub:
	title            string
	word             string
	nonstandard_word string
	original_word    string
	entries          []EntryItem
}

pub struct EntryItem {
pub:
	description string
	examples    []EntryExampleItem
	kinds       []EntryKindItem
}

pub struct EntryExampleItem {
pub:
	value       string
	description string
}

pub struct EntryKindItem {
pub:
	abbreviation string
	description  string
}

// entry returns representations of KBBI search with key `word`
pub fn entry(word string) ![]Entry {
	return Client{}.entry(word)!
}

// entry returns representations of KBBI search with key `word`
pub fn (c Client) entry(word string) ![]Entry {
	mut url := *&entry_url
	url.set_path(os.join_path(url.escaped_path(), word))!

	response := c.fetch(method: .get, url: url.str())!.body

	if response.contains('Pencarian Anda telah mencapai batas maksimum dalam sehari') {
		return error('daily search limit reached')
	} else if response.contains('Entri tidak ditemukan.') {
		return error('word `${word}` not found')
	}

	document := html.parse(response)
	document_tags := document.get_tags()

	container_tags := document_tags.filter(it.name == 'ol'
		|| (it.name == 'ul' && it.attributes['class'] == 'adjusted-par'))
	return document_tags.filter(it.name == 'h2').map(parse_result(it, container_tags) or {
		// re-return the error, but replace
		// the {} placeholder with actual word
		return error(err.msg().replace_once('{}', word))
	})
}

fn parse_result(heading_tag &html.Tag, container_tags []&html.Tag) !Entry {
	container_tag := container_tags.filter(it.position_in_parent > heading_tag.position_in_parent)[0]

	title := parse_title(heading_tag)
	word := title.replace('.', '')
	nonstandard_word := parse_nonstandard_word(heading_tag) or { '' }
	original_word := parse_original_word(heading_tag) or { '' }
	entries := parse_entries(container_tag)!

	return Entry{title, word, nonstandard_word, original_word, entries}
}

fn parse_title(heading_tag &html.Tag) string {
	heading_texts := heading_tag.get_tags('text')
	title := if heading_texts.len > 0 {
		heading_texts.last()
	} else {
		heading_tag
	}.content.trim_space()

	return if superscript_tag := heading_tag.get_tags('sup')[0] {
		'${title} (${superscript_tag.content})'
	} else {
		title
	}
}

fn parse_nonstandard_word(heading_tag &html.Tag) ?string {
	return if tag := heading_tag.get_tags('b')[0] {
		tag.content.trim_space()
	} else {
		none
	}
}

fn parse_original_word(heading_tag &html.Tag) ?string {
	return if tag := heading_tag.get_tags_by_attribute_value('class', 'rootword')[0] {
		tag.get_tags('a')[0].content.trim_space()
	} else {
		none
	}
}

fn parse_entries(container_tag &html.Tag) ![]EntryItem {
	return container_tag.get_tags('li').map(parse_entry(it)!).filter(it.description != 'Usulkan makna baru')
}

fn parse_entry(li_tag &html.Tag) !EntryItem {
	description := li_tag.get_tags('text')[0].content.trim_space().trim_right(':')
	if description == '&rarr;' { // &rarr; is →
		suggestion := li_tag.get_tags('a')[0].content.trim_space()
		// we will replace {} placeholder with actual word
		// when the caller (fn entry) propagates this error
		return error('word `{}` not found, did you mean ${suggestion}?')
	}

	return EntryItem{
		description: description
		examples: parse_entry_examples(li_tag)
		kinds: parse_entry_kinds(li_tag)
	}
}

fn parse_entry_kinds(li_tag &html.Tag) []EntryKindItem {
	return li_tag.get_tags('span').map(EntryKindItem{
		abbreviation: it.content.trim_space()
		description: it.attributes['title']
	}).filter(it.abbreviation != '')
}

fn parse_entry_examples(li_tag &html.Tag) []EntryExampleItem {
	contents := li_tag.get_tags('i').map(it.content.trim_space()).filter(it != '')

	if contents.len == 0 {
		return []
	}

	// we use 2-dimensional array here because
	// an example may also have description, so
	// inner_array[0] is the actual example and
	// inner_array[1] is the description (might be none)
	mut example_entries := [][]string{len: 1, init: []string{cap: 2}}
	for content in contents {
		// examples and their descriptions are divided by a single ';'
		if content == ';' {
			// append another empty inner_array into the outer_array
			example_entries << []string{cap: 2}
		} else {
			// append the content to the last inner_array
			example_entries.last() << content
		}
	}

	return example_entries.map(EntryExampleItem{it[0], it[1] or { '' }})
}
