///|
fn filterspecial(filters : Array[@pdf.PdfObject]) -> Bool {
  filters.any(filter => {
    match filter {
      Name(name) =>
        name is PdfName("/ASCIIHexDecode" | "/ASCII85Decode" | "/AHx" | "/A85")
      _ => false
    }
  })
}

///|
fn is_inline_image_whitespace(chr : Char) -> Bool {
  match chr.to_int() {
    0 | 9 | 10 | 12 | 13 | 32 => true
    _ => false
  }
}

///|
fn is_inline_image_delimiter(chr : Char) -> Bool {
  is_inline_image_whitespace(chr) || is_delimiter_char(chr)
}

///|
fn inline_image_end_ahead(input : @pdfio.Input) -> Bool {
  let pos = (input.pos_in)()
  let b1 = (input.input_byte)()
  let b2 = (input.input_byte)()
  let b3 = (input.input_byte)()
  (input.seek_in)(pos)
  if b1 == @pdfio.no_more || b2 == @pdfio.no_more {
    return false
  }
  if b1 != 'E' || b2 != 'I' {
    return false
  }
  if b3 == @pdfio.no_more {
    return true
  }
  match b3.to_char() {
    Some(ch) => is_inline_image_delimiter(ch)
    None => false
  }
}

///|
fn read_inline_image_encoded_data(input : @pdfio.Input) -> Array[Byte] raise {
  let (output, data) = @pdfio.Output::of_bytes(4096)
  let mut done = false
  while !done {
    let pos = (input.pos_in)()
    let b = (input.input_byte)()
    if b == @pdfio.no_more {
      raise @pdf.PdfError::Msg(
        "Could not read inline image data - end of stream",
      )
    }
    match b.to_char() {
      Some(ch) if is_inline_image_whitespace(ch) =>
        if inline_image_end_ahead(input) {
          (input.seek_in)(pos)
          done = true
        } else {
          (output.output_byte)(b)
        }
      _ => (output.output_byte)(b)
    }
  }
  output.extract_bytes(data)
}

///|
fn get_jpeg_data(input : @pdfio.Input) -> Array[Byte] raise {
  let (output, data) = @pdfio.Output::of_bytes(4096)
  let mut finished = false
  let mut last = 0
  while !finished {
    let b = (input.input_byte)()
    if b == @pdfio.no_more {
      raise @pdf.PdfError::Msg("Could not read JPEG data - end of stream")
    }
    if b == 0xD9 {
      if last == 0xFF {
        finished = true
      } else {
        last = 0xD9
      }
      (output.output_byte)(0xD9)
    } else {
      last = b
      (output.output_byte)(b)
    }
  }
  output.extract_bytes(data)
}

///|
fn lex_inline_image(
  pdf : @pdf.Pdf,
  resources : @pdf.PdfObject,
  input : @pdfio.Input,
) -> (@pdf.PdfObject, @pdf.PdfObject?, Array[Byte]) raise {
  @pdfe.debug("lex_inline_image at \{(input.pos_in)()}\n")
  try {
    let lexemes = @pdfsyntax.lex_dictionary(true, input)
    let tokens : Array[Token] = Array::new(capacity=lexemes.length() + 2)
    tokens.push(LexLeftDict)
    for token in lexemes {
      match token {
        StopLexing => ()
        _ => tokens.push(token)
      }
    }
    tokens.push(LexRightDict)
    let dict = @pdfsyntax.parse(tokens).1
    @pdfe.debug("dict was \{dict.to_string()}\n")
    input.dropwhite()
    let c = (input.input_byte)()
    let c2 = (input.input_byte)()
    if c != 'I' || c2 != 'D' {
      @pdfe.debug("Did not recognise beginning of inline image ID\n")
      nocontent(input)
    }
    let filters = match pdf.lookup_direct_orelse("/F", "/Filter", dict) {
      Some(PdfArray(items)) => items
      Some(Name(name)) => [Name(name)]
      _ => []
    }
    let toskip = !filterspecial(filters)
    if toskip {
      ignore((input.input_byte)())
    }
    @pdfe.debug("**got ID header, skipped possible byte\n")
    let bpc = match
      pdf.lookup_direct_orelse("/BPC", "/BitsPerComponent", dict) {
      Some(Integer(value)) => value
      _ => {
        @pdfe.debug("no BPC\n")
        nocontent(input)
        0
      }
    }
    let cspace = match pdf.lookup_direct_orelse("/CS", "/ColorSpace", dict) {
      Some(Name(name)) =>
        if name
          is PdfName(
            "/DeviceGray"
            | "/DeviceRGB"
            | "/DeviceCMYK"
            | "/G"
            | "/RGB"
            | "/CMYK"
          ) {
          PdfObject::Name(name)
        } else {
          @pdfe.debug("resources is \{resources.to_string()}\n")
          match pdf.lookup_direct("/ColorSpace", resources) {
            Some(Dictionary(_) as d) =>
              match pdf.lookup_direct(name.to_string_bytes(), d) {
                Some(space) => space
                None => {
                  @pdfe.debug("no colourspace A\n")
                  nocontent(input)
                  Null
                }
              }
            _ => {
              @pdfe.debug("no colourspace B\n")
              nocontent(input)
              Null
            }
          }
        }
      Some(PdfArray(_) as n) => n
      None =>
        match pdf.lookup_direct_orelse("/IM", "/ImageMask", dict) {
          Some(Boolean(true)) => Name(PdfName("/DeviceGray"))
          _ => {
            @pdfe.debug("no colourspace C\n")
            nocontent(input)
            Null
          }
        }
      _ => {
        @pdfe.debug("no colourspace D\n")
        nocontent(input)
        Null
      }
    }
    let width = match pdf.lookup_direct_orelse("/W", "/Width", dict) {
      Some(Integer(value)) => value
      _ => {
        @pdfe.debug("no or malformed /W")
        nocontent(input)
        0
      }
    }
    let height = match pdf.lookup_direct_orelse("/H", "/Height", dict) {
      Some(Integer(value)) => value
      _ => {
        @pdfe.debug("no or malformed /H")
        nocontent(input)
        0
      }
    }
    let bitwidth = Op::components(pdf, resources, cspace) * bpc * width
    let bytewidth = if bitwidth % 8 == 0 {
      bitwidth / 8
    } else {
      bitwidth / 8 + 1
    }
    let bytes = bytewidth * height
    let filter_opt = @pdf.Pdf::empty().lookup_direct_orelse(
      "/F", "/Filter", dict,
    )
    let data = match filter_opt {
      None | Some(PdfArray([])) => {
        let out = @pdfio.mkbytes(bytes)
        for i in 0..<bytes {
          @pdfio.bset_unsafe(out, i, (input.input_byte)())
        }
        out
      }
      Some(Name(name)) =>
        if name is PdfName("/DCT" | "/DCTDecode") {
          get_jpeg_data(input)
        } else {
          let encoded = read_inline_image_encoded_data(input)
          match @pdfcodec.PdfCodec::new().decode_from_bytes(encoded, dict) {
            Some(decoded) => decoded
            None => {
              @pdfe.debug("decode_from_bytes failed\n")
              nocontent(input)
              @pdfio.mkbytes(0)
            }
          }
        }
      Some(PdfArray(items)) =>
        if items.length() == 1 {
          match items[0] {
            Name(name) =>
              if name is PdfName("/DCT" | "/DCTDecode") {
                get_jpeg_data(input)
              } else {
                let encoded = read_inline_image_encoded_data(input)
                match
                  @pdfcodec.PdfCodec::new().decode_from_bytes(encoded, dict) {
                  Some(decoded) => decoded
                  None => {
                    @pdfe.debug("decode_from_bytes failed\n")
                    nocontent(input)
                    @pdfio.mkbytes(0)
                  }
                }
              }
            _ => {
              let encoded = read_inline_image_encoded_data(input)
              match @pdfcodec.PdfCodec::new().decode_from_bytes(encoded, dict) {
                Some(decoded) => decoded
                None => {
                  @pdfe.debug("decode_from_bytes failed\n")
                  nocontent(input)
                  @pdfio.mkbytes(0)
                }
              }
            }
          }
        } else {
          let encoded = read_inline_image_encoded_data(input)
          match @pdfcodec.PdfCodec::new().decode_from_bytes(encoded, dict) {
            Some(decoded) => decoded
            None => {
              @pdfe.debug("decode_from_bytes failed\n")
              nocontent(input)
              @pdfio.mkbytes(0)
            }
          }
        }
      Some(_) => {
        let encoded = read_inline_image_encoded_data(input)
        match @pdfcodec.PdfCodec::new().decode_from_bytes(encoded, dict) {
          Some(decoded) => decoded
          None => {
            @pdfe.debug("decode_from_bytes failed\n")
            nocontent(input)
            @pdfio.mkbytes(0)
          }
        }
      }
    }
    input.dropwhite()
    let end1 = (input.input_byte)()
    let end2 = (input.input_byte)()
    if end1 != 'E' || end2 != 'I' {
      @pdfe.warn("warning: bad end to inline image \{end1}, \{end2}")
      input.ignoreuntil(true, chr => chr == 'E')
      input.ignoreuntil(true, chr => chr == 'I')
      input.nudge()
      input.dropwhite()
    }
    let dict_clean = match filter_opt {
      Some(Name(name)) =>
        if name is PdfName("/DCT" | "/DCTDecode") {
          dict
        } else {
          let mut cleaned = dict
          for key in ["/Filter", "/F", "/DecodeParms", "/DP"] {
            cleaned = cleaned.remove_entry(key)
          }
          cleaned
        }
      Some(PdfArray(items)) =>
        if items.length() == 1 {
          match items[0] {
            Name(name) =>
              if name is PdfName("/DCT" | "/DCTDecode") {
                dict
              } else {
                let mut cleaned = dict
                for key in ["/Filter", "/F", "/DecodeParms", "/DP"] {
                  cleaned = cleaned.remove_entry(key)
                }
                cleaned
              }
            _ => {
              let mut cleaned = dict
              for key in ["/Filter", "/F", "/DecodeParms", "/DP"] {
                cleaned = cleaned.remove_entry(key)
              }
              cleaned
            }
          }
        } else {
          let mut cleaned = dict
          for key in ["/Filter", "/F", "/DecodeParms", "/DP"] {
            cleaned = cleaned.remove_entry(key)
          }
          cleaned
        }
      _ => {
        let mut cleaned = dict
        for key in ["/Filter", "/F", "/DecodeParms", "/DP"] {
          cleaned = cleaned.remove_entry(key)
        }
        cleaned
      }
    }
    let dp = @pdf.Pdf::empty().lookup_direct_orelse("/DP", "/DecodeParms", dict)
    (dict_clean, dp, data)
  } catch {
    err => {
      @pdfe.debug("inline image reading failed: \{err}\n")
      nocontent(input)
      (Null, None, @pdfio.mkbytes(0))
    }
  }
}

///|
fn lex_keyword(
  pdf : @pdf.Pdf,
  resources : @pdf.PdfObject,
  input : @pdfio.Input,
) -> Lexeme raise {
  match input.getuntil_white_or_delimiter_string() {
    "true" => Obj(LexBool(true))
    "false" => Obj(LexBool(false))
    "BI" => LexInlineImage(lex_inline_image(pdf, resources, input))
    "ID" | "EI" | "" => {
      nocontent(input)
      Op("")
    }
    opstring => Op(opstring)
  }
}
