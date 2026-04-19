///|
fn all_standard_fonts() -> Array[@pdffont.StandardFont] {
  [
    TimesRoman,
    TimesBold,
    TimesItalic,
    TimesBoldItalic,
    Helvetica,
    HelveticaBold,
    HelveticaOblique,
    HelveticaBoldOblique,
    Courier,
    CourierBold,
    CourierOblique,
    CourierBoldOblique,
    Symbol,
    ZapfDingbats,
  ]
}

///|
test "afm_data loads standard fonts" {
  for font in all_standard_fonts() {
    let (headers, widths, _, widths_by_name) = @pdfstandard14.PdfStandard14::new().afm_data(
      font,
    )
    assert_true(headers.length() > 0)
    assert_true(widths.length() > 0)
    assert_true(widths_by_name.length() > 0)
  }
}

///|
test "baseline_adjustment covers all fonts" {
  let values = all_standard_fonts().map(font => {
    @pdfstandard14.PdfStandard14::new().baseline_adjustment(font)
  })
  assert_eq(values.length(), all_standard_fonts().length())
  assert_eq(
    @pdfstandard14.PdfStandard14::new().baseline_adjustment(TimesBold),
    338,
  )
  assert_eq(
    @pdfstandard14.PdfStandard14::new().baseline_adjustment(HelveticaBold),
    359,
  )
}

///|
test "stemv_of_standard_font covers all fonts" {
  let values = all_standard_fonts().map(font => {
    @pdfstandard14.PdfStandard14::new().stemv_of_standard_font(font)
  })
  assert_eq(values.length(), all_standard_fonts().length())
  assert_eq(
    @pdfstandard14.PdfStandard14::new().stemv_of_standard_font(TimesBold),
    122,
  )
  assert_eq(
    @pdfstandard14.PdfStandard14::new().stemv_of_standard_font(ZapfDingbats),
    125,
  )
}

///|
test "textwidth handles missing widths and kerning" {
  let font = @pdffont.StandardFont::TimesRoman
  let missing = String::from_array([
    Int::unsafe_to_char(999),
    Int::unsafe_to_char(998),
  ])
  let (_, widths, kerns, widths_by_name) = @pdfstandard14.PdfStandard14::new().afm_data(
    font,
  )
  assert_true(widths.get(999) is None)
  assert_true(kerns.get((999, 998)) is None)
  let pdf = @pdf.Pdf::empty()
  let ctx = @pdftext.PdfText::new(pdf)
  let implicit_font : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(PdfName("/Type1"))),
  ])
  let implicit_encoding = ctx.read_encoding(implicit_font)
  let implicit_width = @pdfstandard14.PdfStandard14::new().textwidth(
    true, implicit_encoding, font, missing,
  )
  assert_eq(implicit_width, 0)
  assert_true(widths_by_name.get("NoSlash") is None)
  let no_slash = @pdfe.with_silenced_logs(fn() {
    @pdf.PdfName::of_string("NoSlash")
  })
  let custom_font : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(PdfName("/Type1"))),
    (
      "/Encoding",
      Dictionary([
        ("/BaseEncoding", Name(PdfName("/WinAnsiEncoding"))),
        ("/Differences", PdfArray([Integer(65), Name(no_slash)])),
      ]),
    ),
  ])
  let encoding = ctx.read_encoding(custom_font)
  let custom_width = @pdfstandard14.PdfStandard14::new().textwidth(
    false, encoding, font, "A",
  )
  assert_eq(custom_width, 0)
}

///|
test "textwidth handles empty string and unicode fallback" {
  let font = @pdffont.StandardFont::Helvetica
  let pdf = @pdf.Pdf::empty()
  let ctx = @pdftext.PdfText::new(pdf)
  let winansi_font : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(PdfName("/Type1"))),
    ("/Encoding", Name(PdfName("/WinAnsiEncoding"))),
  ])
  let encoding = ctx.read_encoding(winansi_font)
  let width_empty = @pdfstandard14.PdfStandard14::new().textwidth(
    false, encoding, font, "",
  )
  assert_eq(width_empty, 0)
  let unicode = String::from_array([Int::unsafe_to_char(256)])
  let width_space = @pdfstandard14.PdfStandard14::new().textwidth(
    false, encoding, font, unicode,
  )
  assert_true(width_space > 0)
}

///|
test "textwidth applies kerning for standard fonts" {
  let font = @pdffont.StandardFont::TimesRoman
  let pdf = @pdf.Pdf::empty()
  let ctx = @pdftext.PdfText::new(pdf)
  let implicit_font : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(PdfName("/Type1"))),
  ])
  let encoding = ctx.read_encoding(implicit_font)
  let kerned = @pdfstandard14.PdfStandard14::new().textwidth(
    true, encoding, font, "AV",
  )
  let plain = @pdfstandard14.PdfStandard14::new().textwidth(
    false, encoding, font, "AV",
  )
  assert_true(kerned <= plain)
  let single = @pdfstandard14.PdfStandard14::new().textwidth(
    false, encoding, font, "A",
  )
  assert_true(single > 0)
}

///|
test "flags_of_standard_font covers branches" {
  assert_eq(
    @pdfstandard14.PdfStandard14::new().flags_of_standard_font(Symbol),
    65541,
  )
  assert_eq(
    @pdfstandard14.PdfStandard14::new().flags_of_standard_font(
      CourierBoldOblique,
    ),
    33,
  )
  assert_eq(
    @pdfstandard14.PdfStandard14::new().flags_of_standard_font(Helvetica),
    32,
  )
}
