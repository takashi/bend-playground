import Base
import ./api.bend as Api

# initialize=1でテーブルと初期メッセージを作成。0では読み出しのみ。
def Database.message(initialize: U32) -> IO(Result<&1, &1, U32 & String, String>):
  import "./sqlite.c"
  import "./sqlite.js"

def close_sent(sent: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  (socket, result) = sent
  Socket.close(socket)

def send(socket: Socket, text: String) -> IO(Unit):
  IO.bind(Socket & Result<&1, &1, U32 & String, Unit>, Unit, TCP.send(socket, text), close_sent)

def send_message(result: Result<&1, &1, U32 & String, String>, socket: Socket) -> IO(Unit):
  match result:
    case Done{body}:
      send(socket, Api.message_response(Done{body}))
    case Fail{(code, +message)}:
      do IO<Unit>:
        IO.print_err(message)
        send(socket, Api.message_response(Fail{(code, message)}))

def handle(load: Bool, socket: Socket, text: String) -> IO(Unit):
  match load:
    case False{}:
      send(socket, Api.request(text))
    case True{}:
      do IO<Unit>:
        result : Result<&1, &1, U32 & String, String> <- Database.message(0)
        send_message(result, socket)

def complete(done: Bool, socket: Socket, +text: String, next: Socket -> String -> IO(Unit)) -> IO(Unit):
  match done:
    case True{}:
      handle(Api.needs_message(text), socket, text)
    case False{}:
      next(socket, text)

def chunk_received(empty: Bool, socket: Socket, buffer: String, chunk: String, next: Socket -> String -> IO(Unit)) -> IO(Unit):
  match empty:
    case True{}:
      Socket.close(socket)
    case False{}:
      +text = buffer ++ chunk
      complete(String.contains(text, "\r\n\r\n"), socket, text, next)

def received(
  result: Socket & Result<&1, &1, U32 & String, String>,
  buffer: String, next: Socket -> String -> IO(Unit)
) -> IO(Unit):
  (socket, result) = result
  match result:
    case Fail{error}:
      Socket.close(socket)
    case Done{+chunk}:
      chunk_received(String.is_empty(chunk), socket, buffer, chunk, next)

# 受信の分割に対応し、最大32回・各1024バイトまでヘッダーを読む。
def receive(fuel: Nat, socket: Socket, +buffer: String) -> IO(Unit):
  match fuel:
    case 0n:
      send(socket, Api.response("431 Request Header Fields Too Large", "", "{\"error\":\"Headers Too Large\"}"))
    case 1n+rest:
      do IO<Unit>:
        result : Socket & Result<&1, &1, U32 & String, String> <- TCP.recv(socket, 1024)
        received(result, buffer, s => text => receive(rest, s, text))

def accepted(
  result: Listener & Result<&1, &1, U32 & String, Socket>,
  next: Listener -> IO(Unit)
) -> IO(Unit):
  (listener, result) = result
  match result:
    case Fail{(code, message)}:
      do IO<Unit>:
        IO.print_err(message)
        next(listener)
    case Done{socket}:
      do IO<Unit>:
        IO.spawn(Unit, receive(32n, socket, ""))
        next(listener)

# 受付回数で終了させないため、このループだけ停止性チェックの対象外にする。
@unsafe
def serve(listener: Listener) -> IO(Unit):
  do IO<Unit>:
    result : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(listener)
    accepted(result, l => serve(l))

def start(+port: U32) -> IO(Unit):
  do IO<Unit>:
    initial : String <- IO.try(String, Database.message(1))
    listener : Listener <- IO.try(Listener, TCP.listen(port))
    IO.print("http://localhost:" ++ U32.show(port) ++ "/hello  (Ctrl+C で終了)")
    serve(listener)

def valid_port(valid: Bool, port: Nat) -> IO(Unit):
  match valid:
    case False{}:
      IO.die(Unit, 1, "BEND_PORTは1〜65535の整数にしてください")
    case True{}:
      start(U32.from_nat(port))

def parsed_port(port: Maybe<&2, Nat>) -> IO(Unit):
  match port:
    case None{}:
      IO.die(Unit, 1, "BEND_PORTは1〜65535の整数にしてください")
    case Some{+n}:
      valid_port(Bool.and(Nat.is_gt(n, 0n), Nat.is_le(n, U32.to_nat(65535))), n)

def configured_port(value: Result<&1, &1, U32 & String, String>) -> IO(Unit):
  match value:
    case Fail{error}:
      start(3000)
    case Done{text}:
      parsed_port(Nat.read(text))

def main() -> IO(Unit):
  do IO<Unit>:
    value : Result<&1, &1, U32 & String, String> <- IO.get_env("BEND_PORT")
    configured_port(value)
