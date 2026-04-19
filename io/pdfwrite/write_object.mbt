///|
fn write_pdf_object_to_output(
  ctx : PdfWrite,
  obj : @pdf.PdfObject,
  output : @pdfio.Output,
  include_stream_data : Bool,
  hex_strings : Bool,
) -> Unit raise {
  fn write_str(s : String) -> Unit {
    (output.output_string)(s)
  }

  match obj {
    Null => write_str("null")
    Boolean(b) => write_str(if b { "true" } else { "false" })
    Integer(i) => write_str(i.to_string())
    Real(r) => write_str(format_real(r))
    PdfString(s) =>
      write_str(
        if hex_strings {
          make_hex_pdf_string(s)
        } else {
          make_pdf_string(s)
        },
      )
    Name(n) => write_str(make_pdf_name(ctx, n.to_string_bytes()))
    PdfArray(values) => {
      write_str("[")
      for i in 0..<values.length() {
        if i > 0 {
          write_str(" ")
        }
        write_pdf_object_to_output(
          ctx,
          values[i],
          output,
          include_stream_data,
          hex_strings,
        )
      }
      write_str("]")
    }
    Dictionary(entries) => {
      write_str("<<")
      for i in 0..<entries.length() {
        let (key, value) = entries[i]
        if i > 0 {
          write_str(" ")
        }
        write_str(make_pdf_name(ctx, key))
        write_str(" ")
        let value_hex = hex_strings && key == "/ID"
        write_pdf_object_to_output(
          ctx, value, output, include_stream_data, value_hex,
        )
      }
      write_str(">>")
    }
    Stream(r) => {
      if include_stream_data {
        let _ = obj.getstream() catch { _ => () }
      }
      let (dict, stream_data) = r.val
      write_pdf_object_to_output(
        ctx, dict, output, include_stream_data, hex_strings,
      )
      write_str("\nstream\n")
      if include_stream_data {
        match stream_data {
          Got(bytes) => output.getinit(bytes, 0, @pdfio.bytes_size(bytes))
          _ => ()
        }
      }
      write_str("\nendstream")
    }
    Indirect(n) => write_str("\{n} 0 R")
  }
}

///|
fn write_pdf_object(
  ctx : PdfWrite,
  obj : @pdf.PdfObject,
  include_stream_data : Bool,
  warn_on_toget : Bool,
  sb : StringBuilder,
) -> Unit {
  match obj {
    Null => sb.write_string("null")
    Boolean(b) => sb.write_string(if b { "true" } else { "false" })
    Integer(i) => sb.write_string(i.to_string())
    Real(r) => sb.write_string(format_real(r))
    PdfString(s) => sb.write_string(make_pdf_string(s))
    Name(n) => sb.write_string(make_pdf_name(ctx, n.to_string_bytes()))
    PdfArray(values) => {
      sb.write_char('[')
      for i in 0..<values.length() {
        if i > 0 {
          sb.write_char(' ')
        }
        write_pdf_object(ctx, values[i], include_stream_data, warn_on_toget, sb)
      }
      sb.write_char(']')
    }
    Dictionary(entries) => {
      sb.write_string("<<")
      for i in 0..<entries.length() {
        let (key, value) = entries[i]
        if i > 0 {
          sb.write_char(' ')
        }
        sb.write_string(make_pdf_name(ctx, key))
        sb.write_char(' ')
        write_pdf_object(ctx, value, include_stream_data, warn_on_toget, sb)
      }
      sb.write_string(">>")
    }
    Stream(r) => {
      let (dict, _) = r.val
      write_pdf_object(ctx, dict, include_stream_data, warn_on_toget, sb)
      sb.write_string("\nstream\n")
      if include_stream_data {
        let _ = obj.getstream() catch { _ => () }
        match r.val {
          (_, Got(bytes)) => sb.write_string(@pdfio.string_of_bytes(bytes))
          _ =>
            if warn_on_toget {
              (ctx.logger)(
                "WARNING: toget in string_of_pdfobj_including_data\n",
              )
            }
        }
      }
      sb.write_string("\nendstream")
    }
    Indirect(n) => sb.write_string("\{n} 0 R")
  }
}

///|
/// String of a PDF object.
pub fn PdfWrite::string_of_pdf(self : PdfWrite, obj : @pdf.PdfObject) -> String {
  let sb = StringBuilder::new()
  write_pdf_object(self, obj, false, false, sb)
  sb.to_string()
}
