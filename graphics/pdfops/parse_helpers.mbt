///|
fn split_lexemes(lexemes : Array[Lexeme], start : Int) -> (Array[Lexeme], Int) {
  let section : Array[Lexeme] = Array()
  let mut i = start
  let len = lexemes.length()
  while i < len {
    let lexeme = lexemes[i]
    section.push(lexeme)
    match lexeme {
      Op(_) | LexInlineImage(_) => return (section, i + 1)
      _ => ()
    }
    i = i + 1
  }
  (section, i)
}

///|
fn lexeme_real(lexeme : Lexeme) -> Double? {
  match lexeme {
    Obj(LexReal(value)) => Some(value)
    Obj(LexInt(value)) => Some(Double::from_int(value))
    _ => None
  }
}

///|
fn lexeme_int(lexeme : Lexeme) -> Int? {
  match lexeme {
    Obj(LexInt(value)) => Some(value)
    Obj(LexReal(value)) => Some(value.to_int())
    _ => None
  }
}

///|
fn lexeme_name(lexeme : Lexeme) -> String? {
  match lexeme {
    Obj(LexName(name)) => Some(name)
    _ => None
  }
}

///|
fn lexeme_string(lexeme : Lexeme) -> String? {
  match lexeme {
    Obj(LexString(text)) => Some(text)
    _ => None
  }
}

///|
fn lexeme_pdfobj(lexeme : Lexeme) -> @pdf.PdfObject? raise {
  match lexeme {
    PdfObj(obj) => Some(obj)
    Obj(token) => Some(@pdfsyntax.parse([token]).1)
    _ => None
  }
}

///|
fn reals_of_lexemes(
  lexemes : ArrayView[Lexeme],
  errtext : String,
) -> Array[Double] {
  let out : Array[Double] = Array()
  for lexeme in lexemes {
    match lexeme_real(lexeme) {
      Some(value) => out.push(value)
      None => {
        @pdfe.log(errtext + "\n")
        return [0.0, 0.0, 0.0]
      }
    }
  }
  out
}

///|
fn parse_dash_op(section : Array[Lexeme]) -> Op raise {
  if section.length() < 4 {
    raise @pdf.PdfError::Msg("malformed 'd' op")
  }
  let op = section[section.length() - 1]
  if op is Op("d") {
    let phase = match lexeme_real(section[section.length() - 2]) {
      Some(value) => value
      None => raise @pdf.PdfError::Msg("malformed 'd' op")
    }
    let right = section[section.length() - 3]
    if right is Obj(LexRightSquare) {
      let mut left_index = -1
      for i in 0..<(section.length() - 3) {
        match section[i] {
          Obj(LexLeftSquare) => left_index = i
          _ => ()
        }
      }
      if left_index < 0 {
        raise @pdf.PdfError::Msg("malformed 'd' op")
      }
      let values : Array[Double] = Array()
      for idx in (left_index + 1)..<(section.length() - 3) {
        match lexeme_real(section[idx]) {
          Some(value) => values.push(value)
          None => raise @pdf.PdfError::Msg("malformed 'd' op")
        }
      }
      return Opd(values, phase)
    }
  }
  raise @pdf.PdfError::Msg("malformed 'd' op")
}

///|
fn parse_tj_op(section : Array[Lexeme]) -> Op raise {
  let op = section[section.length() - 1]
  if op is Op("TJ") {
    if section.length() < 3 {
      raise @pdf.PdfError::Msg("malformed TJ op")
    }
    let right = section[section.length() - 2]
    if right is Obj(LexRightSquare) {
      let mut left_index = -1
      for i in 0..<(section.length() - 2) {
        match section[i] {
          Obj(LexLeftSquare) => left_index = i
          _ => ()
        }
      }
      if left_index < 0 {
        raise @pdf.PdfError::Msg("malformed TJ op")
      }
      let elements : Array[@pdf.PdfObject] = Array()
      for idx in (left_index + 1)..<(section.length() - 2) {
        match section[idx] {
          Obj(LexReal(value)) => elements.push(Real(value))
          Obj(LexInt(value)) => elements.push(Real(Double::from_int(value)))
          Obj(LexString(text)) => elements.push(PdfString(text))
          _ => @pdfe.warn("Warning: malformed TJ element; skipping")
        }
      }
      return OpTJ(PdfArray(elements))
    }
  }
  raise @pdf.PdfError::Msg("malformed TJ op")
}

///|
test "parse helpers cover int/real conversion paths" {
  assert_eq(lexeme_real(Obj(LexInt(2))).unwrap(), 2.0)
  assert_eq(lexeme_int(Obj(LexInt(2))).unwrap(), 2)
  match lexeme_pdfobj(Op("q")) {
    None => ()
    Some(_) => fail("expected non-object lexeme to return None")
  }
  let op = parse_tj_op([
    Obj(LexLeftSquare),
    Obj(LexString("A")),
    Obj(LexInt(120)),
    Obj(LexString("B")),
    Obj(LexRightSquare),
    Op("TJ"),
  ])
  match op {
    OpTJ(PdfArray(values)) => {
      assert_eq(values.length(), 3)
      match values[1] {
        Real(v) => assert_eq(v, 120.0)
        _ => fail("expected int TJ element to be converted to Real")
      }
    }
    _ => fail("expected OpTJ")
  }
}
