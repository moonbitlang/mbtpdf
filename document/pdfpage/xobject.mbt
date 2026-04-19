///|
fn merge_dict_entries(
  base : @pdf.PdfObject,
  extras : Array[(String, @pdf.PdfObject)],
) -> @pdf.PdfObject raise {
  let mut updated = base
  for entry in extras {
    updated = updated.add_entry(entry.0, entry.1)
  }
  updated
}

///|
/// Process a single XObject stream with a transformation function.
pub fn PdfPageDoc::process_xobject(
  self : PdfPageDoc,
  f : (@pdf.Pdf, @pdf.PdfObject, Array[@pdf.PdfObject]) -> Array[@pdf.PdfObject],
  resources : @pdf.PdfObject,
  objnum : Int,
) -> Unit raise {
  let pdf = self.pdf
  let xobj = pdf.lookup_obj(objnum)
  match pdf.lookup_direct("/Subtype", xobj) {
    None => raise @pdf.PdfError::Msg("No /Subtype in Xobject")
    Some(Name(PdfName("/Form"))) => {
      xobj.getstream()
      match xobj {
        Stream(r) =>
          match r.val {
            (Dictionary(dict), Got(_bytes)) =>
              match f(pdf, resources, [xobj]) {
                [Stream(updated)] => {
                  let (dict_updated, data) = updated.val
                  let merged = merge_dict_entries(
                    Dictionary(dict),
                    match dict_updated {
                      Dictionary(d) => d
                      _ => []
                    },
                  ).remove_entry("/Filter")
                  r.val = (merged, data)
                }
                _ => fail("process_xobject: bad stream")
              }
            _ => fail("process_xobject: bad stream")
          }
        _ => fail("process_xobject: bad stream")
      }
    }
    Some(_) => ()
  }
}

///|
/// Process XObjects within a page resources dictionary.
pub fn Page::process_xobjects(
  self : Page,
  pdf : @pdf.Pdf,
  f : (@pdf.Pdf, @pdf.PdfObject, Array[@pdf.PdfObject]) -> Array[@pdf.PdfObject],
) -> Unit raise {
  match pdf.lookup_direct("/XObject", self.resources) {
    Some(Dictionary(elts)) =>
      for entry in elts {
        match entry.1 {
          Indirect(i) =>
            PdfPageDoc::new(pdf).process_xobject(f, self.resources, i)
          _ => raise @pdf.PdfError::Msg("process_xobject")
        }
      }
    _ => ()
  }
}

///|
/// Union two resource dictionaries from the same PDF.
pub fn PdfPageDoc::combine_pdf_resources(
  self : PdfPageDoc,
  a : @pdf.PdfObject,
  b : @pdf.PdfObject,
) -> @pdf.PdfObject raise {
  let pdf = self.pdf
  let a_entries = match a {
    Dictionary(entries) => entries
    _ => []
  }
  let b_entries = match b {
    Dictionary(entries) => entries
    _ => []
  }
  fn combine_entries(key : String) -> (String, @pdf.PdfObject)? {
    let a_entries = match pdf.lookup_direct(key, a) {
      Some(Dictionary(d)) => d
      _ => []
    }
    let b_entries = match pdf.lookup_direct(key, b) {
      Some(Dictionary(d)) => d
      _ => []
    }
    if a_entries.length() == 0 && b_entries.length() == 0 {
      None
    } else {
      Some((key, Dictionary(a_entries + b_entries)))
    }
  }

  let unknown_keys_a = a_entries.filter(entry => {
    !resource_keys.contains(entry.0)
  })
  let unknown_keys_b = b_entries.filter(entry => {
    !resource_keys.contains(entry.0)
  })
  let combined_known = resource_keys.filter_map(combine_entries)
  let mut out = @pdf.PdfObject::Dictionary([])
  for entry in unknown_keys_a {
    out = out.add_entry(entry.0, entry.1)
  }
  for entry in unknown_keys_b {
    out = out.add_entry(entry.0, entry.1)
  }
  for entry in combined_known {
    out = out.add_entry(entry.0, entry.1)
  }
  out
}
