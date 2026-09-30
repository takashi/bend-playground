#include <sqlite3.h>
#include <dlfcn.h>

// ローカルのSQLite共有ライブラリを使い、Bendの追加リンク設定を不要にする。
static Term database_message_run(Env e, Term* f, IoWork* w) {
  const char *library =
#ifdef __APPLE__
    "/usr/lib/libsqlite3.dylib";
#else
    "libsqlite3.so.0";
#endif
  void *lib = dlopen(library, RTLD_NOW | RTLD_LOCAL);
  if (!lib) return io_fail(e, 1, "SQLiteライブラリを読み込めません");

#define SQL_FN(name) __typeof__(&name) fn_##name = (__typeof__(&name))dlsym(lib, #name)
  SQL_FN(sqlite3_open_v2);
  SQL_FN(sqlite3_close);
  SQL_FN(sqlite3_busy_timeout);
  SQL_FN(sqlite3_exec);
  SQL_FN(sqlite3_prepare_v2);
  SQL_FN(sqlite3_step);
  SQL_FN(sqlite3_column_text);
  SQL_FN(sqlite3_column_bytes);
  SQL_FN(sqlite3_finalize);
  SQL_FN(sqlite3_errmsg);
#undef SQL_FN
  if (!fn_sqlite3_open_v2 || !fn_sqlite3_close || !fn_sqlite3_busy_timeout ||
      !fn_sqlite3_exec || !fn_sqlite3_prepare_v2 || !fn_sqlite3_step ||
      !fn_sqlite3_column_text || !fn_sqlite3_column_bytes ||
      !fn_sqlite3_finalize || !fn_sqlite3_errmsg) {
    dlclose(lib);
    return io_fail(e, 1, "SQLite APIを読み込めません");
  }

  const char *path = getenv("BEND_DB_PATH");
  if (!path || !*path) path = "app.sqlite";
  sqlite3 *db = NULL;
  sqlite3_stmt *stmt = NULL;
  int flags = (u32)f[0] ? SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE : SQLITE_OPEN_READONLY;
  int rc = fn_sqlite3_open_v2(path, &db, flags, NULL);
  const char *error = "SQLiteを開けません";
  Term result;
  if (rc != SQLITE_OK) goto failed;
  fn_sqlite3_busy_timeout(db, 1000);
  if ((u32)f[0]) {
    rc = fn_sqlite3_exec(db,
      "CREATE TABLE IF NOT EXISTS messages (id INTEGER PRIMARY KEY, message TEXT NOT NULL);"
      "INSERT INTO messages(id, message) VALUES(1, 'Hello, Bend!') ON CONFLICT(id) DO NOTHING;",
      NULL, NULL, NULL);
    if (rc != SQLITE_OK) goto failed;
  }
  rc = fn_sqlite3_prepare_v2(db,
    "SELECT json_object('message', message) FROM messages WHERE id = 1",
    -1, &stmt, NULL);
  if (rc != SQLITE_OK) goto failed;
  rc = fn_sqlite3_step(stmt);
  if (rc != SQLITE_ROW) {
    if (rc == SQLITE_DONE) error = "messagesのid=1がありません";
    goto failed;
  }
  const unsigned char *body = fn_sqlite3_column_text(stmt, 0);
  if (!body) { rc = SQLITE_NOMEM; goto failed; }
  result = io_done(e, io_str(e, (const char *)body, fn_sqlite3_column_bytes(stmt, 0)));
  goto cleanup;

failed:
  if (db && rc != SQLITE_DONE) error = fn_sqlite3_errmsg(db);
  result = io_fail(e, 1, error);
cleanup:
  if (stmt) fn_sqlite3_finalize(stmt);
  if (db) fn_sqlite3_close(db);
  dlclose(lib);
  return result;
}

static void __attribute__((constructor)) database_message_use(void) {
  io_eff(CID_DATABASE_MESSAGE, database_message_run, 0);
}
