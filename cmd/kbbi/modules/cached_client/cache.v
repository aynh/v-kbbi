module cached_client

import json
import kbbi
import os
import db.sqlite
import time
import v.vmod

pub const login_key = '__login'

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

pub fn (c CachedClient) get_cache_keys() []string {
	caches := sql c.cache_db {
		select from EntryCache
	}

	return caches.map(it.key).filter(it != cached_client.login_key)
}

fn get_cache_str(db sqlite.DB, key string) ?string {
	cache := sql db {
		select from EntryCache where key == key limit 1
	} or { return none }

	return cache.value
}

pub fn (c CachedClient) get_cache[T](key string) ?T {
	return json.decode(T, get_cache_str(c.cache_db, key) or { '' }) or { none }
}

pub fn (c CachedClient) get_cache_or_init[T](key string, init fn (kbbi.Client, string) !T) !T {
	return c.get_cache[T](key) or {
		value := init(c.inner, key)!
		c.set_cache(key, value)

		value
	}
}

pub fn (c CachedClient) set_cache[T](key string, value T) {
	cache := new_entry_cache(key, value)
	sql c.cache_db {
		insert cache into EntryCache
	}
}
