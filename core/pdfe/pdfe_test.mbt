///|
test "log forwards to logger" {
  let messages : Array[String] = []
  @pdfe.with_logger(fn(message) { messages.push(message) }, fn() {
    @pdfe.log("hello")
    @pdfe.log("world")
    ()
  })
  debug_inspect(messages, content="[\"hello\", \"world\"]")
}

///|
test "quiet suppresses log output" {
  let messages : Array[String] = []
  @pdfe.with_logger(fn(message) { messages.push(message) }, fn() {
    @pdfe.quiet.val = true
    @pdfe.log("hello")
    @pdfe.quiet.val = false
    @pdfe.log("world")
    ()
  })
  debug_inspect(messages, content="[\"world\"]")
}

///|
test "with_silenced_logs restores quiet flag" {
  @pdfe.quiet.val = false
  let messages : Array[String] = []
  @pdfe.with_logger(fn(message) { messages.push(message) }, fn() {
    @pdfe.with_silenced_logs(fn() {
      @pdfe.log("hidden")
      ()
    })
    @pdfe.log("shown")
    ()
  })
  assert_false(@pdfe.quiet.val)
  debug_inspect(messages, content="[\"shown\"]")
}

///|
test "with_logger restores previous logger on error" {
  let outer_messages : Array[String] = []
  let inner_messages : Array[String] = []
  @pdfe.with_logger(fn(message) { outer_messages.push(message) }, fn() {
    let res : Result[Unit, Error] = try
      @pdfe.with_logger(fn(message) { inner_messages.push(message) }, fn() {
        @pdfe.log("inner")
        fail("boom")
      })
      |> Ok
    catch {
      e => Err(e)
    }
    assert_true(res is Err(_))
    @pdfe.log("outer")
    ()
  })
  debug_inspect(inner_messages, content="[\"inner\"]")
  debug_inspect(outer_messages, content="[\"outer\"]")
}

///|
test "warn appends newline (and preserves existing newline)" {
  let messages : Array[String] = []
  @pdfe.with_logger(fn(message) { messages.push(message) }, fn() {
    @pdfe.warn("hello")
    @pdfe.warn("world\n")
    ()
  })
  debug_inspect(messages, content="[\"hello\\n\", \"world\\n\"]")
}

///|
test "debug logs only when read_debug is enabled" {
  let prev = @pdfe.read_debug.val
  let messages : Array[String] = []
  @pdfe.with_logger(fn(message) { messages.push(message) }, fn() {
    @pdfe.read_debug.val = false
    @pdfe.debug("hidden\n")
    @pdfe.read_debug.val = true
    @pdfe.debug("shown\n")
    @pdfe.read_debug.val = prev
    ()
  })
  debug_inspect(messages, content="[\"shown\\n\"]")
}

///|
test "default logger writes via PdfUtil" {
  let lines : Array[String] = []
  @pdfutil.with_printer(s => lines.push(s), fn() {
    @pdfutil.with_quiet(true, fn() { @pdfutil.PdfUtil::new().fleprint("reset") })
    @pdfutil.with_quiet(false, fn() {
      (@pdfe.logger.val)("hello\n")
      assert_eq(lines, ["hello"])
    })
    ()
  })
}
