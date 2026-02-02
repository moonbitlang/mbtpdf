///|
/// Generate an /ID entry for a document.
pub fn Pdf::generate_id(
  self : Pdf,
  path : String,
  gettime : () -> Double,
) -> PdfObject {
  let _ = self
  let stamp = gettime().to_string()
  let id = path + stamp
  let bytes = bytes_of_string_bytes(id)
  PdfArray([PdfString(bytes), PdfString(bytes)])
}

///|
/// Replace the /ID entry in the trailer dictionary.
pub fn Pdf::change_id(self : Pdf, path : String) -> Unit raise {
  match self.trailerdict {
    Dictionary(_) =>
      self.trailerdict = self.trailerdict.add_entry(
        "/ID",
        self.generate_id(path, () => @env.now().to_double()),
      )
    _ => raise PdfError::Msg("Bad trailer dictionary")
  }
}
