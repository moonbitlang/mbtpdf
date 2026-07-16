///|
fn[T] assert_is_err(res : Result[T, Error]) -> Unit raise {
  match res {
    Err(_) => ()
    Ok(_) => fail("expected error")
  }
}

///|
test "lexer covers name, number, and string error paths" {

  // Bad name hex escape.
  assert_is_err(
    try
      @pdfsyntax.lex_name(@pdfio.Input::of_string("/Name#GG", source="name"))
      |> Ok
    catch {
      e => Err(e)
    },
  )

  // Number parsing fallbacks.
  match @pdfsyntax.lex_number(@pdfio.Input::of_string("1e-3", source="real")) {
    LexReal(_) => ()
    other => fail("expected LexReal, got \{@pdfsyntax.string_of_lexeme(other)}")
  }
  match @pdfsyntax.lex_number(@pdfio.Input::of_string("nan", source="nan")) {
    LexReal(_) => ()
    other => fail("expected LexReal, got \{@pdfsyntax.string_of_lexeme(other)}")
  }
  match @pdfsyntax.lex_number(@pdfio.Input::of_string("1.2.3", source="bad")) {
    LexNone => ()
    other => fail("expected LexNone, got \{@pdfsyntax.string_of_lexeme(other)}")
  }
  match
    @pdfsyntax.lex_number(@pdfio.Input::of_string("12a", source="fallback")) {
    LexNone => ()
    other => fail("expected LexNone, got \{@pdfsyntax.string_of_lexeme(other)}")
  }

  // lex_string expects '('.
  assert_is_err(
    try
      @pdfsyntax.lex_string(@pdfio.Input::of_string("abc", source="string"))
      |> Ok
    catch {
      e => Err(e)
    },
  )

  // lex_string escape unexpected EOF.
  assert_is_err(
    try
      @pdfsyntax.lex_string(@pdfio.Input::of_string("(\\", source="eof-string"))
      |> Ok
    catch {
      e => Err(e)
    },
  )

  // lex_string CR escape path with rewind.
  let token = @pdfsyntax.lex_string(
    @pdfio.Input::of_string("(\\\rX)", source="cr"),
  )
  match token {
    LexString(_) => ()
    _ => fail("expected string token")
  }

  // lex_string octal parse error is tolerated.
  let token2 = @pdfsyntax.lex_string(
    @pdfio.Input::of_string("(\\888)", source="octal"),
  )
  match token2 {
    LexString(_) => ()
    _ => fail("expected string token")
  }
}

///|
test "lex_stream_data handles malformed and rewind cases" {

  // CR not followed by LF triggers a rewind.
  match
    @pdfsyntax.lex_stream_data(
      @pdfio.Input::of_string("\rX0123456789\nendstream", source="cr-stream"),
      999,
      false,
    ) {
    LexStream(_) => ()
    other =>
      fail("expected LexStream, got \{@pdfsyntax.string_of_lexeme(other)}")
  }
  // Non-newline char triggers rewind branch too.
  match
    @pdfsyntax.lex_stream_data(
      @pdfio.Input::of_string(" X0123456789\nendstream", source="rewind-stream"),
      999,
      false,
    ) {
    LexStream(_) => ()
    other =>
      fail("expected LexStream, got \{@pdfsyntax.string_of_lexeme(other)}")
  }
}

///|
test "lex_keyword covers R and unknown keywords" {
  match @pdfsyntax.lex_keyword(@pdfio.Input::of_string("R", source="kw-r")) {
    LexR => ()
    other => fail("expected LexR, got \{@pdfsyntax.string_of_lexeme(other)}")
  }
  match
    @pdfsyntax.lex_keyword(
      @pdfio.Input::of_string("nonsense", source="kw-none"),
    ) {
    LexNone => ()
    other => fail("expected LexNone, got \{@pdfsyntax.string_of_lexeme(other)}")
  }
}

///|
test "lex_stream errors when previous lexemes are not a dictionary" {
  let res : Result[@pdftoken.Token, Error] = try
    @pdfsyntax.lex_stream(
      @pdfio.Input::of_string("stream\nabc", source="stream-bad"),
      [LexInt(1)],
      _k => [],
      false,
    )
    |> Ok
  catch {
    e => Err(e)
  }
  assert_is_err(res)
}

///|
test "lex_stream falls back to malformed stream scan on missing /Length" {
  let dict_lexemes = @pdfsyntax.lex_dictionary(
    false,
    @pdfio.Input::of_string("<< /Type /X >>", source="stream-dict"),
  )
  match
    @pdfsyntax.lex_stream(
      @pdfio.Input::of_string("stream\nABCDEF", source="stream-no-end"),
      dict_lexemes,
      _k => [],
      false,
    ) {
    LexStream(_) => ()
    other =>
      fail("expected LexStream, got \{@pdfsyntax.string_of_lexeme(other)}")
  }
}

///|
test "lex_stream resolves indirect /Length via lexobj" {
  let input = @pdfio.Input::of_string(
    (
      #|1 0 obj
      #|<< /Length 2 0 R >>
      #|stream
      #|ABCD
      #|endstream
      #|endobj
    ),
  )
  let tokens = @pdfsyntax.lex_object_at(false, input, true, fn(k) {
    assert_eq(k, 2)
    @pdfsyntax.lex_object_at(
      false,
      @pdfio.Input::of_string(
        (
          #|2 0 obj
          #|4
          #|endobj
        ),
      ),
      true,
      _ => [],
    )
  })
  assert_true(tokens.exists(t => t is LexStream(_)))
}

///|
test "lex_next stops on short 's' sequences" {
  let dict_level : Ref[Int] = { val: 0 }
  let array_level : Ref[Int] = { val: 0 }
  let prev : Array[@pdftoken.Token] = []
  let t1 = @pdfsyntax.lex_next(
    dict_level,
    array_level,
    true,
    @pdfio.Input::of_string("st", source="lex-next-st"),
    prev,
    false,
    _ => [],
  )
  assert_true(t1 is StopLexing)
  let t2 = @pdfsyntax.lex_next(
    dict_level,
    array_level,
    true,
    @pdfio.Input::of_string("sta", source="lex-next-sta"),
    prev,
    false,
    _ => [],
  )
  assert_true(t2 is StopLexing)
}
