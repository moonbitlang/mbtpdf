///|
fn encoding_string(pdf : @pdf.Pdf, font : @pdf.PdfObject) -> String raise {
  @pdftext.PdfText::new(pdf).read_encoding(font).to_string()
}

///|
test "string_of_standard_font covers all names" {
  let cases : Array[(String, String)] = [
    ("/Times-Roman", "Times-Roman"),
    ("/Times-Bold", "Times-Bold"),
    ("/Times-Italic", "Times-Italic"),
    ("/Times-BoldItalic", "Times-BoldItalic"),
    ("/Helvetica", "Helvetica"),
    ("/Helvetica-Bold", "Helvetica-Bold"),
    ("/Helvetica-Oblique", "Helvetica-Oblique"),
    ("/Helvetica-BoldOblique", "Helvetica-BoldOblique"),
    ("/Courier", "Courier"),
    ("/Courier-Bold", "Courier-Bold"),
    ("/Courier-Oblique", "Courier-Oblique"),
    ("/Courier-BoldOblique", "Courier-BoldOblique"),
    ("/Symbol", "Symbol"),
    ("/ZapfDingbats", "ZapfDingbats"),
  ]
  for pair in cases {
    let name = pair.0
    let expected = pair.1
    match @pdftext.PdfTextUtil::new().standard_font_of_name(name) {
      Some(font) => assert_eq(font.to_string(), expected)
      None => fail("expected standard font")
    }
  }
}

///|
test "string_of_fonttype covers variants" {
  let pdf = @pdf.Pdf::empty()
  let ctx = @pdftext.PdfText::new(pdf)
  let dummy : @pdf.PdfObject = Dictionary([])
  match ctx.simple_fonttype_of_string(dummy, "/Type1") {
    Some(ft) => assert_eq(ft.to_string(), "Type 1")
    None => fail("expected Type1")
  }
  match ctx.simple_fonttype_of_string(dummy, "/MMType1") {
    Some(ft) => assert_eq(ft.to_string(), "MM Type 1")
    None => fail("expected MMType1")
  }
  match ctx.simple_fonttype_of_string(dummy, "/TrueType") {
    Some(ft) => assert_eq(ft.to_string(), "Truetype")
    None => fail("expected Truetype")
  }
  let type3_font : @pdf.PdfObject = Dictionary([
    ("/FontBBox", PdfArray([Real(0.0), Real(0.0), Real(10.0), Real(10.0)])),
    (
      "/FontMatrix",
      PdfArray([
        Real(1.0),
        Real(0.0),
        Real(0.0),
        Real(1.0),
        Real(0.0),
        Real(0.0),
      ]),
    ),
    ("/CharProcs", Dictionary([("/A", Null)])),
  ])
  match ctx.simple_fonttype_of_string(type3_font, "/Type3") {
    Some(ft) => assert_eq(ft.to_string(), "Type 3: charprocs for/A")
    None => fail("expected Type3")
  }
}

///|
test "string_of_encoding covers variants" {
  let pdf = @pdf.Pdf::empty()
  let implicit_font : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(PdfName(b"/Type1"))),
  ])
  assert_eq(encoding_string(pdf, implicit_font), "ImplicitInFontFile")
  let mac_font : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(PdfName(b"/Type1"))),
    ("/Encoding", Name(PdfName(b"/MacRomanEncoding"))),
  ])
  assert_eq(encoding_string(pdf, mac_font), "MacRomanEncoding")
  let expert_font : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(PdfName(b"/Type1"))),
    ("/Encoding", Name(PdfName(b"/MacExpertEncoding"))),
  ])
  assert_eq(encoding_string(pdf, expert_font), "MacExpertEncoding")
  let ansi_font : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(PdfName(b"/Type1"))),
    ("/Encoding", Name(PdfName(b"/WinAnsiEncoding"))),
  ])
  assert_eq(encoding_string(pdf, ansi_font), "WinAnsiEncoding")
  let standard_font : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(PdfName(b"/Type1"))),
    ("/Encoding", Dictionary([])),
  ])
  assert_eq(encoding_string(pdf, standard_font), "StandardEncoding")
  let custom_font : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(PdfName(b"/Type1"))),
    (
      "/Encoding",
      Dictionary([
        ("/BaseEncoding", Name(PdfName(b"/WinAnsiEncoding"))),
        ("/Differences", PdfArray([Integer(65), Name(PdfName(b"/A"))])),
      ]),
    ),
  ])
  assert_eq(
    encoding_string(pdf, custom_font),
    "CustomEncoding with base WinAnsiEncoding and differences 65 -> /A, ",
  )
  let fill_font : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(PdfName(b"/TrueType"))),
    (
      "/Encoding",
      Dictionary([("/BaseEncoding", Name(PdfName(b"/WinAnsiEncoding")))]),
    ),
  ])
  assert_eq(
    encoding_string(pdf, fill_font),
    "FillUndefinedWithStandard WinAnsiEncoding",
  )
}

///|
test "string_of_simple_font formats details" {
  let pdf = @pdf.Pdf::empty()
  let ctx = @pdftext.PdfText::new(pdf)
  let font : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(PdfName(b"/Type1"))),
    ("/BaseFont", Name(PdfName(b"/Helvetica"))),
    ("/FirstChar", Integer(65)),
    ("/LastChar", Integer(65)),
    ("/Widths", PdfArray([Integer(500)])),
    (
      "/Encoding",
      Dictionary([
        ("/BaseEncoding", Name(PdfName(b"/WinAnsiEncoding"))),
        ("/Differences", PdfArray([Integer(65), Name(PdfName(b"/A"))])),
      ]),
    ),
  ])
  let simple = match (ctx.read_simple_font(font) : @pdffont.Font) {
    SimpleFont(value) => value
    _ => fail("expected simple font")
  }
  let rendered = simple.to_string()
  assert_true(rendered.contains("fonttype = Type 1"))
  assert_true(rendered.contains("basefont /Helvetica"))
  assert_true(rendered.contains("CustomEncoding"))
}

///|
test "string_of_font covers variants" {
  let pdf = @pdf.Pdf::empty()
  let ctx = @pdftext.PdfText::new(pdf)
  let standard_font : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(PdfName(b"/Type1"))),
    ("/BaseFont", Name(PdfName(b"/Helvetica"))),
  ])
  let standard = ctx.read_standard14font(standard_font)
  assert_eq(standard.to_string(), "StandardFont Helvetica")
  let simple_font : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(PdfName(b"/Type1"))),
    ("/BaseFont", Name(PdfName(b"/Helvetica"))),
    ("/FirstChar", Integer(65)),
    ("/LastChar", Integer(65)),
    ("/Widths", PdfArray([Integer(500)])),
  ])
  let simple = ctx.read_simple_font(simple_font)
  assert_true(simple.to_string().contains("SimpleFont fonttype"))
  let descendant : @pdf.PdfObject = Dictionary([
    (
      "/CIDSystemInfo",
      Dictionary([
        ("/Registry", PdfString("Adobe")),
        ("/Ordering", PdfString("Identity")),
        ("/Supplement", Integer(0)),
      ]),
    ),
    ("/BaseFont", Name(PdfName(b"/CIDFont"))),
    ("/FontDescriptor", Dictionary([])),
  ])
  let cid_font : @pdf.PdfObject = Dictionary([
    ("/BaseFont", Name(PdfName(b"/CIDFontType0"))),
    ("/DescendantFonts", PdfArray([descendant])),
    ("/Encoding", Name(PdfName(b"/Identity-H"))),
  ])
  let cid = ctx.read_cidkeyed_font(cid_font)
  assert_eq(cid.to_string(), "CIDKeyedFont /CIDFontType0")
}
