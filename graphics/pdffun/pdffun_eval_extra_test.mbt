///|
fn calc_fun(ops : Array[Calculator]) -> PdfFunction {
  { func: Calculator(ops), domain: [0.0, 1.0], range: None }
}

///|
fn eval_calc_inputs(
  ops : Array[Calculator],
  inputs : Array[Double],
) -> Array[Double] raise BadFunctionEvaluation {
  calc_fun(ops).eval(inputs)
}

///|
fn assert_calc_err(ops : Array[Calculator]) -> Unit raise {
  let res : Result[Array[Double], Error] = try? calc_fun(ops).eval([0.0])
  assert_true(res is Err(_))
}

///|
test "parse_function sampled order" {
  let pdf = @pdf.Pdf::empty()
  let dict : @pdf.PdfObject = Dictionary([
    ("/FunctionType", Integer(0)),
    ("/Domain", PdfArray([Real(0.0), Real(1.0)])),
    ("/Range", PdfArray([Real(0.0), Real(1.0)])),
    ("/Size", PdfArray([Integer(1)])),
    ("/BitsPerSample", Integer(8)),
    ("/Order", Integer(3)),
    ("/Length", Integer(1)),
  ])
  let data = @pdfio.bytes_of_list([0x80])
  let stream : @pdf.PdfObject = Stream(Ref::new((dict, Got(data))))
  let parsed = PdfFunction::parse(pdf, stream)
  match parsed.func {
    Sampled(s) => assert_eq(s.order, 3)
    _ => fail("expected sampled function")
  }
}

///|
test "parse_function defaults c0 c1" {
  let pdf = @pdf.Pdf::empty()
  let dict : @pdf.PdfObject = Dictionary([
    ("/FunctionType", Integer(2)),
    ("/Domain", PdfArray([Real(0.0), Real(1.0)])),
    ("/N", Real(1.0)),
  ])
  let parsed = PdfFunction::parse(pdf, dict)
  match parsed.func {
    Interpolation(i) => {
      assert_eq(i.c0.length(), 1)
      assert_eq(i.c1.length(), 1)
      assert_eq(i.c0[0], 0.0)
      assert_eq(i.c1[0], 1.0)
    }
    _ => fail("expected interpolation function")
  }
}

///|
test "parse_function calculator supports nested procedures" {
  let pdf = @pdf.Pdf::empty()
  let program = "{ false { true { 1 } if } { 0 } ifelse }"
  let dict : @pdf.PdfObject = Dictionary([
    ("/FunctionType", Integer(4)),
    ("/Domain", PdfArray([Real(0.0), Real(1.0)])),
    ("/Length", Integer(program.length())),
  ])
  let data = @pdfio.bytes_of_string(program)
  let stream : @pdf.PdfObject = Stream(Ref::new((dict, Got(data))))
  let parsed = PdfFunction::parse(pdf, stream)
  match parsed.func {
    Calculator(ops) =>
      match ops {
        [Bool(false), IfElse([Bool(true), If([Int(1)])], [Int(0)])] => ()
        _ => fail("unexpected calculator parse result")
      }
    _ => fail("expected calculator function")
  }
}

///|
test "parse_function rejects bad bits per sample" {
  let pdf = @pdf.Pdf::empty()
  let dict : @pdf.PdfObject = Dictionary([
    ("/FunctionType", Integer(0)),
    ("/Domain", PdfArray([Real(0.0), Real(1.0)])),
    ("/Range", PdfArray([Real(0.0), Real(1.0)])),
    ("/Size", PdfArray([Integer(1)])),
    ("/BitsPerSample", Name(PdfName(b"/Bad"))),
  ])
  let res : Result[PdfFunction, Error] = try? PdfFunction::parse(pdf, dict)
  assert_true(res is Err(_))
}

///|
test "calculator bool output errors" {
  let ops = [Calculator::Float(1.0), Float(1.0), Eq]
  let res : Result[Array[Double], Error] = try? calc_fun(ops).eval([0.0])
  assert_true(res is Err(_))
}

///|
test "calculator compares bools" {
  let ops = [
    Calculator::Pop,
    Bool(true),
    Bool(true),
    Ge,
    IfElse([Int(1)], [Int(0)]),
  ]
  let out = eval_calc_inputs(ops, [0.0])
  assert_eq(out.length(), 1)
  assert_eq(out[0], 1.0)
}

///|
test "calculator conversions and rounding" {
  let ops = [
    Calculator::Pop,
    Int(2),
    Cvi,
    Cvr,
    Float(1.5),
    Cvr,
    Neg,
    Int(3),
    Round,
    Truncate,
    Floor,
  ]
  let out = eval_calc_inputs(ops, [0.0])
  assert_true(out.length() >= 2)
}

///|
test "calculator mul and sub mixed types" {
  let ops = [Calculator::Pop, Float(2.0), Int(3), Mul, Int(1), Sub]
  let out = eval_calc_inputs(ops, [0.0])
  assert_eq(out.length(), 1)
  assert_eq(out[0], 5.0)
}

///|
test "calculator mul and sub float int" {
  let ops = [
    Calculator::Pop,
    Int(4),
    Float(1.5),
    Mul,
    Int(2),
    Float(1.0),
    Sub,
    Sub,
  ]
  let out = eval_calc_inputs(ops, [0.0])
  assert_true(out.length() >= 1)
}

///|
test "calculator bitshift with negative values" {
  let ops = [Calculator::Pop, Int(1), Int(-4), Bitshift]
  let out = eval_calc_inputs(ops, [0.0])
  assert_eq(out.length(), 1)
}

///|
test "calculator roll handles negative and zero shift" {
  let ops_negative = [
    Calculator::Pop,
    Int(10),
    Int(20),
    Int(30),
    Int(3),
    Int(-1),
    Roll,
  ]
  let out = eval_calc_inputs(ops_negative, [0.0])
  assert_eq(out.length(), 3)
  let ops_zero = [Calculator::Pop, Int(1), Int(2), Int(3), Int(3), Int(0), Roll]
  let out_zero = eval_calc_inputs(ops_zero, [0.0])
  assert_eq(out_zero.length(), 3)
}

///|
test "calculator type errors" {
  let cases : Array[Array[Calculator]] = [
    [Pop, Bool(true), Abs],
    [Pop, Bool(true), Int(1), Add],
    [Pop, Bool(true), Ceiling],
    [Pop, Bool(true), Cvi],
    [Pop, Bool(true), Cvr],
    [Pop, Bool(true), Floor],
    [Pop, Bool(true), Int(1), Mul],
    [Pop, Bool(true), Neg],
    [Pop, Bool(true), Round],
    [Pop, Bool(true), Int(1), Sub],
    [Pop, Bool(true), Truncate],
    [Pop, Bool(true), Int(1), And],
    [Pop, Float(1.0), Not],
    [Pop, Bool(true), Int(1), Or],
    [Pop, Bool(true), Int(1), Xor],
    [Pop, Float(1.0), Copy],
    [Pop, Float(1.0), Index],
    [Pop, Int(10), Int(2), Int(1), Roll],
  ]
  for ops in cases {
    assert_calc_err(ops)
  }
}

///|
test "stitching bad arity and NaN input" {
  let f1 : PdfFunction = {
    func: Interpolation({ c0: [0.0], c1: [1.0], n: 1.0 }),
    domain: [0.0, 1.0],
    range: Some([0.0, 1.0]),
  }
  let fun : PdfFunction = {
    func: Stitching({ functions: [f1], bounds: [], stitch_encode: [0.0, 1.0] }),
    domain: [0.0, 1.0],
    range: Some([0.0, 1.0]),
  }
  let res_bad : Result[Array[Double], Error] = try? fun.eval([0.1, 0.2])
  assert_true(res_bad is Err(_))
  let res_nan : Result[Array[Double], Error] = try? fun.eval([0.0 / 0.0])
  assert_true(res_nan is Err(_))
}

///|
test "pdfobject_of_function handles zero bps" {
  let fun : PdfFunction = {
    func: Sampled({
      size: [1],
      order: 1,
      encode: [0.0, 0.0],
      decode: [0.0, 1.0],
      bps: 0,
      samples: [],
    }),
    domain: [0.0, 1.0],
    range: Some([0.0, 1.0]),
  }
  let pdf = @pdf.Pdf::empty()
  let obj = fun.to_pdf_object(pdf)
  match (obj : @pdf.PdfObject) {
    Stream(r) =>
      match (r.val.1 : @pdf.Stream) {
        Got(bytes) => assert_eq(@pdfio.bytes_size(bytes), 0)
        _ => fail("expected stream bytes")
      }
    _ => fail("expected stream")
  }
}
