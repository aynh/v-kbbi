module cache

import os
import sqlite
import time
import v.vmod

[table: 'response_cache']
pub struct CacheEntry {
	id int [primary; sql: serial]
pub:
	key        string    [nonull; unique]
	value      string    [nonull]
	created_at time.Time [nonull; sql_type: 'DATETIME']
}

pub fn cache_db() !sqlite.DB {
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

pub fn get_or_init(db sqlite.DB, key string, init fn (key string) !string) !string {
	db_key := key.to_lower()
	cached := if db.is_open {
		tmp := sql db {
			select from CacheEntry where key == db_key limit 1
		}
		tmp
	} else {
		CacheEntry{}
	}

	return if cached.value != '' {
		cached.value
	} else {
		cache := CacheEntry{
			key: db_key
			value: init(key)!
			created_at: time.now()
		}

		sql db {
			insert cache into CacheEntry
		}

		cache.value
	}
}
