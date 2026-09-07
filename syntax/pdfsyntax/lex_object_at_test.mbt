///|
fn lex_from_string(oneonly : Bool, source : String) -> Array[Token] raise {
  let input = @pdfio.Input::of_string(source)
  @pdfsyntax.lex_object_at(oneonly, input, true, _ => [])
}

///|
test "lex_object_at stops at atom when oneonly" {
  let tokens = lex_from_string(true, "123 456")
  match tokens {
    [LexInt(123)] => ()
    _ => fail("expected single integer lexeme")
  }
}

///|
test "lex_object_at captures array tokens" {
  let tokens = lex_from_string(true, "[1 2]")
  let rendered : Array[String] = Array()
  for token in tokens {
    rendered.push(@pdfsyntax.string_of_lexeme(token))
  }
  assert_eq(rendered, ["[", "1", "2", "]"])
}

///|
test "lex_object_at captures dictionary tokens" {
  let tokens = lex_from_string(true, "<< /Type /Example /Count 2 >>")
  let rendered : Array[String] = Array()
  for token in tokens {
    rendered.push(@pdfsyntax.string_of_lexeme(token))
  }
  assert_eq(rendered, ["<<", "/Type", "/Example", "/Count", "2", ">>"])
}

///|
test "lex_object_at reads until endobj when not oneonly" {
  let tokens = lex_from_string(false, "1 0 obj 7 endobj")
  let rendered : Array[String] = Array()
  for token in tokens {
    rendered.push(@pdfsyntax.string_of_lexeme(token))
  }
  assert_eq(rendered, ["1", "0", "obj", "7", "endobj"])
}
