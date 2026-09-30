import Base
import ./LAWS.bend as Laws
import ./api.bend as Api

def Laws.hello():
  {==}

def Laws.not_found(method, target, different):
  Equal.cong(Bool, String,
    found => Api.route_result(found, String.eq(method, "GET")),
    String.eq(Api.first(String.split(target, '?')), "/hello"),
    False{}, different)

def Laws.method_not_allowed():
  {==}

def Laws.database_body_preserved(body):
  {==}

def Laws.database_error_response(code, message):
  {==}
