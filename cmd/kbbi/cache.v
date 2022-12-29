module main

import json
import os
import sqlite
import time
import v.vmod

const login_cache_key = '__login'

[table: 'cache']
struct EntryCache {
	id         int       [primary; sql: serial]
	key        string    [nonull; unique]
	value      string    [nonull]
	created_at time.Time [nonull; sql_type: 'DATETIME']
}

fn new_entry_cache[T](key string, value T) EntryCache {
	return EntryCache{
		key: key
		value: json.encode(value)
		created_at: time.now()
	}
}

fn new_cache_db() !sqlite.DB {
	vm := vmod.decode(@VMOD_FILE) or { panic(err) }
	db_dir := os.join_path(os.cache_dir(), vm.name)
	os.mkdir_all(db_dir)!

	path := os.join_path(db_dir, 'db.sqlite')
	db := sqlite.connect(path)!

	sql db {
		create table EntryCache
	}

	return db
}

fn get_cache_keys(db sqlite.DB) []string {
	caches := sql db {
		select from EntryCache
	}

	return caches.map(it.key).filter(it != login_cache_key)
}

fn get_cache_str(db sqlite.DB, key string) ?string {
	cache := sql db {
		select from EntryCache where key == key limit 1
	} or { return none }

	return cache.value
}

fn get_cache[T](db sqlite.DB, key string) ?T {
	return json.decode(T, get_cache_str(db, key) or { '' }) or { none }
}

fn get_cache_or_init[T](db sqlite.DB, key string, init fn (string) !T) !T {
	return get_cache[T](db, key) or {
		value := init(key)!
		set_cache(db, key, value)

		value
	}
}

fn set_cache[T](db sqlite.DB, key string, value T) {
	cache := new_entry_cache(key, value)
	sql db {
		insert cache into EntryCache
	}
}
