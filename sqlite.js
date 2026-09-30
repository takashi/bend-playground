function database_message(initialize) {
  let db;
  try {
    const { Database } = require("bun:sqlite");
    db = new Database(process.env.BEND_DB_PATH || "app.sqlite", {
      readonly: !initialize,
      create: !!initialize,
    });
    db.exec("PRAGMA busy_timeout = 1000");
    if (initialize) {
      db.exec("CREATE TABLE IF NOT EXISTS messages (id INTEGER PRIMARY KEY, message TEXT NOT NULL)");
      db.exec("INSERT INTO messages(id, message) VALUES(1, 'Hello, Bend!') ON CONFLICT(id) DO NOTHING");
    }
    const row = db.query("SELECT json_object('message', message) AS body FROM messages WHERE id = 1").get();
    if (!row) return io_fail(1, "messagesのid=1がありません");
    return io_done(row.body);
  } catch (error) {
    console.error("SQLite:", error.message);
    return io_fail(1, "SQLiteの読み出しに失敗しました");
  } finally {
    db?.close();
  }
}
