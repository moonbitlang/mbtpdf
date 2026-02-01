///|
test "nametree lookup" {
  let pdf = Pdf::empty()
  let names = PdfObject::Array([
    String("A"),
    Integer(1),
    String("B"),
    Integer(2),
  ])
  let tree = d([("/Names", names)])
  assert_some_integer(pdf.nametree_lookup(String("A"), tree), 1)
  match pdf.nametree_lookup(String("C"), tree) {
    None => ()
    _ => fail("expected none")
  }
  let tree_limits_low = d([
    ("/Limits", Array([String("B"), String("C")])),
    ("/Names", Array([String("B"), Integer(2)])),
  ])
  match pdf.nametree_lookup(String("A"), tree_limits_low) {
    None => ()
    _ => fail("expected none")
  }
  let tree_limits_high = d([
    ("/Limits", Array([String("A"), String("B")])),
    ("/Names", Array([String("A"), Integer(1)])),
  ])
  match pdf.nametree_lookup(String("Z"), tree_limits_high) {
    None => ()
    _ => fail("expected none")
  }
  let tree_limits_ok = d([
    ("/Limits", Array([String("A"), String("Z")])),
    ("/Names", Array([String("M"), Integer(3)])),
  ])
  assert_some_integer(pdf.nametree_lookup(String("M"), tree_limits_ok), 3)
  let kid_missing = d([("/Names", Array([String("X"), Integer(1)]))])
  let kid = d([("/Names", Array([String("K"), Integer(9)]))])
  let parent = d([("/Kids", Array([kid_missing, kid]))])
  assert_some_integer(pdf.nametree_lookup(String("K"), parent), 9)
  let bad_parent = d([("/Kids", Integer(1))])
  assert_is_err(try? pdf.nametree_lookup(String("A"), bad_parent))
  let int_tree = d([("/Names", Array([Integer(1), String("one")]))])
  match pdf.nametree_lookup(Integer(1), int_tree) {
    Some(String("one")) => ()
    _ => fail("expected integer key match")
  }
  let missing = d([])
  assert_is_err(try? pdf.nametree_lookup(String("A"), missing))
  let malformed = d([("/Limits", Integer(1))])
  assert_is_err(try? pdf.nametree_lookup(String("A"), malformed))
  let bad_names = d([("/Names", Integer(1))])
  assert_is_err(try? pdf.nametree_lookup(String("A"), bad_names))
  let kids_pdf = Pdf::empty()
  let kid1 = d([("/Names", Array([String("A"), Integer(1)]))])
  let kid2 = d([("/Names", Array([String("M"), Integer(2)]))])
  kids_pdf.addobj_given_num((2, kid1))
  kids_pdf.addobj_given_num((3, kid2))
  let parent_with_kids = d([
    ("/Limits", Array([String("A"), String("Z")])),
    ("/Kids", Array([Indirect(2), Indirect(3)])),
  ])
  assert_some_integer(
    kids_pdf.nametree_lookup(String("M"), parent_with_kids),
    2,
  )
  match kids_pdf.nametree_lookup(Name(PdfName("/M")), parent_with_kids) {
    None => ()
    _ => fail("expected none for name key")
  }
  let malformed_entry = d([("/Limits", Array([String("A"), String("Z")]))])
  assert_is_err(try? kids_pdf.nametree_lookup(String("A"), malformed_entry))
}

///|
test "contents_of_nametree" {
  let pdf = Pdf::empty()
  let tree = d([("/Names", Array([String("A"), Integer(1), String("B")]))])
  let contents = @pdfe.with_logger(_ => (), fn() {
    pdf.contents_of_nametree(tree)
  })
  assert_eq(contents.length(), 1)
  match contents[0] {
    (String("A"), Integer(1)) => ()
    _ => fail("expected name pair")
  }
  let kid1 = d([("/Names", Array([String("K"), Integer(9)]))])
  let kid2 = d([("/Names", Array([String("L"), Integer(10)]))])
  let parent = d([("/Kids", Array([kid1, kid2]))])
  let flattened = pdf.contents_of_nametree(parent)
  assert_eq(flattened.length(), 2)
  let bad = d([("/Type", Name(PdfName("/Other")))])
  assert_is_err(try? pdf.contents_of_nametree(bad))
}
