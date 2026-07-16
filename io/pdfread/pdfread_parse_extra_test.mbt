///|
test "parse errors on non-name dictionary key" {
  let tokens : Array[Token] = [LexLeftDict, LexInt(1), LexInt(2), LexRightDict]
  let res : Result[(Int, @pdf.PdfObject), Error] = try
    @pdfsyntax.parse(tokens) |> Ok
  catch {
    e => Err(e)
  }
  assert_true(res is Err(_))
}

///|
test "parse errors on invalid array element" {
  let tokens : Array[Token] = [LexLeftSquare, LexRightDict]
  let res : Result[(Int, @pdf.PdfObject), Error] = try
    @pdfsyntax.parse(tokens) |> Ok
  catch {
    e => Err(e)
  }
  assert_true(res is Err(_))
}

///|
test "parse returns null for empty object" {
  let tokens : Array[Token] = [LexInt(10), LexInt(0), LexObj, LexEndObj]
  let (objnum, obj) = @pdfsyntax.parse(tokens)
  assert_eq(objnum, 10)
  match (obj : @pdf.PdfObject) {
    Null => ()
    _ => fail("expected null object")
  }
}

///|
using @pdftoken {type Token}

///|
test "parse skips unmatched stream pattern" {
  let tokens : Array[Token] = [
    LexInt(1),
    LexInt(0),
    LexObj,
    LexBool(false),
    LexInt(2),
    LexInt(3),
    LexInt(4),
  ]
  let (objnum, obj) = @pdfsyntax.parse(tokens)
  assert_eq(objnum, 1)
  match (obj : @pdf.PdfObject) {
    Boolean(false) => ()
    _ => fail("expected boolean object")
  }
}

///|
test "parse returns null when failure_is_ok" {
  let tokens : Array[Token] = [LexObj, LexEndObj]
  let (objnum, obj) = @pdfsyntax.parse(tokens, failure_is_ok=true)
  assert_eq(objnum, 0)
  match (obj : @pdf.PdfObject) {
    Null => ()
    _ => fail("expected null fallback object")
  }
}
