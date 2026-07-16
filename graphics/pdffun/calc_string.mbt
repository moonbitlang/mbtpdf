///|
fn calculator_to_string_inner(op : Calculator) -> String {
  match op {
    If(ops) => "\{calculator_ops_to_string(ops)} if"
    IfElse(a, b) =>
      "\{calculator_ops_to_string(a)} \{calculator_ops_to_string(b)} ifelse"
    Bool(true) => "true"
    Bool(false) => "false"
    Float(f) => f.to_string()
    Int(i) => i.to_string()
    Abs => "abs"
    Add => "add"
    Atan => "atan"
    Ceiling => "ceiling"
    Cos => "cos"
    Cvi => "cvi"
    Cvr => "cvr"
    Div => "div"
    Exp => "exp"
    Floor => "floor"
    Idiv => "idiv"
    Ln => "ln"
    Log => "log"
    Mod => "mod"
    Mul => "mul"
    Neg => "neg"
    Round => "round"
    Sin => "sin"
    Sqrt => "sqrt"
    Sub => "sub"
    Truncate => "truncate"
    And => "and"
    Bitshift => "bitshift"
    Eq => "eq"
    Ge => "ge"
    Gt => "gt"
    Le => "le"
    Lt => "lt"
    Ne => "ne"
    Not => "not"
    Or => "or"
    Xor => "xor"
    Copy => "copy"
    Exch => "exch"
    Pop => "pop"
    Dup => "dup"
    Index => "index"
    Roll => "roll"
  }
}

///|
fn calculator_ops_to_string(ops : Array[Calculator]) -> String {
  let parts = ops.map(calculator_to_string_inner)
  "{" + parts.join(" ") + "}"
}

///|
pub fn Calculator::to_string(self : Array[Calculator]) -> String {
  calculator_ops_to_string(self)
}

///|
/// Flatten a function to its PDF representation.
pub fn PdfFunction::to_pdf_object(
  self : PdfFunction,
  pdf : @pdf.Pdf,
) -> PdfObject {
  let domain = PdfObject::PdfArray(
    self.domain.map(x => @pdf.ToPdfNumber::to_pdf_number(x)),
  )
  let range_entry = match self.range {
    None => []
    Some(values) =>
      [
        (
          "/Range",
          PdfObject::PdfArray(
            values.map(x => @pdf.ToPdfNumber::to_pdf_number(x)),
          ),
        ),
      ]
  }
  let base = [
    ("/FunctionType", PdfObject::Integer(funtype_of_function(self))),
    ("/Domain", domain),
  ]
  match self.func {
    Sampled(s) => {
      let encode_vals = if s.encode.length() == 0 {
        interleave_lists(
          many(0.0, s.size.length()),
          s.size.map(x => (x - 1).to_double()),
        )
      } else {
        s.encode
      }
      let decode_vals = if s.decode.length() == 0 {
        match self.range {
          Some(values) => values
          None => []
        }
      } else {
        s.decode
      }
      let sampled_entries = [
        (
          "/Size",
          PdfObject::PdfArray(
            s.size.map(x => @pdf.ToPdfNumber::to_pdf_number(x)),
          ),
        ),
        ("/BitsPerSample", Integer(s.bps)),
        (
          "/Encode",
          PdfArray(encode_vals.map(x => @pdf.ToPdfNumber::to_pdf_number(x))),
        ),
      ]
      let sampled_entries = if decode_vals.length() > 0 {
        concat_arrays(sampled_entries, [
          (
            "/Decode",
            PdfArray(decode_vals.map(x => @pdf.ToPdfNumber::to_pdf_number(x))),
          ),
        ])
      } else {
        sampled_entries
      }
      let entries = concat_arrays(
        concat_arrays(base, range_entry),
        sampled_entries,
      )
      let entries_with_order = if s.order != 1 {
        concat_arrays(entries, [("/Order", Integer(s.order))])
      } else {
        entries
      }
      let data = sampled_bytes(s.samples, s.bps)
      let entries_with_length = concat_arrays(entries_with_order, [
        ("/Length", Integer(@pdfio.bytes_size(data))),
      ])
      Stream(Ref((Dictionary(entries_with_length), Got(data))))
    }
    Calculator(ops) => {
      let entries = concat_arrays(base, range_entry)
      let data = @pdfio.bytes_of_string(calculator_ops_to_string(ops))
      let entries_with_length = concat_arrays(entries, [
        ("/Length", Integer(@pdfio.bytes_size(data))),
      ])
      Stream(Ref((Dictionary(entries_with_length), Got(data))))
    }
    _ => {
      let extras = extra_entries_of_function(pdf, self)
      Dictionary(concat_arrays(concat_arrays(base, range_entry), extras))
    }
  }
}
