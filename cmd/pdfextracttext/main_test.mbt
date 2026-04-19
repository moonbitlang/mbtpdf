///|
async fn cleanup(path : String) -> Unit {
  let _ : Result[Unit, Error] = try? @fs.remove(path)
}

///|
async test "run extracts text and rejects encrypted inputs" {
  @pdfutil.with_quiet_async(true, async fn() {
    @pdfe.with_silenced_logs_async(async fn() {
      run(["pdftext"], quiet=true)
      let in_file = "cmd_pdftext_in.pdf"
      let out_file = "cmd_pdftext_out.txt"
      cleanup(in_file)
      cleanup(out_file)
      let pdf = @pdfpage.PdfPageDoc::minimum_valid()
      @pdfwritefs.PdfWriteFs::new().pdf_to_file(pdf, in_file)
      run(["pdftext", in_file, out_file], quiet=true)
      assert_true(@fs.exists(out_file))
      let enc_file = "cmd_pdftext_enc.pdf"
      let out_enc = "cmd_pdftext_enc.txt"
      cleanup(enc_file)
      cleanup(out_enc)
      let enc = @pdfcrypt.PdfCrypt::new().encrypt_pdf_40bit(
        "user",
        "owner",
        [],
        pdf,
      )
      @pdfwritefs.PdfWriteFs::new().pdf_to_file(enc, enc_file)
      run(["pdftext", enc_file, out_enc], quiet=true)
      assert_false(@fs.exists(out_enc))
      cleanup(in_file)
      cleanup(out_file)
      cleanup(enc_file)
      cleanup(out_enc)
      ()
    })
  })
}
