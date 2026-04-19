///|
test "nametree lookup" {
  let pdf = Pdf::empty()
  let names = PdfObject::PdfArray([
    PdfString("A"),
    Integer(1),
    PdfString("B"),
    Integer(2),
  ])
  let tree = PdfObject::Dictionary([("/Names", names)])
  assert_some_integer(pdf.nametree_lookup(PdfString("A"), tree), 1)
  match pdf.nametree_lookup(PdfString("C"), tree) {
    None => ()
    _ => fail("expected none")
  }
  let tree_limits_low = PdfObject::Dictionary([
    ("/Limits", PdfArray([PdfString("B"), PdfString("C")])),
    ("/Names", PdfArray([PdfString("B"), Integer(2)])),
  ])
  match pdf.nametree_lookup(PdfString("A"), tree_limits_low) {
    None => ()
    _ => fail("expected none")
  }
  let tree_limits_high = PdfObject::Dictionary([
    ("/Limits", PdfArray([PdfString("A"), PdfString("B")])),
    ("/Names", PdfArray([PdfString("A"), Integer(1)])),
  ])
  match pdf.nametree_lookup(PdfString("Z"), tree_limits_high) {
    None => ()
    _ => fail("expected none")
  }
  let tree_limits_ok = PdfObject::Dictionary([
    ("/Limits", PdfArray([PdfString("A"), PdfString("Z")])),
    ("/Names", PdfArray([PdfString("M"), Integer(3)])),
  ])
  assert_some_integer(pdf.nametree_lookup(PdfString("M"), tree_limits_ok), 3)
  let kid_missing = PdfObject::Dictionary([
    ("/Names", PdfArray([PdfString("X"), Integer(1)])),
  ])
  let kid = PdfObject::Dictionary([
    ("/Names", PdfArray([PdfString("K"), Integer(9)])),
  ])
  let parent = PdfObject::Dictionary([("/Kids", PdfArray([kid_missing, kid]))])
  assert_some_integer(pdf.nametree_lookup(PdfString("K"), parent), 9)
  let bad_parent = PdfObject::Dictionary([("/Kids", Integer(1))])
  assert_is_err(try? pdf.nametree_lookup(PdfString("A"), bad_parent))
  let int_tree = PdfObject::Dictionary([
    ("/Names", PdfArray([Integer(1), PdfString("one")])),
  ])
  match pdf.nametree_lookup(Integer(1), int_tree) {
    Some(PdfString("one")) => ()
    _ => fail("expected integer key match")
  }
  let missing = PdfObject::Dictionary([])
  assert_is_err(try? pdf.nametree_lookup(PdfString("A"), missing))
  let malformed = PdfObject::Dictionary([("/Limits", Integer(1))])
  assert_is_err(try? pdf.nametree_lookup(PdfString("A"), malformed))
  let bad_names = PdfObject::Dictionary([("/Names", Integer(1))])
  assert_is_err(try? pdf.nametree_lookup(PdfString("A"), bad_names))
  let kids_pdf = Pdf::empty()
  let kid1 = PdfObject::Dictionary([
    ("/Names", PdfArray([PdfString("A"), Integer(1)])),
  ])
  let kid2 = PdfObject::Dictionary([
    ("/Names", PdfArray([PdfString("M"), Integer(2)])),
  ])
  kids_pdf.addobj_given_num((2, kid1))
  kids_pdf.addobj_given_num((3, kid2))
  let parent_with_kids = PdfObject::Dictionary([
    ("/Limits", PdfArray([PdfString("A"), PdfString("Z")])),
    ("/Kids", PdfArray([Indirect(2), Indirect(3)])),
  ])
  assert_some_integer(
    kids_pdf.nametree_lookup(PdfString("M"), parent_with_kids),
    2,
  )
  match kids_pdf.nametree_lookup(Name(PdfName(b"/M")), parent_with_kids) {
    None => ()
    _ => fail("expected none for name key")
  }
  let malformed_entry = PdfObject::Dictionary([
    ("/Limits", PdfArray([PdfString("A"), PdfString("Z")])),
  ])
  assert_is_err(try? kids_pdf.nametree_lookup(PdfString("A"), malformed_entry))
}

///|
test "contents_of_nametree" {
  let pdf = Pdf::empty()
  let tree = PdfObject::Dictionary([
    ("/Names", PdfArray([PdfString("A"), Integer(1), PdfString("B")])),
  ])
  let contents = @pdfe.with_logger(_ => (), fn() {
    pdf.contents_of_nametree(tree)
  })
  assert_eq(contents.length(), 1)
  match contents[0] {
    (PdfString("A"), Integer(1)) => ()
    _ => fail("expected name pair")
  }
  let kid1 = PdfObject::Dictionary([
    ("/Names", PdfArray([PdfString("K"), Integer(9)])),
  ])
  let kid2 = PdfObject::Dictionary([
    ("/Names", PdfArray([PdfString("L"), Integer(10)])),
  ])
  let parent = PdfObject::Dictionary([("/Kids", PdfArray([kid1, kid2]))])
  let flattened = pdf.contents_of_nametree(parent)
  assert_eq(flattened.length(), 2)
  let bad = PdfObject::Dictionary([("/Type", Name(PdfName(b"/Other")))])
  assert_is_err(try? pdf.contents_of_nametree(bad))
}
