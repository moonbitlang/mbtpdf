///|
/// Generate a minimal "Hello, World!" PDF document.
///
/// Parameters:
/// - `out_file`: Output filename (defaults to "hello.pdf")
/// - `quiet`: If true, suppress error messages on failure
pub async fn run(
  out_file? : String = "hello.pdf",
  quiet? : Bool = false,
) -> Unit {
  try {
    // Define a Type1 font using the built-in Times-Italic PostScript font.
    // Type1 fonts are one of the 14 standard PDF fonts that don't require embedding.
    let font = @pdf.PdfObject::Dictionary([
      ("/Type", Name(PdfName(b"/Font"))),
      ("/Subtype", Name(PdfName(b"/Type1"))),
      ("/BaseFont", Name(PdfName(b"/Times-Italic"))),
    ])

    // Build the page content as a sequence of PDF graphics operators:
    // - Opcm: Concatenate matrix - translate origin to (50, 770) points from bottom-left
    // - OpBT: Begin Text object
    // - OpTf: Set Text font to "/F0" at 36 point size
    // - OpTj: Show text string "Hello, World!"
    // - OpET: End Text object
    let ops : Array[@pdfops.Op] = [
      Opcm(@pdftransform.Transform([Translate(50.0, 770.0)]).to_matrix()),
      OpBT,
      OpTf("/F0", 36.0),
      OpTj("Hello, World!"),
      OpET,
    ]

    // Convert operators to a PDF content stream
    let stream = @pdfops.Op::stream_of_ops(ops)

    // Create a page with A4 dimensions, the content stream, and font resources
    let page = @pdfpage.Page(
      content=[stream],
      mediabox=@pdfpage.Page::blank(@pdfpaper.a4).mediabox,
      resources=Dictionary([("/Font", Dictionary([("/F0", font)]))]),
      rotate=Rotate0,
      rest=Dictionary([]),
    )

    // Build the PDF: create empty document, add page tree, then add document root
    let (pdf, pageroot) = @pdfpage.PdfPageDoc::new(@pdf.Pdf::empty()).add_pagetree([
        page,
      ],
    )
    let pdf = @pdfpage.PdfPageDoc::new(pdf).add_root(pageroot, [])

    // Write the PDF to disk
    @pdfwritefs.PdfWriteFs::new().pdf_to_file(pdf, out_file)
  } catch {
    err =>
      if !quiet {
        println("Failed to produce output.")
        println(err)
      }
  }
}

///|
/// Entry point - generates hello.pdf in the current directory.
async fn main {
  run()
}
