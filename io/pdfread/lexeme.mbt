///|
fn lex_object_for_xref(
  input : @pdfio.Input,
  xrefs : Map[Int32, XRef],
  read_stream_data : Bool,
  objnum : Int32,
) -> Array[@pdftoken.Token] raise {
  let current_pos = (input.pos_in)()
  match xrefs.get(objnum) {
    Some(Plain(offset, _gen)) => {
      (input.seek_in)(offset)
      let tokens = @pdfsyntax.lex_object_at(false, input, read_stream_data, fn(
        k : Int32,
      ) -> Array[@pdftoken.Token] raise {
        lex_object_for_xref(input, xrefs, read_stream_data, k)
      })
      (input.seek_in)(current_pos)
      tokens
    }
    Some(Stream(_, _)) => {
      let message = @pdf.input_pdferror(input, "Object in object stream")
      raise @pdf.PdfError::Msg(message)
    }
    None => {
      let message = @pdf.input_pdferror(input, "Object not in xref table")
      raise @pdf.PdfError::Msg(message)
    }
  }
}
