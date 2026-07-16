///|
async fn cleanup(path : String) -> Unit {
  @fs.remove(path) catch {
    _ => ()
  }
}

///|
async test "run writes output pdf" {
  let out = "cmd_pdfshowcase_test.pdf"
  cleanup(out)
  run(out_file=out, quiet=true)
  assert_true(@fs.exists(out))
  cleanup(out)
}
