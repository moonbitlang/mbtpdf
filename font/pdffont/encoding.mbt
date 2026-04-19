///|
/// Encoding table utilities.

///|
fn add_encoding(table : Map[Int, String], encoding : Encoding) -> Unit {
  let addvals = (vals : Array[(String, Int)]) => {
    for pair in vals {
      table.set(pair.1, pair.0)
    }
  }
  match encoding {
    ImplicitInFontFile => ()
    StandardEncoding => addvals(@pdfglyphlist.name_to_standard)
    MacRomanEncoding => addvals(@pdfglyphlist.name_to_macroman)
    WinAnsiEncoding => addvals(@pdfglyphlist.name_to_win)
    MacExpertEncoding => addvals(@pdfglyphlist.name_to_macexpert)
    CustomEncoding(enc, ds) => {
      add_encoding(table, enc)
      addvals(ds)
    }
    FillUndefinedWithStandard(enc) => {
      addvals(@pdfglyphlist.name_to_standard)
      add_encoding(table, enc)
    }
  }
}

///|
pub fn Encoding::table(self : Encoding) -> Map[Int, String] {
  let table : Map[Int, String] = Map::new(capacity=203)
  add_encoding(table, self)
  table
}

///|
pub fn Encoding::reverse_table(self : Encoding) -> Map[String, Int] {
  let table : Map[String, Int] = Map::new(capacity=203)
  let addvals = (vals : Array[(String, Int)]) => {
    for pair in vals {
      table.set(pair.0, pair.1)
    }
  }
  fn add_reverse(enc : Encoding) -> Unit {
    match enc {
      ImplicitInFontFile => ()
      StandardEncoding => addvals(@pdfglyphlist.name_to_standard)
      MacRomanEncoding => addvals(@pdfglyphlist.name_to_macroman)
      WinAnsiEncoding => addvals(@pdfglyphlist.name_to_win)
      MacExpertEncoding => addvals(@pdfglyphlist.name_to_macexpert)
      CustomEncoding(inner, ds) => {
        add_reverse(inner)
        addvals(ds)
      }
      FillUndefinedWithStandard(inner) => {
        addvals(@pdfglyphlist.name_to_standard)
        add_reverse(inner)
      }
    }
  }

  add_reverse(self)
  table
}
