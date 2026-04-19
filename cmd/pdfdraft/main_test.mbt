///|
async fn cleanup(path : String) -> Unit {
  let _ : Result[Unit, Error] = try? @fs.remove(path)
}

///|
fn sample_rect() -> @pdf.PdfObject {
  PdfArray([Real(0.0), Real(0.0), Real(100.0), Real(100.0)])
}

///|
async test "run removes image xobjects and writes output" {
  @pdfutil.with_quiet_async(true, async fn() {
    @pdfe.with_silenced_logs_async(async fn() {
      run(["pdfdraft"], quiet=true)
      let in_file = "cmd_pdfdraft_in.pdf"
      let out_file = "cmd_pdfdraft_out.pdf"
      cleanup(in_file)
      cleanup(out_file)
      let img_xobj : @pdf.PdfObject = Dictionary([
        ("/Subtype", Name(PdfName("/Image"))),
      ])
      let form_xobj : @pdf.PdfObject = Dictionary([
        ("/Subtype", Name(PdfName("/Form"))),
      ])
      let resources : @pdf.PdfObject = Dictionary([
        ("/XObject", Dictionary([("/Im0", img_xobj), ("/Form0", form_xobj)])),
      ])
      let inline_dict : @pdf.PdfObject = Dictionary([
        ("/W", Integer(1)),
        ("/H", Integer(1)),
        ("/BPC", Integer(8)),
        ("/CS", Name(PdfName("/DeviceGray"))),
      ])
      let inline_data = @pdfops.Op::InlineImage(
        (inline_dict, None, [(0).to_byte()]),
      )
      let ops : Array[@pdfops.Op] = [
        Opq,
        OpDo("/Im0"),
        inline_data,
        OpDo("/Form0"),
        OpQ,
      ]
      let stream = @pdfops.Op::stream_of_ops(ops)
      let page = @pdfpage.Page(
        content=[stream],
        mediabox=sample_rect(),
        resources~,
        rotate=Rotate0,
        rest=Dictionary([]),
      )
      let (pdf1, pageroot) = @pdfpage.PdfPageDoc::new(@pdf.Pdf::empty()).add_pagetree([
          page,
        ],
      )
      let pdf = @pdfpage.PdfPageDoc::new(pdf1).add_root(pageroot, [])
      @pdfwritefs.PdfWriteFs::new().pdf_to_file(pdf, in_file)
      run(["pdfdraft", in_file, out_file], quiet=true)
      assert_true(@fs.exists(out_file))
      run(["pdfdraft", "missing_input.pdf", out_file], quiet=true)
      cleanup(in_file)
      cleanup(out_file)
      ()
    })
  })
}
