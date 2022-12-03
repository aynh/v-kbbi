module client

import os
import sqlite
import time
import v.vmod

[table: 'response_cache']
struct CacheEntry {
	id         int       [primary; sql: serial]
	key        string    [nonull; unique]
	value      string    [nonull]
	created_at time.Time [nonull; sql_type: 'DATETIME']
}

fn (c KbbiClient) cache_db() !sqlite.DB {
	cache_dir := c.cache_dir()
	os.mkdir_all(cache_dir)!

	vm := vmod.decode(@VMOD_FILE) or { panic(err) }
	db := sqlite.connect(os.join_path(cache_dir, vm.version + '.db'))!

	sql db {
		create table CacheEntry
	}

	return db
}

fn (c KbbiClient) cache_dir() string {
	vm := vmod.decode(@VMOD_FILE) or { panic(err) }
	return os.norm_path(os.join_path(os.cache_dir(), 'v' + vm.name))
}
