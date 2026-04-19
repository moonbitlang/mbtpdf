///|
/// The 14 Standard PDF Fonts (Widths and Kerns).

///|
pub struct PdfStandard14 {
  unit : Unit
}

///|
pub fn PdfStandard14::new() -> PdfStandard14 {
  { unit: () }
}

///|
type AfmTables = (
  Map[String, String],
  Map[Int, Int],
  Map[(Int, Int), Int],
  Map[String, Int],
)

///|
fn read_afm(afm : Array[Byte]) -> AfmTables raise {
  let decompressed = @pdfio.string_of_bytes(
    @pdfcodec.PdfCodec::new().decode_flate(afm),
  )
  let (headers, ws, ks, ws_prime) = @pdfafm.PdfAfm::new().read(
    @pdfio.Input::of_string(decompressed),
  )
  (
    @pdfutil.PdfUtil::new().hashtable_of_dictionary(headers),
    @pdfutil.PdfUtil::new().hashtable_of_dictionary(ws),
    @pdfutil.PdfUtil::new().hashtable_of_dictionary(
      ks.map(pair => ((pair.0, pair.1), pair.2)),
    ),
    @pdfutil.PdfUtil::new().hashtable_of_dictionary(ws_prime),
  )
}

///|
let tables : Array[(@pdffont.StandardFont, () -> AfmTables raise)] = [
  (
    TimesRoman,
    @pdfutil.PdfUtil::new().memoize(() => {
      read_afm(@pdfafmdata.PdfAfmData::new().times_roman_afm())
    }),
  ),
  (
    TimesBold,
    @pdfutil.PdfUtil::new().memoize(() => {
      read_afm(@pdfafmdata.PdfAfmData::new().times_bold_afm())
    }),
  ),
  (
    TimesItalic,
    @pdfutil.PdfUtil::new().memoize(() => {
      read_afm(@pdfafmdata.PdfAfmData::new().times_italic_afm())
    }),
  ),
  (
    TimesBoldItalic,
    @pdfutil.PdfUtil::new().memoize(() => {
      read_afm(@pdfafmdata.PdfAfmData::new().times_bold_italic_afm())
    }),
  ),
  (
    Helvetica,
    @pdfutil.PdfUtil::new().memoize(() => {
      read_afm(@pdfafmdata.PdfAfmData::new().helvetica_afm())
    }),
  ),
  (
    HelveticaBold,
    @pdfutil.PdfUtil::new().memoize(() => {
      read_afm(@pdfafmdata.PdfAfmData::new().helvetica_bold_afm())
    }),
  ),
  (
    HelveticaOblique,
    @pdfutil.PdfUtil::new().memoize(() => {
      read_afm(@pdfafmdata.PdfAfmData::new().helvetica_oblique_afm())
    }),
  ),
  (
    HelveticaBoldOblique,
    @pdfutil.PdfUtil::new().memoize(() => {
      read_afm(@pdfafmdata.PdfAfmData::new().helvetica_bold_oblique_afm())
    }),
  ),
  (
    Courier,
    @pdfutil.PdfUtil::new().memoize(() => {
      read_afm(@pdfafmdata.PdfAfmData::new().courier_afm())
    }),
  ),
  (
    CourierBold,
    @pdfutil.PdfUtil::new().memoize(() => {
      read_afm(@pdfafmdata.PdfAfmData::new().courier_bold_afm())
    }),
  ),
  (
    CourierOblique,
    @pdfutil.PdfUtil::new().memoize(() => {
      read_afm(@pdfafmdata.PdfAfmData::new().courier_oblique_afm())
    }),
  ),
  (
    CourierBoldOblique,
    @pdfutil.PdfUtil::new().memoize(() => {
      read_afm(@pdfafmdata.PdfAfmData::new().courier_bold_oblique_afm())
    }),
  ),
  (
    Symbol,
    @pdfutil.PdfUtil::new().memoize(() => {
      read_afm(@pdfafmdata.PdfAfmData::new().symbol_afm())
    }),
  ),
  (
    ZapfDingbats,
    @pdfutil.PdfUtil::new().memoize(() => {
      read_afm(@pdfafmdata.PdfAfmData::new().zapf_dingbats_afm())
    }),
  ),
]

///|
fn lookup_tables(font : @pdffont.StandardFont) -> AfmTables raise {
  for entry in tables {
    if entry.0 == font {
      return (entry.1)()
    }
  }
  fail("standard14: missing font data")
}

///|
pub fn PdfStandard14::baseline_adjustment(
  _self : PdfStandard14,
  font : @pdffont.StandardFont,
) -> Int {
  match font {
    TimesRoman => 662 / 2
    TimesBold => 676 / 2
    TimesItalic => 653 / 2
    TimesBoldItalic => 669 / 2
    Helvetica => 718 / 2
    HelveticaBold => 718 / 2
    HelveticaOblique => 718 / 2
    HelveticaBoldOblique => 718 / 2
    Courier => 562 / 2
    CourierBold => 562 / 2
    CourierOblique => 562 / 2
    CourierBoldOblique => 562 / 2
    Symbol => 673 / 2
    ZapfDingbats => 705 / 2
  }
}

///|
fn find_kern(kerns : Map[(Int, Int), Int], key : (Int, Int)) -> Int {
  match kerns.get(key) {
    Some(value) => value
    None => 0
  }
}

///|
fn find_width(
  widths : Map[Int, Int],
  charname_to_width : Map[String, Int],
  encoding : @pdffont.Encoding,
  encoding_table : Map[Int, String],
  code : Int,
) -> Int raise {
  match encoding {
    ImplicitInFontFile =>
      match widths.get(code) {
        Some(value) => value
        None => 0
      }
    _ => {
      let charname = match encoding_table.get(code) {
        Some(value) => value
        None => "/space"
      }
      let stripped = match charname.get_char(0) {
        Some('/') => charname[1:].to_string()
        _ => charname
      }
      match charname_to_width.get(stripped) {
        Some(value) => value
        None => 0
      }
    }
  }
}

///|
fn width(
  dokern : Bool,
  widths : Map[Int, Int],
  charname_to_width : Map[String, Int],
  encoding : @pdffont.Encoding,
  encoding_table : Map[Int, String],
  kerns : Map[(Int, Int), Int],
  codes : Array[Int],
) -> Int raise {
  if codes.length() == 0 {
    return 0
  }
  let mut total = 0
  for i in 0..<codes.length() {
    let h = codes[i]
    total = total +
      find_width(widths, charname_to_width, encoding, encoding_table, h)
    if dokern && i + 1 < codes.length() {
      total = total + find_kern(kerns, (h, codes[i + 1]))
    }
  }
  total
}

///|
pub fn PdfStandard14::textwidth(
  _self : PdfStandard14,
  dokern : Bool,
  encoding : @pdffont.Encoding,
  font : @pdffont.StandardFont,
  s : String,
) -> Int raise {
  let (_, widths, kerns, charname_to_width) = lookup_tables(font)
  let encoding_table = @pdffont.Encoding::table(encoding)
  let codes = Array::new(capacity=s.length())
  for c in s {
    codes.push(c.to_int())
  }
  width(
    dokern, widths, charname_to_width, encoding, encoding_table, kerns, codes,
  )
}

///|
pub fn PdfStandard14::afm_data(
  _self : PdfStandard14,
  font : @pdffont.StandardFont,
) -> AfmTables raise {
  lookup_tables(font)
}

///|
pub fn PdfStandard14::stemv_of_standard_font(
  _self : PdfStandard14,
  font : @pdffont.StandardFont,
) -> Int {
  match font {
    TimesRoman => 116
    TimesBold => 122
    TimesItalic => 105
    TimesBoldItalic => 108
    Helvetica => 114
    HelveticaBold => 123
    HelveticaOblique => 127
    HelveticaBoldOblique => 136
    Courier => 88
    CourierBold => 93
    CourierOblique => 100
    CourierBoldOblique => 104
    Symbol => 0
    ZapfDingbats => 125
  }
}

///|
pub fn PdfStandard14::flags_of_standard_font(
  _self : PdfStandard14,
  font : @pdffont.StandardFont,
) -> Int {
  match font {
    Symbol => 65541
    ZapfDingbats => 4
    Courier | CourierBold | CourierOblique | CourierBoldOblique => 33
    _ => 32
  }
}
