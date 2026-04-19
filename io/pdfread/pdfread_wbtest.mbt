///|
test "@pdfsyntax.lex_keyword rewinds endobj suffix" {
  let input = @pdfio.Input::of_string("endobj123 0 obj")
  let token = @pdfsyntax.lex_keyword(input)
  match token {
    LexEndObj => ()
    _ => fail("expected LexEndObj")
  }
  match @pdfsyntax.lex_number(input) {
    LexInt(123) => ()
    _ => fail("expected 123")
  }
}

///|
test "@pdfsyntax.lex_next returns LexNone for unknown uppercase" {
  let input = @pdfio.Input::of_string("T")
  let dict_level : Ref[Int] = { val: 0 }
  let array_level : Ref[Int] = { val: 0 }
  let previous = Array::new()
  let token = @pdfsyntax.lex_next(
    dict_level,
    array_level,
    false,
    input,
    previous,
    true,
    _ => [],
  )
  match token {
    LexNone => ()
    _ => fail("expected LexNone")
  }
}

///|
test "@pdfsyntax.lex_next recovers from lex errors" {
  let input = @pdfio.Input::of_string("(")
  let dict_level : Ref[Int] = { val: 0 }
  let array_level : Ref[Int] = { val: 0 }
  let previous = Array::new()
  let token = @pdfe.with_logger(_ => (), fn() {
    @pdfsyntax.lex_next(dict_level, array_level, false, input, previous, true, _ => {
      []
    })
  })
  match token {
    StopLexing => ()
    _ => fail("expected StopLexing")
  }
}

///|
test "@pdfsyntax.lex_hexstring rejects invalid hex" {
  let input = @pdfio.Input::of_string("<G>")
  let res : Result[@pdftoken.Token, Error] = try? @pdfsyntax.lex_hexstring(
    input,
  )
  match res {
    Err(_) => ()
    _ => fail("expected @pdfsyntax.lex_hexstring failure")
  }
}

///|
test "@pdfsyntax.lex_hexstring pads odd nibble" {
  let input = @pdfio.Input::of_string("<F>")
  let token = @pdfsyntax.lex_hexstring(input)
  match token {
    LexString(s) => {
      let bytes = @pdfio.bytes_of_string(s)
      assert_eq(bytes.length(), 1)
      assert_eq(bytes[0].to_int(), 0xF0)
    }
    _ => fail("expected LexString")
  }
}

///|
test "@pdfsyntax.lex_hexstring ignores whitespace" {
  let input = @pdfio.Input::of_string("<0F 0A>")
  let token = @pdfsyntax.lex_hexstring(input)
  match token {
    LexString(s) => {
      let bytes = @pdfio.bytes_of_string(s)
      assert_eq(bytes.length(), 2)
      assert_eq(bytes[0].to_int(), 0x0F)
      assert_eq(bytes[1].to_int(), 0x0A)
    }
    _ => fail("expected LexString")
  }
}

///|
test "@pdfsyntax.lex_dictionary minus_one stops after closing dict" {
  let input = @pdfio.Input::of_string("/Type /Example >> trailer")
  let tokens = @pdfsyntax.lex_dictionary(true, input)
  if tokens.length() == 0 {
    fail("expected tokens")
  }
  let last = tokens[tokens.length() - 1]
  match last {
    LexRightDict => ()
    _ => fail("expected closing dict")
  }
}

///|
test "@pdfsyntax.lex_name rejects invalid hex" {
  let input = @pdfio.Input::of_string("/#GZ")
  let res : Result[@pdftoken.Token, Error] = try? @pdfsyntax.lex_name(input)
  match res {
    Err(_) => ()
    _ => fail("expected @pdfsyntax.lex_name failure")
  }
}

///|
test "@pdfsyntax.lex_name rejects truncated hex" {
  let input = @pdfio.Input::of_string("/#1")
  let res : Result[@pdftoken.Token, Error] = try? @pdfsyntax.lex_name(input)
  match res {
    Err(_) => ()
    _ => fail("expected @pdfsyntax.lex_name failure")
  }
}
