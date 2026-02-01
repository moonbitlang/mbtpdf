///|
/// Font writing helpers.

///|
type PdfObject = @pdf.PdfObject

///|
pub fn PdfTextUtil::make_font(
  _self : PdfTextUtil,
  fontname : String,
  encoding : @pdffont.Encoding,
) -> @pdf.PdfObject {
  @pdf.PdfObject::Dictionary([
    (@pdf.n("/Type"), Name(PdfName("/Font"))),
    (@pdf.n("/Subtype"), Name(PdfName("/Type1"))),
    (
      @pdf.n("/Encoding"),
      Name(@pdf.PdfName::of_string("/" + encoding.to_string())),
    ),
    (@pdf.n("/BaseFont"), Name(@pdf.PdfName::of_string("/" + fontname))),
  ])
}

///|
pub fn PdfText::write_encoding(
  self : PdfText,
  encoding : @pdffont.Encoding,
) -> Int raise {
  fn encoding_name(enc : @pdffont.Encoding) -> String? {
    match enc {
      StandardEncoding => Some("/StandardEncoding")
      MacRomanEncoding => Some("/MacRomanEncoding")
      WinAnsiEncoding => Some("/WinAnsiEncoding")
      MacExpertEncoding => Some("/MacExpertEncoding")
      CustomEncoding(inner, _) => encoding_name(inner)
      FillUndefinedWithStandard(inner) => encoding_name(inner)
      ImplicitInFontFile => None
    }
  }

  match encoding {
    StandardEncoding | MacRomanEncoding | WinAnsiEncoding | MacExpertEncoding => {
      let name = match encoding_name(encoding) {
        Some(value) => value
        None => raise @pdf.PdfError::Msg("write_encoding: missing name")
      }
      self.pdf.addobj(Name(@pdf.PdfName::of_string(name)))
    }
    FillUndefinedWithStandard(inner) => self.write_encoding(inner)
    CustomEncoding(base, diffs) => {
      let diff_array = Array::new()
      for diff in diffs {
        diff_array.push(PdfObject::Integer(diff.1))
        diff_array.push(Name(@pdf.PdfName::of_string(diff.0)))
      }
      let mut encoding_dict = @pdf.PdfObject::Dictionary([
        (@pdf.n("/Type"), Name(PdfName("/Encoding"))),
        (@pdf.n("/Differences"), Array(diff_array)),
      ])
      match encoding_name(base) {
        Some(name) =>
          encoding_dict = encoding_dict.add_entry(
            "/BaseEncoding",
            Name(@pdf.PdfName::of_string(name)),
          )
        None => ()
      }
      self.pdf.addobj(encoding_dict)
    }
    ImplicitInFontFile =>
      raise @pdf.PdfError::Msg("write_encoding: implicit encoding")
  }
}

///|
let tounicode_preamble : String =
  #|/CIDInit /ProcSet findresource begin
  #|12 dict begin
  #|begincmap
  #|/CIDSystemInfo <<
  #|  /Registry (Adobe)
  #|  /Ordering (UCS)
  #|  /Supplement 0
  #|>> def
  #|/CMapName /Adobe-Identity-UCS def
  #|/CMapType 2 def
  #|1 begincodespacerange
  #|<00><FF>
  #|endcodespacerange
  #|

///|
let tounicode_postamble : String =
  #|endbfrange
  #|endcmap
  #|CMapName currentdict /CMap defineresource pop
  #|end
  #|end
  #|

///|
let hex_digits_upper : Array[Char] = "0123456789ABCDEF".to_array()

///|
let hex_digits_lower : Array[Char] = "0123456789abcdef".to_array()

///|
fn hex_byte(digits : Array[Char], value : Int) -> String {
  let hi = value / 16
  let lo = value % 16
  String::from_array([digits[hi], digits[lo]])
}

///|
fn hex_byte_upper(value : Int) -> String {
  hex_byte(hex_digits_upper, value)
}

///|
fn hex_byte_lower(value : Int) -> String {
  hex_byte(hex_digits_lower, value)
}

///|
pub fn PdfTextUtil::hex(_self : PdfTextUtil, u : String) -> String {
  let sb = StringBuilder::new()
  let bytes = @pdfio.bytes_of_string(u)
  for b in bytes {
    sb.write_string(hex_byte_upper(b.to_int()))
  }
  sb.to_string()
}

///|
pub fn PdfTextUtil::tounicode_map(
  self : PdfTextUtil,
  start_code : Int,
  us : Array[String],
) -> Array[Byte] {
  let sb = StringBuilder::new()
  let mut code = start_code
  sb
  ..write_string(tounicode_preamble)
  ..write_string("\{us.length()} beginbfrange\n")
  for u in us {
    sb.write_string(
      "<\{hex_byte_lower(code)}><\{hex_byte_lower(code)}><\{self.hex(u)}>\n",
    )
    code = code + 1
  }
  sb.write_string(tounicode_postamble)
  @pdfio.bytes_of_string(sb.to_string())
}

///|
pub fn PdfText::write_tounicode(self : PdfText, u : Map[Int, String]) -> Int {
  let pairs = @pdfutil.PdfUtil::new().list_of_hashtbl(u)
  pairs.sort_by((a, b) => a.0 - b.0)
  let strings = pairs.map(pair => pair.1)
  let bytes = PdfTextUtil::new().tounicode_map(33, strings)
  let dict = @pdf.PdfObject::Dictionary([
    (@pdf.n("/Length"), Integer(@pdfio.bytes_size(bytes))),
  ])
  self.pdf.addobj(Stream(Ref::new((dict, Got(bytes)))))
}

///|
pub fn PdfText::write_font(
  self : PdfText,
  objnum? : Int,
  font : @pdffont.Font,
) -> Int raise {
  match font {
    SimpleFont(simple) =>
      match simple.fonttype {
        Type3(type3) =>
          match simple.fontdescriptor {
            Some(_) => {
              let encoding_entry = match simple.encoding {
                ImplicitInFontFile => []
                _ =>
                  [
                    (
                      @pdf.n("/Encoding"),
                      PdfObject::Indirect(self.write_encoding(simple.encoding)),
                    ),
                  ]
              }
              let dict = @pdf.PdfObject::Dictionary(
                [
                  (@pdf.n("/Type"), PdfObject::Name(PdfName("/Font"))),
                  (@pdf.n("/Subtype"), Name(PdfName("/Type3"))),
                  (
                    @pdf.n("/FontBBox"),
                    Array([Real(0.0), Real(0.0), Real(0.0), Real(0.0)]),
                  ),
                  (
                    @pdf.n("/FontMatrix"),
                    Array([
                      Real(0.0),
                      Real(0.0),
                      Real(0.0),
                      Real(0.0),
                      Real(0.0),
                      Real(0.0),
                    ]),
                  ),
                  (
                    @pdf.n("/CharProcs"),
                    @pdf.PdfObject::Dictionary(
                      type3.charprocs.map(pair => (
                        @pdf.PdfName::of_string(pair.0),
                        Null,
                      )),
                    ),
                  ),
                  (@pdf.n("/FirstChar"), Integer(0)),
                  (@pdf.n("/LastChar"), Integer(0)),
                  (@pdf.n("/Widths"), Array([Real(0.0)])),
                ].add(encoding_entry),
              )
              self.pdf.addobj(dict)
            }
            None => raise @pdf.PdfError::Msg("Missing font descriptor")
          }
        Truetype =>
          match simple.fontdescriptor {
            Some(fd) =>
              match fd.fontfile {
                Some(FontFile2(ttf)) => {
                  let (minx, miny, maxx, maxy) = fd.fontbbox
                  let fontdesc = @pdf.PdfObject::Dictionary([
                    (@pdf.n("/Type"), Name(PdfName("/FontDescriptor"))),
                    (
                      @pdf.n("/FontName"),
                      Name(@pdf.PdfName::of_string(simple.basefont)),
                    ),
                    (@pdf.n("/Flags"), Integer(fd.flags)),
                    (
                      @pdf.n("/FontBBox"),
                      Array([
                        Integer(minx.to_int()),
                        Integer(miny.to_int()),
                        Integer(maxx.to_int()),
                        Integer(maxy.to_int()),
                      ]),
                    ),
                    (@pdf.n("/ItalicAngle"), Integer(fd.italicangle.to_int())),
                    (@pdf.n("/Ascent"), Integer(fd.ascent.to_int())),
                    (@pdf.n("/Descent"), Integer(fd.descent.to_int())),
                    (@pdf.n("/CapHeight"), Integer(fd.capheight.to_int())),
                    (@pdf.n("/StemV"), Integer(fd.stemv.to_int())),
                    (@pdf.n("/XHeight"), Integer(fd.xheight.to_int())),
                    (@pdf.n("/AvgWidth"), Integer(fd.avgwidth.to_int())),
                    (@pdf.n("/MaxWidth"), Integer(fd.maxwidth.to_int())),
                    (@pdf.n("/FontFile2"), Indirect(ttf)),
                  ])
                  let fontdesc_num = self.pdf.addobj(fontdesc)
                  let mut font_dict_entries : Array[
                    (@pdf.PdfName, @pdf.PdfObject),
                  ] = [
                    (@pdf.n("/Type"), Name(PdfName("/Font"))),
                    (@pdf.n("/Subtype"), Name(PdfName("/TrueType"))),
                    (
                      @pdf.n("/BaseFont"),
                      Name(@pdf.PdfName::of_string(simple.basefont)),
                    ),
                    (@pdf.n("/FontDescriptor"), Indirect(fontdesc_num)),
                    (@pdf.n("/FirstChar"), Integer(simple.firstchar)),
                    (@pdf.n("/LastChar"), Integer(simple.lastchar)),
                    (
                      @pdf.n("/Widths"),
                      Array(simple.widths.map(w => Integer(w))),
                    ),
                  ]
                  font_dict_entries = match fd.tounicode {
                    None =>
                      font_dict_entries.add([
                        (
                          @pdf.n("/Encoding"),
                          Name(
                            @pdf.PdfName::of_string(
                              "/" + simple.encoding.to_string(),
                            ),
                          ),
                        ),
                      ])
                    Some(u) =>
                      font_dict_entries.add([
                        (
                          @pdf.n("/ToUnicode"),
                          Indirect(self.write_tounicode(u)),
                        ),
                      ])
                  }
                  let font_obj = @pdf.PdfObject::Dictionary(font_dict_entries)
                  match objnum {
                    None => self.pdf.addobj(font_obj)
                    Some(o) => {
                      self.pdf.addobj_given_num((o, font_obj))
                      o
                    }
                  }
                }
                _ => raise @pdf.PdfError::Msg("Missing FontFile2")
              }
            None => raise @pdf.PdfError::Msg("Missing font descriptor")
          }
        _ =>
          raise @pdf.PdfError::Msg(
            "Pdftext.write_font does not support this font",
          )
      }
    StandardFont(standard, encoding) =>
      self.pdf.addobj(
        PdfTextUtil::new().make_font(standard.to_string(), encoding),
      )
    _ =>
      raise @pdf.PdfError::Msg("Pdftext.write_font does not support this font")
  }
}
