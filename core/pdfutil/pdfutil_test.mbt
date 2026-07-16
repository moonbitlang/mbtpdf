///|
test "PdfUtil print shims respect quiet and printer" {
  let util = @pdfutil.PdfUtil::new()
  let lines : Array[String] = []
  @pdfutil.with_printer(s => lines.push(s), fn() {
    @pdfutil.with_quiet(true, fn() {
      util.flprint("reset")
      util.fleprint("reset")
      assert_eq(lines.length(), 0)
    })
    @pdfutil.with_quiet(false, fn() {
      util.flprint("a")
      util.flprint("b\nc")
      util.flprint("\n")
      util.fleprint("err\n")
      assert_eq(lines, ["ab", "c", "err"])
    })
    @pdfutil.with_quiet(true, fn() {
      util.flprint("ignored\n")
      util.fleprint("ignored\n")
      assert_eq(lines, ["ab", "c", "err"])
    })
    ()
  })
}

///|
test "PdfUtil::memoize caches computed values" {
  let util = @pdfutil.PdfUtil::new()
  let calls : Ref[Int] = Ref(0)
  let memo = util.memoize(fn() {
    calls.val = calls.val + 1
    calls.val
  })
  assert_eq(memo(), 1)
  assert_eq(memo(), 1)
  assert_eq(calls.val, 1)
}
