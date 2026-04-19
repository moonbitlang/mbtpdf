///|
fn keyword_of_string(value : String) -> Calculator? {
  match value {
    "abs" => Some(Abs)
    "add" => Some(Add)
    "atan" => Some(Atan)
    "ceiling" => Some(Ceiling)
    "cos" => Some(Cos)
    "cvi" => Some(Cvi)
    "cvr" => Some(Cvr)
    "div" => Some(Div)
    "exp" => Some(Exp)
    "floor" => Some(Floor)
    "idiv" => Some(Idiv)
    "ln" => Some(Ln)
    "log" => Some(Log)
    "mod" => Some(Mod)
    "mul" => Some(Mul)
    "neg" => Some(Neg)
    "round" => Some(Round)
    "sin" => Some(Sin)
    "sqrt" => Some(Sqrt)
    "sub" => Some(Sub)
    "truncate" => Some(Truncate)
    "and" => Some(And)
    "bitshift" => Some(Bitshift)
    "eq" => Some(Eq)
    "ge" => Some(Ge)
    "gt" => Some(Gt)
    "le" => Some(Le)
    "lt" => Some(Lt)
    "ne" => Some(Ne)
    "not" => Some(Not)
    "or" => Some(Or)
    "xor" => Some(Xor)
    "copy" => Some(Copy)
    "exch" => Some(Exch)
    "pop" => Some(Pop)
    "dup" => Some(Dup)
    "index" => Some(Index)
    "roll" => Some(Roll)
    _ => None
  }
}

///|
priv enum CalcTok {
  LBrace
  RBrace
  Bool(Bool)
  Int(Int)
  Real(Double)
  Name(String)
}

///|
priv enum CalcNode {
  Atom(CalcTok)
  Proc(Array[CalcNode])
}

///|
fn is_calc_whitespace(c : Char) -> Bool {
  c is ('\u{0000}' | '\t' | '\n' | '\u{000C}' | '\r' | ' ')
}

///|
fn calc_dropwhite(input : @pdfio.Input) -> Unit {
  while true {
    let b = input.peek_byte()
    if b == @pdfio.no_more {
      break
    }
    let c = b.to_byte().to_char()
    if is_calc_whitespace(c) {
      input.nudge()
      continue
    }
    break
  }
}

///|
fn calc_skip_comment(input : @pdfio.Input) -> Unit {
  let _ = (input.input_byte)()
  while true {
    let b = (input.input_byte)()
    if b == @pdfio.no_more {
      break
    }
    let c = b.to_byte().to_char()
    if c == '\n' || c == '\r' {
      break
    }
  }
}

///|
fn calc_read_word(input : @pdfio.Input) -> String {
  let bytes : Array[Byte] = Array::new()
  while true {
    let b = (input.input_byte)()
    if b == @pdfio.no_more {
      break
    }
    let c = b.to_byte().to_char()
    if is_calc_whitespace(c) || c == '{' || c == '}' || c == '%' {
      input.rewind()
      break
    }
    bytes.push(b.to_byte())
  }
  @pdfio.string_of_bytes(bytes)
}

///|
fn calc_token_of_word(word : String) -> CalcTok {
  match word {
    "true" => Bool(true)
    "false" => Bool(false)
    _ =>
      try @strconv.parse_int(word) catch {
        _ =>
          try @strconv.parse_double(word) catch {
            _ => Name(word)
          } noraise {
            f => Real(f)
          }
      } noraise {
        i => Int(i)
      }
  }
}

///|
fn calc_lex(text : String) -> Array[CalcTok] {
  let input = @pdfio.Input::of_string(text)
  let out = Array::new()
  while true {
    calc_dropwhite(input)
    let b = input.peek_byte()
    if b == @pdfio.no_more {
      break
    }
    let c = b.to_byte().to_char()
    match c {
      '%' => calc_skip_comment(input)
      '{' => {
        input.nudge()
        out.push(CalcTok::LBrace)
      }
      '}' => {
        input.nudge()
        out.push(RBrace)
      }
      _ => {
        let word = calc_read_word(input)
        if word.length() > 0 {
          out.push(calc_token_of_word(word))
        } else {
          input.nudge()
        }
      }
    }
  }
  out
}

///|
fn calc_parse_seq(
  toks : Array[CalcTok],
  start : Int,
  stop_on_rbrace : Bool,
) -> (Array[CalcNode], Int) raise {
  let out = Array::new()
  let mut i = start
  while i < toks.length() {
    match toks[i] {
      RBrace =>
        if stop_on_rbrace {
          return (out, i + 1)
        } else {
          raise @pdf.PdfError::Msg("Unexpected '}' in Type 4 function")
        }
      LBrace => {
        let (body, next_i) = calc_parse_seq(toks, i + 1, true)
        out.push(Proc(body))
        i = next_i
      }
      other => {
        out.push(Atom(other))
        i = i + 1
      }
    }
  }
  if stop_on_rbrace {
    raise @pdf.PdfError::Msg("Unclosed '{' in Type 4 function")
  }
  (out, i)
}

///|
fn calc_parse_program(toks : Array[CalcTok]) -> Array[CalcNode] raise {
  match toks {
    [LBrace, ..] => {
      let (nodes, next_i) = calc_parse_seq(toks, 1, true)
      if next_i != toks.length() {
        raise @pdf.PdfError::Msg("Trailing tokens after Type 4 program")
      }
      nodes
    }
    _ => {
      let (nodes, next_i) = calc_parse_seq(toks, 0, false)
      if next_i != toks.length() {
        raise @pdf.PdfError::Msg("Trailing tokens after Type 4 program")
      }
      nodes
    }
  }
}

///|
fn calc_compile(nodes : Array[CalcNode]) -> Array[Calculator] raise {
  let out = Array::new(capacity=nodes.length())
  let mut i = 0
  while i < nodes.length() {
    if i + 2 < nodes.length() {
      match (nodes[i], nodes[i + 1], nodes[i + 2]) {
        (Proc(a), Proc(b), Atom(Name("ifelse"))) => {
          out.push(Calculator::IfElse(calc_compile(a), calc_compile(b)))
          i = i + 3
          continue
        }
        _ => ()
      }
    }
    if i + 1 < nodes.length() {
      match (nodes[i], nodes[i + 1]) {
        (Proc(body), Atom(Name("if"))) => {
          out.push(If(calc_compile(body)))
          i = i + 2
          continue
        }
        _ => ()
      }
    }
    match nodes[i] {
      Proc(_) =>
        raise @pdf.PdfError::Msg("Unexpected '{...}' in Type 4 function")
      Atom(Bool(b)) => out.push(Bool(b))
      Atom(Int(v)) => out.push(Int(v))
      Atom(Real(f)) => out.push(Float(f))
      Atom(Name(name)) =>
        match keyword_of_string(name) {
          Some(op) => out.push(op)
          None => {
            @pdfe.log("Bad keyword \{name}\n")
            raise @pdf.PdfError::Msg("Cannot parse Type 4 function")
          }
        }
      Atom(LBrace | RBrace) =>
        raise @pdf.PdfError::Msg("Unexpected brace token in Type 4 function")
    }
    i = i + 1
  }
  out
}

///|
fn parse_calculator(text : String) -> Array[Calculator] raise {
  calc_compile(calc_parse_program(calc_lex(text)))
}

///|
/// Parse a function given a document and function object.
pub fn PdfFunction::parse(pdf : @pdf.Pdf, obj : PdfObject) -> PdfFunction raise {
  let f = pdf.direct(obj)
  let getnum_direct = (value : PdfObject) => pdf.getnum(value)
  let domain = match pdf.lookup_fail("No /Domain", "/Domain", f) {
    PdfArray(values) => values.map(getnum_direct)
    _ => raise @pdf.PdfError::Msg("Bad /Domain")
  }
  let range = match pdf.lookup_direct("/Range", f) {
    Some(PdfArray(values)) => Some(values.map(getnum_direct))
    _ => None
  }
  let func = match pdf.lookup_fail("no /FunctionType", "/FunctionType", f) {
    Integer(0) => {
      let size = match pdf.lookup_fail("no /Size (sampled fun)", "/Size", f) {
        PdfArray(values) =>
          values.map(value => {
            match value {
              Integer(n) => n
              _ => raise @pdf.PdfError::Msg("bad /Size (sampled fun)")
            }
          })
        _ => raise @pdf.PdfError::Msg("Bad /Size (sampled fun)")
      }
      let order = match pdf.lookup_direct("/Order", f) {
        Some(Integer(n)) => n
        _ => 1
      }
      let encode = match pdf.lookup_direct("/Encode", f) {
        Some(PdfArray(values)) if values.length() == 2 * size.length() =>
          values.map(getnum_direct)
        _ =>
          interleave_lists(
            many(0.0, size.length()),
            size.map(x => (x - 1).to_double()),
          )
      }
      let decode = match pdf.lookup_direct("/Decode", f) {
        Some(PdfArray(values)) => values.map(getnum_direct)
        _ =>
          match range {
            Some(values) => values
            None => raise @pdf.PdfError::Msg("No /Range")
          }
      }
      let bitspersample = match
        pdf.lookup_fail("no /BitsPerSample", "/BitsPerSample", f) {
        Integer(i) => i
        _ => raise @pdf.PdfError::Msg("Bad /BitsPerSample")
      }
      @pdfcodec.PdfCodec::new().decode_pdfstream(pdf, f)
      let samples_count = product(size) * (decode.length() / 2)
      let data = match f {
        Stream(r) =>
          match r.val {
            (_, Got(bytes)) => bytes
            _ => raise @pdf.PdfError::Msg("No stream data")
          }
        _ => raise @pdf.PdfError::Msg("This is not a function")
      }
      let samples = read_samples(data, samples_count, bitspersample)
      PdfFunctionKind::Sampled({
        size,
        order,
        encode,
        decode,
        bps: bitspersample,
        samples,
      })
    }
    Integer(2) => {
      let c0 = match pdf.lookup_direct("/C0", f) {
        Some(PdfArray(values)) => values.map(getnum_direct)
        _ => [0.0]
      }
      let c1 = match pdf.lookup_direct("/C1", f) {
        Some(PdfArray(values)) => values.map(getnum_direct)
        _ => [1.0]
      }
      let n = getnum_direct(pdf.lookup_fail("No /N in Type 2 fun", "/N", f))
      Interpolation({ c0, c1, n })
    }
    Integer(3) => {
      let functions = match pdf.lookup_fail("no /Functions", "/Functions", f) {
        PdfArray(values) => values
        _ => raise @pdf.PdfError::Msg("Bad /Functions")
      }
      let bounds = match pdf.lookup_fail("no /Bounds", "/Bounds", f) {
        PdfArray(values) => values.map(getnum_direct)
        _ => raise @pdf.PdfError::Msg("Bad /Bounds")
      }
      let encode = match pdf.lookup_fail("no /Encode", "/Encode", f) {
        PdfArray(values) => values.map(getnum_direct)
        _ => raise @pdf.PdfError::Msg("Bad /Bounds")
      }
      Stitching({
        functions: functions.map(value => PdfFunction::parse(pdf, value)),
        bounds,
        stitch_encode: encode,
      })
    }
    Integer(4) => {
      @pdfcodec.PdfCodec::new().decode_pdfstream(pdf, f)
      match f {
        Stream(r) =>
          match r.val {
            (_, Got(bytes)) =>
              Calculator(parse_calculator(@pdfio.string_of_bytes(bytes)))
            _ => raise @pdf.PdfError::Msg("This is not a function")
          }
        _ => raise @pdf.PdfError::Msg("This is not a function")
      }
    }
    _ => raise @pdf.PdfError::Msg("Unknown function type")
  }
  { domain, range, func }
}
