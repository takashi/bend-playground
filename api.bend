import Base

# HTTPのContent-Lengthは文字数ではなくUTF-8バイト数。
def char_bytes(+code: U32) -> Nat:
  Nat.add(1n, Nat.add(U32.to_nat(Bool.to_u32(U32.is_ge(code, 128))), Nat.add(U32.to_nat(Bool.to_u32(U32.is_ge(code, 2048))), U32.to_nat(Bool.to_u32(U32.is_ge(code, 65536))))))

def byte_length(text: String) -> Nat:
  match text:
    case SNil{}:
      0n
    case SCon{Chr{code}, rest}:
      Nat.add(char_bytes(code), byte_length(rest))

def response(status: String, extra: String, +body: String) -> String:
  "HTTP/1.1 " ++ status ++ "\r\nContent-Type: application/json; charset=utf-8\r\nContent-Length: " ++ Nat.show(byte_length(body)) ++ "\r\nConnection: close\r\n" ++ extra ++ "\r\n" ++ body

# 外部IOから得た結果を、送信する文字列へ変換する純粋な処理。
def message_response(result: Result<&1, &1, U32 & String, String>) -> String:
  match result:
    case Done{body}:
      response("200 OK", "", body)
    case Fail{error}:
      response("500 Internal Server Error", "", "{\"error\":\"Database Error\"}")

def route_result(found: Bool, get: Bool) -> String:
  match found get:
    case False{} _:
      response("404 Not Found", "", "{\"error\":\"Not Found\"}")
    case True{} False{}:
      response("405 Method Not Allowed", "Allow: GET\r\n", "{\"error\":\"Method Not Allowed\"}")
    case True{} True{}:
      response("200 OK", "", "{\"message\":\"Hello, Bend!\"}")

def first(parts: List<&2, String>) -> String:
  match parts:
    case Nil{}:
      ""
    case h <> t:
      h

def route(method: String, target: String) -> String:
  route_result(String.eq(first(String.split(target, '?')), "/hello"), String.eq(method, "GET"))

def request_parts(parts: List<&2, String>) -> String:
  match parts:
    case method <> target <> version <> Nil{}:
      route(method, target)
    case _:
      response("400 Bad Request", "", "{\"error\":\"Bad Request\"}")

def request(raw: String) -> String:
  request_parts(String.split(String.trim(first(String.lines(raw))), ' '))

# DB参照が必要なリクエストだけを選ぶ。404・405は従来の純粋なルーターで処理する。
def needs_message_parts(parts: List<&2, String>) -> Bool:
  match parts:
    case method <> target <> version <> Nil{}:
      Bool.and(String.eq(method, "GET"), String.eq(first(String.split(target, '?')), "/hello"))
    case _:
      False{}

def needs_message(raw: String) -> Bool:
  needs_message_parts(String.split(String.trim(first(String.lines(raw))), ' '))
