///|
fn parse_lexemes(
  compatibility : Ref[Int],
  lexemes : Array[Lexeme],
) -> Array[Op] raise {
  let ops : Array[Op] = []
  let mut index = 0
  while index < lexemes.length() {
    let (op, next_index) = parse_operator(compatibility, lexemes, index)
    ops.push(op)
    index = next_index
  }
  ops
}

///|
/// Parse the operators in content streams.
///
/// This is the “page-friendly” entry point:
///
/// - Accepts a page’s `/Contents` array (`Array[PdfObject]`)
/// - Decodes compressed streams via `@pdfcodec.PdfCodec`
/// - Parses the resulting bytes into typed `Op`s
///
/// If you already have decoded bytes, prefer `Op::parse_stream` /
/// `Op::parse_single_stream`.
pub fn Op::parse_operators(
  pdf : @pdf.Pdf,
  resources : @pdf.PdfObject,
  streams : Array[@pdf.PdfObject],
) -> Array[Op] raise {
  let rawstreams : Array[Array[Byte]] = []
  for stream in streams {
    let direct = pdf.direct(stream)
    let r = match direct {
      Stream(r) => r
      _ => raise @pdf.PdfError::Msg("Malformed stream")
    }
    @pdfcodec.PdfCodec::new().decode_pdfstream(pdf, direct)
    direct.getstream()
    match r.val {
      (_, Got(data)) => rawstreams.push(data)
      _ => raise @pdf.PdfError::Msg("Malformed stream")
    }
  }
  Op::parse_stream(pdf, resources, rawstreams)
}
