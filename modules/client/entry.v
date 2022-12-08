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
	kinds       []KbbiEntryKind
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

[params]
pub struct EntryConfig {
	word        string [required]
	cached_only bool
}

// entry returns representations of KBBI search with key `word`
pub fn entry(c EntryConfig) ![]KbbiResult {
	return new_client(no_cache: true)!.entry(c)!
}

// entry returns representations of KBBI search with key `word`
pub fn (c KbbiClient) entry(e EntryConfig) ![]KbbiResult {
	response := c.fetch_entry(e)!

	document := html.parse(response)
	document_tags := document.get_tags()

	container_tags := document_tags.filter(it.name == 'ol'
		|| (it.name == 'ul' && it.attributes['class'] == 'adjusted-par'))
	return document_tags.filter(it.name == 'h2').map(parse_result(it, container_tags) or {
		// re-return the error, but replace
		// the {} placeholder with actual word
		return error(err.msg().replace_once('{}', e.word))
	})
}

fn (c KbbiClient) fetch_entry(e EntryConfig) !string {
	cached_only := e.cached_only
	cookie := c.application_cookie
	return c.cache_get_or_init(e.word, fn [cached_only, cookie] (word string) !string {
		if cached_only {
			return error('word `${word}` not cached')
		}

		response := http.fetch(
			method: .get
			url: 'https://kbbi.kemdikbud.go.id/entri/${word.to_lower()}'
			cookies: {
				application_cookie: cookie
			}
		)!.body

		if response.contains('Pencarian Anda telah mencapai batas maksimum dalam sehari') {
			return error('daily search limit reached')
		} else if response.contains('Entri tidak ditemukan.') {
			return error('word `${word}` not found')
		}

		return response
	})!
}

fn parse_result(heading_tag &html.Tag, container_tags []&html.Tag) !KbbiResult {
	container_tag := container_tags.filter(it.position_in_parent > heading_tag.position_in_parent)[0]

	title := parse_title(heading_tag)
	word := title.replace('.', '')
	nonstandard_word := parse_nonstandard_word(heading_tag) or { '' }
	original_word := parse_original_word(heading_tag) or { '' }
	entries := parse_entries(container_tag)!

	return KbbiResult{title, word, nonstandard_word, original_word, entries}
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

fn parse_entries(container_tag &html.Tag) ![]KbbiEntry {
	return container_tag.get_tags('li').map(parse_entry(it)!).filter(it.description != 'Usulkan makna baru')
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
		kinds: parse_entry_kinds(li_tag)
	}
}

fn parse_entry_kinds(li_tag &html.Tag) []KbbiEntryKind {
	return li_tag.get_tags('span').map(KbbiEntryKind{
		abbreviation: it.content.trim_space()
		description: it.attributes['title']
	}).filter(it.abbreviation != '')
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
