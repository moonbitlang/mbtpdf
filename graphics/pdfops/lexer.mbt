///|
fn is_delimiter_char(chr : Char) -> Bool {
  match chr {
    '(' | ')' | '<' | '>' | '[' | ']' | '{' | '}' | '/' | '%' => true
    _ => false
  }
}

///|
fn string_first_char(value : String) -> Char? {
  value.get_char(0)
}

///|
fn string_last_char(value : String) -> Char? {
  let length = value.length()
  if length <= 0 {
    None
  } else {
    value.get_char(length - 1)
  }
}

///|
fn strip_dict_markers(value : String) -> String {
  if value.length() < 4 {
    value
  } else {
    value[2:value.length() - 2].to_owned()
  }
}

///|
fn lex_name(input : @pdfio.Input) -> Lexeme raise {
  input.nudge()
  Obj(LexName("/" + input.getuntil_white_or_delimiter_string()))
}

///|
fn nocontent(input : @pdfio.Input) -> Unit raise {
  @pdfe.debug("Failed to understand content on page\n")
  if @pdfe.read_debug.val {
    @pdfio.debug_next_n_chars(20, input)
  }
  raise CouldntHandleContent
}

///|
fn lex_number(input : @pdfio.Input) -> Lexeme raise {
  match (@pdfsyntax.lex_number(input) : Token) {
    LexReal(value) => Obj(LexReal(value))
    LexInt(value) => Obj(LexReal(Double::from_int(value)))
    _ => {
      nocontent(input)
      Obj(LexReal(0.0))
    }
  }
}

///|
fn get_dictionary(input : @pdfio.Input) -> Lexeme raise {
  PdfObj(@pdfsyntax.parse(@pdfsyntax.lex_dictionary(false, input)).1)
}

///|
fn lex_string(input : @pdfio.Input) -> Lexeme raise {
  match (@pdfsyntax.lex_string(input) : Token) {
    LexString(text) => Obj(LexString(text))
    _ => {
      nocontent(input)
      Obj(LexString(""))
    }
  }
}

///|
fn lex_hexstring(input : @pdfio.Input) -> Lexeme raise {
  match (@pdfsyntax.lex_hexstring(input) : Token) {
    LexString(text) => Obj(LexString(text))
    _ => {
      nocontent(input)
      Obj(LexString(""))
    }
  }
}

///|
fn lex_next(
  pdf : @pdf.Pdf,
  resources : @pdf.PdfObject,
  input : @pdfio.Input,
) -> Lexeme raise {
  try {
    input.dropwhite()
    let next = input.peek_byte()
    if next == @pdfio.no_more {
      raise LexingEnd
    }
    let chr_opt = next.to_char()
    match chr_opt {
      Some('/') => lex_name(input)
      Some('+' | '-' | '.' | '0'..='9') => lex_number(input)
      Some('A'..='Z' | 'a'..='z') => lex_keyword(pdf, resources, input)
      Some('\'') | Some('\"') => lex_keyword(pdf, resources, input)
      Some('(') => lex_string(input)
      Some('[') => {
        input.nudge()
        Obj(LexLeftSquare)
      }
      Some(']') => {
        input.nudge()
        Obj(LexRightSquare)
      }
      Some('<') => {
        input.nudge()
        let next_char = input.peek_char()
        input.rewind()
        match next_char {
          Some('<') => get_dictionary(input)
          _ => lex_hexstring(input)
        }
      }
      Some('%') => {
        ignore(@pdfsyntax.lex_comment(input))
        LexComment
      }
      _ => raise @pdf.PdfError::Msg("Lexing failure in content stream")
    }
  } catch {
    @pdf.PdfError::Msg(message) =>
      raise @pdf.PdfError::Msg("pdfops.lex_next => \{message}")
    CouldntHandleContent => raise @pdf.PdfError::Msg("Malformed page content")
    err => raise err
  }
}

///|
fn lex_stream(
  pdf : @pdf.Pdf,
  resources : @pdf.PdfObject,
  input : @pdfio.Input,
) -> Array[Lexeme] raise {
  let lexemes : Array[Lexeme] = Array::new()
  try {
    while true {
      let lexeme = lex_next(pdf, resources, input)
      match lexeme {
        LexComment => ()
        _ => lexemes.push(lexeme)
      }
    }
    lexemes
  } catch {
    LexingEnd => lexemes
    err => raise err
  }
}

///|
/// Parse a single decoded content stream into operators.
///
/// This expects **decoded bytes**. If you have a PDF `Stream` object (possibly
/// compressed), use `Op::parse_operators` which will decode `/Contents` streams
/// before parsing.
pub fn Op::parse_single_stream(
  pdf : @pdf.Pdf,
  resources : @pdf.PdfObject,
  stream : Array[Byte],
) -> Array[Op] raise {
  let input = @pdfio.Input::of_bytes(stream)
  let lexemes = lex_stream(pdf, resources, input)
  parse_lexemes({ val: 0 }, lexemes)
}
