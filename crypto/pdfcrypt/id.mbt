///|
fn get_or_add_id(pdf : @pdf.Pdf) -> (String, @pdf.Pdf) raise {
  match pdf.lookup_direct("/ID", pdf.trailerdict) {
    Some(PdfArray([PdfString(s), _])) => (@pdf.string_bytes_of_bytes(s), pdf)
    _ => {
      let stamp = @env.now().to_string()
      let id = stamp
      let id_bytes = @pdf.bytes_of_string_bytes(id)
      let idobj = @pdf.PdfObject::PdfArray([
        PdfString(id_bytes),
        PdfString(id_bytes),
      ])
      pdf.trailerdict = pdf.trailerdict.add_entry("/ID", idobj)
      (id, pdf)
    }
  }
}
