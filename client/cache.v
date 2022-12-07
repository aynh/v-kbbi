module client

import os
import sqlite
import time
import v.vmod

const login_cache_key = '__login'

[table: 'response_cache']
struct CacheEntry {
	id         int       [primary; sql: serial]
	key        string    [nonull; unique]
	value      string    [nonull]
	created_at time.Time [nonull; sql_type: 'DATETIME']
}

fn new_cache_db() !sqlite.DB {
	vm := vmod.decode(@VMOD_FILE) or { panic(err) }
	dir := os.join_path(os.cache_dir(), 'v' + vm.name)
	os.mkdir_all(dir)!

	path := os.norm_path(os.join_path(dir, vm.version + '.db'))
	db := sqlite.connect(path)!

	sql db {
		create table CacheEntry
	}

	return db
}

pub fn (c KbbiClient) cache_get_all_keys() []string {
	caches := sql c.cache_db {
		select from CacheEntry where key != client.login_cache_key
	}

	return caches.map(it.key)
}

pub fn (c KbbiClient) cache_get_or_init(key string, init fn (key string) !string) !string {
	db_key := key.to_lower()
	cached := sql c.cache_db {
		select from CacheEntry where key == db_key limit 1
	} or {
		cache := CacheEntry{
			key: db_key
			value: init(key)!
			created_at: time.now()
		}

		sql c.cache_db {
			insert cache into CacheEntry
		}

		cache
	}

	return cached.value
}
