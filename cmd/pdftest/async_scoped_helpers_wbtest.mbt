///|
async test "pdfe.with_logger_async restores logger on error" {
  let prev_logger = @pdfe.logger.val
  let prev_quiet = @pdfe.quiet.val
  let outer : Array[String] = []
  let inner : Array[String] = []
  @pdfe.quiet.val = false
  @pdfe.logger.val = s => outer.push(s)
  defer {
    @pdfe.quiet.val = prev_quiet
    @pdfe.logger.val = prev_logger
  }
  let res : Result[Unit, Error] = try
    @pdfe.with_logger_async(s => inner.push(s), fn() {
      @pdfe.log("inner")
      fail("boom")
    })
    |> Ok
  catch {
    e => Err(e)
  }
  assert_true(res is Err(_))
  @pdfe.log("outer")
  assert_eq(inner, ["inner"])
  assert_eq(outer, ["outer"])
}

///|
async test "pdfutil.with_printer_async restores printer on error" {
  let prev_quiet = @pdfutil.quiet.val
  let prev_printer = @pdfutil.printer.val
  let outer : Array[String] = []
  let inner : Array[String] = []

  // Ensure no leftover buffered content.
  @pdfutil.quiet.val = true
  @pdfutil.PdfUtil::new().flprint("reset\n")
  @pdfutil.PdfUtil::new().fleprint("reset\n")
  @pdfutil.quiet.val = false
  @pdfutil.printer.val = s => outer.push(s)
  defer {
    @pdfutil.quiet.val = prev_quiet
    @pdfutil.printer.val = prev_printer
  }
  let res : Result[Unit, Error] = try
    @pdfutil.with_printer_async(s => inner.push(s), fn() {
      @pdfutil.PdfUtil::new().flprint("inner\n")
      fail("boom")
    })
    |> Ok
  catch {
    e => Err(e)
  }
  assert_true(res is Err(_))
  @pdfutil.PdfUtil::new().flprint("outer\n")
  assert_eq(inner, ["inner"])
  assert_eq(outer, ["outer"])
}
