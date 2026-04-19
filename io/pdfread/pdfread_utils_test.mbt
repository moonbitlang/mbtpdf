///|
test "getuntil_white_or_delimiter_string stops before delimiter" {
  let input = @pdfio.Input::of_string("abc/def")
  let token = input.getuntil_white_or_delimiter_string()
  assert_eq(token, "abc")
  match (input.input_char)() {
    Some('/') => ()
    _ => fail("expected delimiter")
  }
}

///|
test "dropwhite skips whitespace" {
  let input = @pdfio.Input::of_string(" \t\nabc")
  input.dropwhite()
  match (input.input_char)() {
    Some('a') => ()
    _ => fail("expected first non-whitespace char")
  }
}

///|
test "ignoreuntil leaves delimiter" {
  let input = @pdfio.Input::of_string("xx#yy")
  input.ignoreuntil(true, c => c == '#')
  match (input.input_char)() {
    Some('#') => ()
    _ => fail("expected # delimiter")
  }
}

///|
test "getuntil fails on eof when required" {
  let input = @pdfio.Input::of_string("abc")
  let res : Result[Array[Char], Error] = try? input.getuntil(false, c => {
    c == '/'
  })
  assert_true(res is Err(_))
}
