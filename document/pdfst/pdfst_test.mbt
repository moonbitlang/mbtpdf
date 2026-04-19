///|
test "trim_structure_tree no-ops on empty pdf" {
  let pdf0 = @pdf.Pdf::empty()
  let pages_root_num = pdf0.addobj(
    Dictionary([
      ("/Type", Name(PdfName(b"/Pages"))),
      ("/Kids", PdfArray([])),
      ("/Count", Integer(0)),
    ]),
  )
  let catalog_num = pdf0.addobj(
    Dictionary([
      ("/Type", Name(PdfName(b"/Catalog"))),
      ("/Pages", Indirect(pages_root_num)),
    ]),
  )
  let trailerdict = pdf0.trailerdict.add_entry("/Root", Indirect(catalog_num))
  let pdf : @pdf.Pdf = {
    major: pdf0.major,
    minor: pdf0.minor,
    root: catalog_num,
    objects: pdf0.objects,
    trailerdict,
    was_linearized: pdf0.was_linearized,
    saved_encryption: pdf0.saved_encryption,
  }
  @pdfst.PdfStructTree::new(pdf).trim_structure_tree([])
}

///|
test "renumber_parent_trees updates direct StructTreeRoot and keeps unmapped StructParent" {
  let pdf1 = @pdf.Pdf::empty()
  let tagged = pdf1.addobj(Dictionary([("/StructParent", Integer(123))]))
  pdf1.trailerdict = pdf1.trailerdict.add_entry(
    "/Root",
    Dictionary([("/StructTreeRoot", Dictionary([]))]),
  )
  let pdf2 = @pdf.Pdf::empty()
  pdf2.trailerdict = pdf2.trailerdict.add_entry(
    "/Root",
    Dictionary([("/StructTreeRoot", Dictionary([]))]),
  )
  @pdfst.PdfStructTrees::new([pdf1, pdf2]).renumber_parent_trees()
  match pdf1.lookup_direct("/StructParent", pdf1.lookup_obj(tagged)) {
    Some(Integer(123)) => ()
    _ => fail("expected /StructParent to remain unchanged")
  }
  match
    pdf1.lookup_chain(pdf1.trailerdict, [
      "/Root", "/StructTreeRoot", "/ParentTree",
    ]) {
    Some(_) => ()
    None => fail("expected /ParentTree to be written")
  }
}
