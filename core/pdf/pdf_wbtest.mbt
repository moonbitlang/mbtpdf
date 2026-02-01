///|
test "check_object_contains_renumbering detects indirects" {
  let changes : Map[Int, Int] = Map::new()
  changes.set(2, 99)
  assert_true(!check_object_contains_renumbering(changes, Integer(1)))
  assert_true(check_object_contains_renumbering(changes, Indirect(2)))
  let arr = Array([Integer(1), Indirect(2)])
  assert_true(check_object_contains_renumbering(changes, arr))
  let dict = PdfObject::Dictionary([
    (PdfName::of_bytes("/A"), Integer(1)),
    (PdfName::of_bytes("/B"), Indirect(2)),
  ])
  assert_true(check_object_contains_renumbering(changes, dict))
  let stream_dict = PdfObject::Dictionary([
    (PdfName::of_bytes("/Length"), Integer(0)),
    (PdfName::of_bytes("/B"), Indirect(2)),
  ])
  let stream = Stream(Ref::new((stream_dict, Got([]))))
  assert_true(check_object_contains_renumbering(changes, stream))
}
