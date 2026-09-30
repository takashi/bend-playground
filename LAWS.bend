import Base
import ./api.bend as Api

# 公開エンドポイントは GET /hello の1つだけ。
law hello:
  {Api.route("GET", "/hello") == Api.response("200 OK", "", "{\"message\":\"Hello, Bend!\"}") : String}

# 任意のメソッドとリクエスト先について、クエリを除いたパスの
# 一致判定がFalseなら、必ず404応答を返す。
law not_found:
  for +method: String
  for +target: String
  for different: {String.eq(Api.first(String.split(target, '?')), "/hello") == False{} : Bool}
  {Api.route(method, target) == Api.response("404 Not Found", "", "{\"error\":\"Not Found\"}") : String}

law method_not_allowed:
  {Api.route("POST", "/hello") == Api.response("405 Method Not Allowed", "Allow: GET\r\n", "{\"error\":\"Method Not Allowed\"}") : String}

# DB取得が成功したという前提で、任意の本文を変更せず200応答に含める。
# DBそのものの正しさ・JSONの妥当性・TCP送信の成功は主張しない。
law database_body_preserved:
  for +body: String
  {Api.message_response(Done{body}) == "HTTP/1.1 200 OK\r\nContent-Type: application/json; charset=utf-8\r\nContent-Length: " ++ Nat.show(Api.byte_length(body)) ++ "\r\nConnection: close\r\n\r\n" ++ body : String}

# どんなDBエラーでも、内部のコードやメッセージを応答へ含めない。
law database_error_response:
  for code: U32
  for message: String
  {Api.message_response(Fail{(code, message)}) == "HTTP/1.1 500 Internal Server Error\r\nContent-Type: application/json; charset=utf-8\r\nContent-Length: 26\r\nConnection: close\r\n\r\n{\"error\":\"Database Error\"}" : String}
