///|
fn lexemes_of_op(op : Op) -> Array[Lexeme] {
  let out : Array[Lexeme] = []
  fn push(lexeme : Lexeme) -> Unit {
    out.push(lexeme)
  }

  match op {
    Opw(w) => {
      push(Obj(LexReal(w)))
      push(Op("w"))
    }
    OpJ(j) => {
      push(Obj(LexInt(j)))
      push(Op("J"))
    }
    Opj(j) => {
      push(Obj(LexInt(j)))
      push(Op("j"))
    }
    OpM(m) => {
      push(Obj(LexReal(m)))
      push(Op("M"))
    }
    Opd(values, phase) => {
      push(Obj(LexLeftSquare))
      for value in values {
        push(Obj(LexReal(value)))
      }
      push(Obj(LexRightSquare))
      push(Obj(LexReal(phase)))
      push(Op("d"))
    }
    Opri(name) => {
      push(Obj(LexName(name)))
      push(Op("ri"))
    }
    Opi(value) => {
      push(Obj(LexInt(value)))
      push(Op("i"))
    }
    Opgs(name) => {
      push(Obj(LexName(name)))
      push(Op("gs"))
    }
    Opq => push(Op("q"))
    OpQ => push(Op("Q"))
    Opcm(t) => {
      push(Obj(LexReal(t.a)))
      push(Obj(LexReal(t.b)))
      push(Obj(LexReal(t.c)))
      push(Obj(LexReal(t.d)))
      push(Obj(LexReal(t.e)))
      push(Obj(LexReal(t.f)))
      push(Op("cm"))
    }
    Opm(x, y) => {
      push(Obj(LexReal(x)))
      push(Obj(LexReal(y)))
      push(Op("m"))
    }
    Opl(x, y) => {
      push(Obj(LexReal(x)))
      push(Obj(LexReal(y)))
      push(Op("l"))
    }
    Opc(x1, y1, x2, y2, x3, y3) => {
      push(Obj(LexReal(x1)))
      push(Obj(LexReal(y1)))
      push(Obj(LexReal(x2)))
      push(Obj(LexReal(y2)))
      push(Obj(LexReal(x3)))
      push(Obj(LexReal(y3)))
      push(Op("c"))
    }
    Opv(x2, y2, x3, y3) => {
      push(Obj(LexReal(x2)))
      push(Obj(LexReal(y2)))
      push(Obj(LexReal(x3)))
      push(Obj(LexReal(y3)))
      push(Op("v"))
    }
    Opy(x1, y1, x3, y3) => {
      push(Obj(LexReal(x1)))
      push(Obj(LexReal(y1)))
      push(Obj(LexReal(x3)))
      push(Obj(LexReal(y3)))
      push(Op("y"))
    }
    Oph => push(Op("h"))
    Opre(x, y, w, h) => {
      push(Obj(LexReal(x)))
      push(Obj(LexReal(y)))
      push(Obj(LexReal(w)))
      push(Obj(LexReal(h)))
      push(Op("re"))
    }
    OpS => push(Op("S"))
    Ops => push(Op("s"))
    Opf => push(Op("f"))
    OpF => push(Op("F"))
    OpfStar => push(Op("f*"))
    OpB => push(Op("B"))
    OpBStar => push(Op("B*"))
    Opb => push(Op("b"))
    OpbStar => push(Op("b*"))
    Opn => push(Op("n"))
    OpW => push(Op("W"))
    OpWStar => push(Op("W*"))
    OpBT => push(Op("BT"))
    OpET => push(Op("ET"))
    OpTc(value) => {
      push(Obj(LexReal(value)))
      push(Op("Tc"))
    }
    OpTw(value) => {
      push(Obj(LexReal(value)))
      push(Op("Tw"))
    }
    OpTz(value) => {
      push(Obj(LexReal(value)))
      push(Op("Tz"))
    }
    OpTL(value) => {
      push(Obj(LexReal(value)))
      push(Op("TL"))
    }
    OpTf(name, size) => {
      push(Obj(LexName(name)))
      push(Obj(LexReal(size)))
      push(Op("Tf"))
    }
    OpTr(value) => {
      push(Obj(LexInt(value)))
      push(Op("Tr"))
    }
    OpTs(value) => {
      push(Obj(LexReal(value)))
      push(Op("Ts"))
    }
    OpTd(tx, ty) => {
      push(Obj(LexReal(tx)))
      push(Obj(LexReal(ty)))
      push(Op("Td"))
    }
    OpTD(tx, ty) => {
      push(Obj(LexReal(tx)))
      push(Obj(LexReal(ty)))
      push(Op("TD"))
    }
    OpTm(t) => {
      push(Obj(LexReal(t.a)))
      push(Obj(LexReal(t.b)))
      push(Obj(LexReal(t.c)))
      push(Obj(LexReal(t.d)))
      push(Obj(LexReal(t.e)))
      push(Obj(LexReal(t.f)))
      push(Op("Tm"))
    }
    OpTStar => push(Op("T*"))
    OpTj(text) => {
      push(Obj(LexString(text)))
      push(Op("Tj"))
    }
    OpTJ(obj) => {
      push(PdfObj(obj))
      push(Op("TJ"))
    }
    OpSingleQuote(text) => {
      push(Obj(LexString(text)))
      push(Op("'"))
    }
    OpDoubleQuote(word, char, text) => {
      push(Obj(LexReal(word)))
      push(Obj(LexReal(char)))
      push(Obj(LexString(text)))
      push(Op("\""))
    }
    Opd0(wx, wy) => {
      push(Obj(LexReal(wx)))
      push(Obj(LexReal(wy)))
      push(Op("d0"))
    }
    Opd1(wx, wy, llx, lly, urx, ury) => {
      push(Obj(LexReal(wx)))
      push(Obj(LexReal(wy)))
      push(Obj(LexReal(llx)))
      push(Obj(LexReal(lly)))
      push(Obj(LexReal(urx)))
      push(Obj(LexReal(ury)))
      push(Op("d1"))
    }
    OpCS(name) => {
      push(Obj(LexName(name)))
      push(Op("CS"))
    }
    Opcs(name) => {
      push(Obj(LexName(name)))
      push(Op("cs"))
    }
    OpSC(values) => {
      for value in values {
        push(Obj(LexReal(value)))
      }
      push(Op("SC"))
    }
    Opsc(values) => {
      for value in values {
        push(Obj(LexReal(value)))
      }
      push(Op("sc"))
    }
    OpSCN(values) => {
      for value in values {
        push(Obj(LexReal(value)))
      }
      push(Op("SCN"))
    }
    Opscn(values) => {
      for value in values {
        push(Obj(LexReal(value)))
      }
      push(Op("scn"))
    }
    OpSCNName(name, values) => {
      for value in values {
        push(Obj(LexReal(value)))
      }
      push(Obj(LexName(name)))
      push(Op("SCN"))
    }
    OpscnName(name, values) => {
      for value in values {
        push(Obj(LexReal(value)))
      }
      push(Obj(LexName(name)))
      push(Op("scn"))
    }
    OpG(value) => {
      push(Obj(LexReal(value)))
      push(Op("G"))
    }
    Opg(value) => {
      push(Obj(LexReal(value)))
      push(Op("g"))
    }
    OpRG(r, g, b) => {
      push(Obj(LexReal(r)))
      push(Obj(LexReal(g)))
      push(Obj(LexReal(b)))
      push(Op("RG"))
    }
    Oprg(r, g, b) => {
      push(Obj(LexReal(r)))
      push(Obj(LexReal(g)))
      push(Obj(LexReal(b)))
      push(Op("rg"))
    }
    OpK(c, m, y, k) => {
      push(Obj(LexReal(c)))
      push(Obj(LexReal(m)))
      push(Obj(LexReal(y)))
      push(Obj(LexReal(k)))
      push(Op("K"))
    }
    Opk(c, m, y, k) => {
      push(Obj(LexReal(c)))
      push(Obj(LexReal(m)))
      push(Obj(LexReal(y)))
      push(Obj(LexReal(k)))
      push(Op("k"))
    }
    Opsh(name) => {
      push(Obj(LexName(name)))
      push(Op("sh"))
    }
    InlineImage(data) => push(LexInlineImage(data))
    OpDo(name) => {
      push(Obj(LexName(name)))
      push(Op("Do"))
    }
    OpMP(name) => {
      push(Obj(LexName(name)))
      push(Op("MP"))
    }
    OpDP(name, obj) => {
      push(Obj(LexName(name)))
      push(PdfObj(obj))
      push(Op("DP"))
    }
    OpBMC(name) => {
      push(Obj(LexName(name)))
      push(Op("BMC"))
    }
    OpBDC(name, obj) => {
      push(Obj(LexName(name)))
      push(PdfObj(obj))
      push(Op("BDC"))
    }
    OpEMC => push(Op("EMC"))
    OpBX => push(Op("BX"))
    OpEX => push(Op("EX"))
    OpUnknown(_) => ()
    OpComment(text) =>
      if write_comments.val {
        push(Obj(LexComment(text)))
      } else {
        ()
      }
  }
  out
}

///|
fn lexemes_of_ops(ops : Array[Op]) -> Array[Lexeme] {
  let out : Array[Lexeme] = []
  for op in ops {
    let lexemes = lexemes_of_op(op)
    for lexeme in lexemes {
      out.push(lexeme)
    }
  }
  out
}

///|
fn lexemelists_of_ops(ops : Array[Op]) -> Array[Array[Lexeme]] {
  let out : Array[Array[Lexeme]] = Array(capacity=ops.length())
  for op in ops {
    out.push(lexemes_of_op(op))
  }
  out
}

///|
fn string_of_lexeme(lexeme : Lexeme) -> String raise {
  match lexeme {
    LexComment => ""
    Obj(token) => @pdfsyntax.string_of_lexeme(token)
    Op(op) => op
    PdfObj(obj) => obj.to_string()
    LexInlineImage((dict, dp, data)) => {
      let dict_data = match
        @pdf.Pdf::empty().lookup_direct_orelse("/F", "/Filter", dict) {
        None | Some(PdfArray([])) => {
          let _ = dp
          let dict = dict.add_entry("/F", Name(PdfName(b"/Fl")))
          let encoded = @pdfcodec.PdfCodec::new().encode_flate(data)
          (dict, encoded)
        }
        _ => (dict, data)
      }
      let dict = dict_data.0
      let data = dict_data.1
      let dict = dict.add_entry("/L", Integer(@pdfio.bytes_size(data)))
      let dict_string = dict.to_string()
      let dict_body = strip_dict_markers(dict_string)
      let filters = match
        @pdf.Pdf::empty().lookup_direct_orelse("/F", "/Filter", dict) {
        Some(PdfArray(items)) => items
        Some(Name(name)) => [Name(name)]
        _ => []
      }
      let space = if filterspecial(filters) { "" } else { " " }
      let sb = StringBuilder()
      sb.write_string("BI\n")
      sb.write_string(dict_body)
      sb.write_string(" ID")
      sb.write_string(space)
      sb.write_string(@pdfio.string_of_bytes(data))
      sb.write_string("\nEI\n")
      sb.to_string()
    }
  }
}

///|
fn string_of_lexemes(lexemes : Array[Lexeme]) -> String raise {
  let sb = StringBuilder()
  let mut last_char : Char? = None
  for lexeme in lexemes {
    let text = string_of_lexeme(lexeme)
    if text.length() > 0 {
      let first = string_first_char(text)
      if last_char is Some(prev) && first is Some(curr) {
        if !is_delimiter_char(prev) && !is_delimiter_char(curr) {
          sb.write_char(' ')
        }
      }
      sb.write_string(text)
      last_char = string_last_char(text)
    }
  }
  sb.to_string()
}

///|
/// Render operators as PDF content-stream syntax.
///
/// This is primarily intended for logging, debugging, and test assertions
/// (e.g. snapshotting a rewritten operator sequence as text).
///
/// For producing a real PDF `/Contents` stream object, prefer `stream_of_ops`.
pub fn Op::string_of_ops(ops : Array[Op]) -> String raise {
  string_of_lexemes(lexemes_of_ops(ops))
}

///|
/// Render an operator as PDF content-stream syntax.
///
/// This is equivalent to `Op::string_of_ops([self])`.
pub fn Op::to_string(self : Op) -> String raise {
  Op::string_of_ops([self])
}

///|
/// Concatenate byte streams with whitespace between them.
///
/// This is mainly useful when a page has multiple `/Contents` streams and you
/// want to lex/parse them as a single stream.
pub fn Op::concat_bytess(ss : Array[Array[Byte]]) -> Array[Byte] {
  let mut total = 0
  for bytes in ss {
    total = total + @pdfio.bytes_size(bytes)
  }
  let out = @pdfio.mkbytes(total + ss.length())
  let mut pos = 0
  for bytes in ss {
    let len = @pdfio.bytes_size(bytes)
    for i in 0..<len {
      @pdfio.bset_unsafe(out, pos, @pdfio.bget_unsafe(bytes, i))
      pos = pos + 1
    }
    @pdfio.bset_unsafe(out, pos, ' ')
    pos = pos + 1
  }
  out
}

///|
fn stream_of_lexemes(oplists : Array[Array[Lexeme]]) -> Array[Byte] raise {
  let sb = StringBuilder()
  let mut prev : String = ""
  for oplist in oplists {
    let text = string_of_lexemes(oplist)
    if !sb.is_empty() {
      let prev_len = prev.length()
      let curr_len = text.length()
      let mut insert = true
      if !always_add_whitespace.val {
        let prev_delim = if prev_len > 0 {
          match string_last_char(prev) {
            Some(chr) => is_delimiter_char(chr)
            None => false
          }
        } else {
          false
        }
        let curr_delim = if curr_len > 0 {
          match string_first_char(text) {
            Some(chr) => is_delimiter_char(chr)
            None => false
          }
        } else {
          false
        }
        if prev_delim || curr_delim {
          insert = false
        }
      }
      if insert {
        sb.write_string(whitespace.val)
      }
    }
    sb.write_string(text)
    prev = text
  }
  @pdfio.bytes_of_string(sb.to_string())
}

///|
/// Flatten a list of operators to an uncompressed PDF stream.
///
/// This produces a `Stream` object suitable for use as page `/Contents` (often
/// after further encoding via `@pdfcodec.PdfCodec::encode_pdfstream`).
pub fn Op::stream_of_ops(ops : Array[Op]) -> @pdf.PdfObject raise {
  let data = stream_of_lexemes(lexemelists_of_ops(ops))
  Stream(
    Ref(
      (Dictionary([("/Length", Integer(@pdfio.bytes_size(data)))]), Got(data)),
    ),
  )
}

///|
fn parse_operator(
  compatibility : Ref[Int],
  lexemes : Array[Lexeme],
  start : Int,
) -> (Op, Int) raise {
  if start >= lexemes.length() {
    return (OpUnknown(""), start)
  }
  match lexemes[start] {
    LexInlineImage(data) => return (InlineImage(data), start + 1)
    _ => ()
  }
  let (section, next_index) = split_lexemes(lexemes, start)
  if section.length() == 0 {
    return (OpUnknown(""), next_index)
  }
  let op_lexeme = section[section.length() - 1]
  match op_lexeme {
    LexInlineImage(data) => return (InlineImage(data), next_index)
    Op(op) => {
      let operand_count = section.length() - 1
      fn as_real(index : Int) -> Double? {
        if index < operand_count {
          lexeme_real(section[index])
        } else {
          None
        }
      }

      fn as_int(index : Int) -> Int? {
        if index < operand_count {
          lexeme_int(section[index])
        } else {
          None
        }
      }

      fn as_name(index : Int) -> String? {
        if index < operand_count {
          lexeme_name(section[index])
        } else {
          None
        }
      }

      fn as_string(index : Int) -> String? {
        if index < operand_count {
          lexeme_string(section[index])
        } else {
          None
        }
      }

      match op {
        "W" => return (OpW, next_index)
        "W*" => return (OpWStar, next_index)
        "q" => return (Opq, next_index)
        "Q" => return (OpQ, next_index)
        "h" => return (Oph, next_index)
        "n" => return (Opn, next_index)
        "f*" => return (OpfStar, next_index)
        "f" => return (Opf, next_index)
        "F" => return (OpF, next_index)
        "BT" => return (OpBT, next_index)
        "ET" => return (OpET, next_index)
        "B" => return (OpB, next_index)
        "B*" => return (OpBStar, next_index)
        "b" => return (Opb, next_index)
        "b*" => return (OpbStar, next_index)
        "S" => return (OpS, next_index)
        "s" => return (Ops, next_index)
        "T*" => return (OpTStar, next_index)
        "BX" => {
          compatibility.val = compatibility.val + 1
          return (OpBX, next_index)
        }
        "EX" => {
          compatibility.val = compatibility.val - 1
          return (OpEX, next_index)
        }
        "Td" =>
          if operand_count == 2 {
            let tx = as_real(0)
            let ty = as_real(1)
            if tx is Some(x) && ty is Some(y) {
              return (OpTd(x, y), next_index)
            }
          }
        "TD" =>
          if operand_count == 2 {
            let tx = as_real(0)
            let ty = as_real(1)
            if tx is Some(x) && ty is Some(y) {
              return (OpTD(x, y), next_index)
            }
          }
        "w" =>
          if operand_count == 1 {
            let w = as_real(0)
            if w is Some(value) {
              return (Opw(value), next_index)
            }
          }
        "J" =>
          if operand_count == 1 {
            let cap = as_int(0)
            if cap is Some(value) {
              return (OpJ(value), next_index)
            }
          }
        "j" =>
          if operand_count == 1 {
            let join = as_int(0)
            if join is Some(value) {
              return (Opj(value), next_index)
            }
          }
        "m" =>
          if operand_count == 2 {
            let x = as_real(0)
            let y = as_real(1)
            if x is Some(xv) && y is Some(yv) {
              return (Opm(xv, yv), next_index)
            }
          }
        "l" =>
          if operand_count == 2 {
            let x = as_real(0)
            let y = as_real(1)
            if x is Some(xv) && y is Some(yv) {
              return (Opl(xv, yv), next_index)
            }
          }
        "TL" =>
          if operand_count == 1 {
            let leading = as_real(0)
            if leading is Some(value) {
              return (OpTL(value), next_index)
            }
          }
        "Tf" =>
          if operand_count == 2 {
            let name = as_name(0)
            let size = as_real(1)
            if name is Some(n) && size is Some(s) {
              return (OpTf(n, s), next_index)
            }
          }
        "Tj" =>
          if operand_count == 1 {
            let text = as_string(0)
            if text is Some(value) {
              return (OpTj(value), next_index)
            }
          }
        "RG" =>
          if operand_count == 3 {
            let r = as_real(0)
            let g = as_real(1)
            let b = as_real(2)
            if r is Some(rv) && g is Some(gv) && b is Some(bv) {
              return (OpRG(rv, gv, bv), next_index)
            }
          }
        "rg" =>
          if operand_count == 3 {
            let r = as_real(0)
            let g = as_real(1)
            let b = as_real(2)
            if r is Some(rv) && g is Some(gv) && b is Some(bv) {
              return (Oprg(rv, gv, bv), next_index)
            }
          }
        "G" =>
          if operand_count == 1 {
            let g = as_real(0)
            if g is Some(value) {
              return (OpG(value), next_index)
            }
          }
        "g" =>
          if operand_count == 1 {
            let g = as_real(0)
            if g is Some(value) {
              return (Opg(value), next_index)
            }
          }
        "k" =>
          if operand_count == 4 {
            let c = as_real(0)
            let m = as_real(1)
            let y = as_real(2)
            let k = as_real(3)
            if c is Some(cv) && m is Some(mv) && y is Some(yv) && k is Some(kv) {
              return (Opk(cv, mv, yv, kv), next_index)
            }
          }
        "K" =>
          if operand_count == 4 {
            let c = as_real(0)
            let m = as_real(1)
            let y = as_real(2)
            let k = as_real(3)
            if c is Some(cv) && m is Some(mv) && y is Some(yv) && k is Some(kv) {
              return (OpK(cv, mv, yv, kv), next_index)
            }
          }
        "cm" =>
          if operand_count == 6 {
            let a = as_real(0)
            let b = as_real(1)
            let c = as_real(2)
            let d = as_real(3)
            let e = as_real(4)
            let f = as_real(5)
            if a is Some(av) &&
              b is Some(bv) &&
              c is Some(cv) &&
              d is Some(dv) &&
              e is Some(ev) &&
              f is Some(fv) {
              return (
                Opcm(TransformMatrix(a=av, b=bv, c=cv, d=dv, e=ev, f=fv)),
                next_index,
              )
            }
          }
        "Tm" =>
          if operand_count == 6 {
            let a = as_real(0)
            let b = as_real(1)
            let c = as_real(2)
            let d = as_real(3)
            let e = as_real(4)
            let f = as_real(5)
            if a is Some(av) &&
              b is Some(bv) &&
              c is Some(cv) &&
              d is Some(dv) &&
              e is Some(ev) &&
              f is Some(fv) {
              return (
                OpTm(TransformMatrix(a=av, b=bv, c=cv, d=dv, e=ev, f=fv)),
                next_index,
              )
            }
          }
        "MP" =>
          if operand_count == 1 {
            let name = as_name(0)
            if name is Some(value) {
              return (OpMP(value), next_index)
            }
          }
        "DP" =>
          if operand_count == 2 {
            let name = as_name(0)
            if name is Some(value) {
              let obj = lexeme_pdfobj(section[1])
              if obj is Some(props) {
                return (OpDP(value, props), next_index)
              }
            }
          }
        "BMC" =>
          if operand_count == 1 {
            let name = as_name(0)
            if name is Some(value) {
              return (OpBMC(value), next_index)
            }
          }
        "BDC" =>
          if operand_count == 2 {
            let name = as_name(0)
            if name is Some(value) {
              let obj = lexeme_pdfobj(section[1])
              if obj is Some(props) {
                return (OpBDC(value, props), next_index)
              }
            }
          }
        "EMC" => return (OpEMC, next_index)
        "gs" =>
          if operand_count == 1 {
            let name = as_name(0)
            if name is Some(value) {
              return (Opgs(value), next_index)
            }
          }
        "Do" =>
          if operand_count == 1 {
            let name = as_name(0)
            if name is Some(value) {
              return (OpDo(value), next_index)
            }
          }
        "CS" =>
          if operand_count == 1 {
            let name = as_name(0)
            if name is Some(value) {
              return (OpCS(value), next_index)
            }
          }
        "cs" =>
          if operand_count == 1 {
            let name = as_name(0)
            if name is Some(value) {
              return (Opcs(value), next_index)
            }
          }
        "c" =>
          if operand_count == 6 {
            let x1 = as_real(0)
            let y1 = as_real(1)
            let x2 = as_real(2)
            let y2 = as_real(3)
            let x3 = as_real(4)
            let y3 = as_real(5)
            if x1 is Some(x1v) &&
              y1 is Some(y1v) &&
              x2 is Some(x2v) &&
              y2 is Some(y2v) &&
              x3 is Some(x3v) &&
              y3 is Some(y3v) {
              return (Opc(x1v, y1v, x2v, y2v, x3v, y3v), next_index)
            }
          }
        "v" =>
          if operand_count == 4 {
            let x2 = as_real(0)
            let y2 = as_real(1)
            let x3 = as_real(2)
            let y3 = as_real(3)
            if x2 is Some(x2v) &&
              y2 is Some(y2v) &&
              x3 is Some(x3v) &&
              y3 is Some(y3v) {
              return (Opv(x2v, y2v, x3v, y3v), next_index)
            }
          }
        "y" =>
          if operand_count == 4 {
            let x1 = as_real(0)
            let y1 = as_real(1)
            let x3 = as_real(2)
            let y3 = as_real(3)
            if x1 is Some(x1v) &&
              y1 is Some(y1v) &&
              x3 is Some(x3v) &&
              y3 is Some(y3v) {
              return (Opy(x1v, y1v, x3v, y3v), next_index)
            }
          }
        "re" =>
          if operand_count == 4 {
            let x = as_real(0)
            let y = as_real(1)
            let w = as_real(2)
            let h = as_real(3)
            if x is Some(xv) && y is Some(yv) && w is Some(wv) && h is Some(hv) {
              return (Opre(xv, yv, wv, hv), next_index)
            }
          }
        "ri" =>
          if operand_count == 1 {
            let name = as_name(0)
            if name is Some(value) {
              return (Opri(value), next_index)
            }
          }
        "i" =>
          if operand_count == 1 {
            let value = as_int(0)
            if value is Some(v) {
              return (Opi(v), next_index)
            }
          }
        "M" =>
          if operand_count == 1 {
            let value = as_real(0)
            if value is Some(v) {
              return (OpM(v), next_index)
            }
          }
        "'" =>
          if operand_count == 1 {
            let text = as_string(0)
            if text is Some(value) {
              return (OpSingleQuote(value), next_index)
            }
          }
        "\"" =>
          if operand_count == 3 {
            let aw = as_real(0)
            let ac = as_real(1)
            let text = as_string(2)
            if aw is Some(awp) && ac is Some(acp) && text is Some(txt) {
              return (OpDoubleQuote(awp, acp, txt), next_index)
            }
          }
        "d0" =>
          if operand_count == 2 {
            let wx = as_real(0)
            let wy = as_real(1)
            if wx is Some(wxv) && wy is Some(wyv) {
              return (Opd0(wxv, wyv), next_index)
            }
          }
        "d1" =>
          if operand_count == 6 {
            let wx = as_real(0)
            let wy = as_real(1)
            let llx = as_real(2)
            let lly = as_real(3)
            let urx = as_real(4)
            let ury = as_real(5)
            if wx is Some(wxv) &&
              wy is Some(wyv) &&
              llx is Some(llxv) &&
              lly is Some(llyv) &&
              urx is Some(urxv) &&
              ury is Some(uryv) {
              return (Opd1(wxv, wyv, llxv, llyv, urxv, uryv), next_index)
            }
          }
        "sh" =>
          if operand_count == 1 {
            let name = as_name(0)
            if name is Some(value) {
              return (Opsh(value), next_index)
            }
          }
        "Tc" =>
          if operand_count == 1 {
            let value = as_real(0)
            if value is Some(v) {
              return (OpTc(v), next_index)
            }
          }
        "Tw" =>
          if operand_count == 1 {
            let value = as_real(0)
            if value is Some(v) {
              return (OpTw(v), next_index)
            }
          }
        "Tz" =>
          if operand_count == 1 {
            let value = as_real(0)
            if value is Some(v) {
              return (OpTz(v), next_index)
            }
          }
        "Tr" =>
          if operand_count == 1 {
            let value = as_real(0)
            if value is Some(v) {
              return (OpTr(v.to_int()), next_index)
            }
          }
        "Ts" =>
          if operand_count == 1 {
            let value = as_real(0)
            if value is Some(v) {
              return (OpTs(v), next_index)
            }
          }
        "sc" =>
          return (
            Opsc(reals_of_lexemes(section[0:operand_count], "Malformed 'sc'")),
            next_index,
          )
        "SC" =>
          return (
            OpSC(reals_of_lexemes(section[0:operand_count], "Malformed 'SC'")),
            next_index,
          )
        "scn" =>
          if operand_count > 0 {
            match lexeme_name(section[operand_count - 1]) {
              Some(name) => {
                let values = reals_of_lexemes(
                  section[0:operand_count - 1],
                  "scn",
                )
                return (OpscnName(name, values), next_index)
              }
              None => {
                let values = reals_of_lexemes(
                  section[0:operand_count],
                  "Malformed 'scn'",
                )
                return (Opscn(values), next_index)
              }
            }
          }
        "SCN" =>
          if operand_count > 0 {
            match lexeme_name(section[operand_count - 1]) {
              Some(name) => {
                let values = reals_of_lexemes(
                  section[0:operand_count - 1],
                  "SCN",
                )
                return (OpSCNName(name, values), next_index)
              }
              None => {
                let values = reals_of_lexemes(
                  section[0:operand_count],
                  "Malformed 'SCN'",
                )
                return (OpSCN(values), next_index)
              }
            }
          }
        "d" => return (parse_dash_op(section), next_index)
        "TJ" => return (parse_tj_op(section), next_index)
        _ => ()
      }
      @pdfe.log(
        "Empty or malformed graphics operation \{string_of_lexemes(section)}.\n",
      )
      (OpUnknown(string_of_lexemes(section)), next_index)
    }
    _ => {
      @pdfe.log(
        "Empty or malformed graphics operation \{string_of_lexemes(section)}.\n",
      )
      (OpUnknown(string_of_lexemes(section)), next_index)
    }
  }
}

///|
/// Parse a list of byte streams to an operator list.
///
/// If `streams` contains multiple byte arrays, they are concatenated with
/// whitespace (like many real PDFs where `/Contents` is an array of streams).
pub fn Op::parse_stream(
  pdf : @pdf.Pdf,
  resources : @pdf.PdfObject,
  streams : Array[Array[Byte]],
) -> Array[Op] raise {
  let stream = if streams.length() == 1 {
    streams[0]
  } else {
    Op::concat_bytess(streams)
  }
  Op::parse_single_stream(pdf, resources, stream)
}
