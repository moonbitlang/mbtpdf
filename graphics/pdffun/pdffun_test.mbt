///|
fn assert_close(a : Double, b : Double) -> Unit raise {
  let diff = (a - b).abs()
  assert_true(diff < 0.000001)
}

///|
fn[T] assert_is_err(res : Result[T, Error]) -> Unit raise {
  match res {
    Err(_) => ()
    Ok(_) => fail("expected error")
  }
}

///|
fn eval_calc(ops : Array[Calculator]) -> Array[Double] raise {
  let fun : PdfFunction = { func: Calculator(ops), domain: [], range: None }
  PdfFunction::eval(fun, [])
}

///|
test "eval calculator function" {
  let pdf = @pdf.Pdf::empty()
  let dict : @pdf.PdfObject = @pdf.PdfObject::Dictionary([
    (@pdf.PdfName::of_bytes("/FunctionType"), Integer(4)),
    (@pdf.PdfName::of_bytes("/Domain"), Array([Real(0.0), Real(10.0)])),
  ])
  let data = @pdfio.bytes_of_string("{ dup mul }")
  let stream_ref = Ref::new((dict, @pdf.Stream::Got(data)))
  let stream_obj : @pdf.PdfObject = Stream(stream_ref)
  let fun = PdfFunction::parse(pdf, stream_obj)
  let output = PdfFunction::eval(fun, [2.0])
  assert_eq(output.length(), 1)
  assert_close(output[0], 4.0)
}

///|
test "eval interpolation function" {
  let fun : PdfFunction = {
    func: Interpolation({ c0: [0.0], c1: [1.0], n: 1.0 }),
    domain: [0.0, 1.0],
    range: Some([0.0, 1.0]),
  }
  let output = PdfFunction::eval(fun, [0.25])
  assert_eq(output.length(), 1)
  assert_close(output[0], 0.25)
}

///|
test "serialize sampled function" {
  let fun : PdfFunction = {
    func: Sampled({
      size: [2],
      order: 1,
      encode: [0.0, 1.0],
      decode: [0.0, 1.0],
      bps: 8,
      samples: [0, 255],
    }),
    domain: [0.0, 1.0],
    range: Some([0.0, 1.0]),
  }
  let pdf = @pdf.Pdf::empty()
  let obj = fun.to_pdf_object(pdf)
  match (obj : @pdf.PdfObject) {
    Stream(_) => ()
    _ => fail("expected sampled function to be a stream")
  }
  let parsed = PdfFunction::parse(pdf, obj)
  let output = PdfFunction::eval(parsed, [1.0])
  assert_eq(output.length(), 1)
  assert_close(output[0], 1.0)
}

///|
test "serialize calculator function" {
  let fun : PdfFunction = {
    func: Calculator([Dup, Mul]),
    domain: [0.0, 10.0],
    range: Some([0.0, 100.0]),
  }
  let pdf = @pdf.Pdf::empty()
  let obj = fun.to_pdf_object(pdf)
  match (obj : @pdf.PdfObject) {
    Stream(_) => ()
    _ => fail("expected calculator function to be a stream")
  }
  let parsed = PdfFunction::parse(pdf, obj)
  let output = PdfFunction::eval(parsed, [3.0])
  assert_eq(output.length(), 1)
  assert_close(output[0], 9.0)
}

///|
test "parse sampled function stream" {
  let pdf = @pdf.Pdf::empty()
  let dict : @pdf.PdfObject = @pdf.PdfObject::Dictionary([
    (@pdf.PdfName::of_bytes("/FunctionType"), Integer(0)),
    (@pdf.PdfName::of_bytes("/Domain"), Array([Real(0.0), Real(1.0)])),
    (@pdf.PdfName::of_bytes("/Range"), Array([Real(0.0), Real(1.0)])),
    (@pdf.PdfName::of_bytes("/Size"), Array([Integer(2)])),
    (@pdf.PdfName::of_bytes("/BitsPerSample"), Integer(8)),
  ])
  let data = @pdfio.bytes_of_list([0, 255])
  let stream : @pdf.PdfObject = Stream(Ref::new((dict, Got(data))))
  let fun = PdfFunction::parse(pdf, stream)
  match (fun.func : PdfFunctionKind) {
    Sampled(sample) => {
      assert_eq(sample.size.length(), 1)
      assert_eq(sample.samples.length(), 2)
      assert_eq(sample.samples[0], 0)
      assert_eq(sample.samples[1], 255)
    }
    _ => fail("expected sampled function")
  }
}

///|
test "serialize interpolation function" {
  let fun : PdfFunction = {
    func: Interpolation({ c0: [0.0], c1: [2.0], n: 1.0 }),
    domain: [0.0, 1.0],
    range: Some([0.0, 2.0]),
  }
  let pdf = @pdf.Pdf::empty()
  let obj = fun.to_pdf_object(pdf)
  let parsed = PdfFunction::parse(pdf, obj)
  let output = PdfFunction::eval(parsed, [0.5])
  assert_eq(output.length(), 1)
  assert_close(output[0], 1.0)
}

///|
test "serialize stitching function" {
  let f1 : PdfFunction = {
    func: Interpolation({ c0: [0.0], c1: [1.0], n: 1.0 }),
    domain: [0.0, 1.0],
    range: Some([0.0, 1.0]),
  }
  let f2 : PdfFunction = {
    func: Interpolation({ c0: [1.0], c1: [2.0], n: 1.0 }),
    domain: [0.0, 1.0],
    range: Some([1.0, 2.0]),
  }
  let fun : PdfFunction = {
    func: Stitching({
      functions: [f1, f2],
      bounds: [0.5],
      stitch_encode: [0.0, 1.0, 0.0, 1.0],
    }),
    domain: [0.0, 1.0],
    range: Some([0.0, 2.0]),
  }
  let pdf = @pdf.Pdf::empty()
  let obj = fun.to_pdf_object(pdf)
  let parsed = PdfFunction::parse(pdf, obj)
  let out1 = PdfFunction::eval(parsed, [0.25])
  let out2 = PdfFunction::eval(parsed, [0.75])
  assert_eq(out1.length(), 1)
  assert_eq(out2.length(), 1)
  assert_close(out1[0], 0.5)
  assert_close(out2[0], 1.5)
}

///|
test "serialize calculator covers opcode strings" {
  let ops : Array[Calculator] = [
    Cvi,
    Cvr,
    Div,
    Exp,
    Floor,
    Idiv,
    Ln,
    Log,
    Mod,
    Truncate,
    And,
    Bitshift,
    Eq,
    Ge,
    Gt,
    Le,
    Lt,
    Ne,
    Not,
    Or,
    Xor,
    Copy,
    Exch,
    Pop,
    Dup,
    Index,
    Roll,
  ]
  let fun : PdfFunction = {
    func: Calculator(ops),
    domain: [0.0, 1.0],
    range: None,
  }
  let pdf = @pdf.Pdf::empty()
  let obj = fun.to_pdf_object(pdf)
  match (obj : @pdf.PdfObject) {
    Stream(r) =>
      match r.val.1 {
        Got(bytes) => {
          let text = @pdfio.string_of_bytes(bytes)
          assert_true(text.contains("cvi"))
          assert_true(text.contains("bitshift"))
          assert_true(text.contains("roll"))
        }
        _ => fail("expected stream bytes")
      }
    _ => fail("expected stream object")
  }
}

///|
test "eval stitching function" {
  let pdf = @pdf.Pdf::empty()
  let f1 : @pdf.PdfObject = @pdf.PdfObject::Dictionary([
    (@pdf.PdfName::of_bytes("/FunctionType"), Integer(2)),
    (@pdf.PdfName::of_bytes("/Domain"), Array([Real(0.0), Real(1.0)])),
    (@pdf.PdfName::of_bytes("/C0"), Array([Real(0.0)])),
    (@pdf.PdfName::of_bytes("/C1"), Array([Real(1.0)])),
    (@pdf.PdfName::of_bytes("/N"), Real(1.0)),
  ])
  let f2 : @pdf.PdfObject = @pdf.PdfObject::Dictionary([
    (@pdf.PdfName::of_bytes("/FunctionType"), Integer(2)),
    (@pdf.PdfName::of_bytes("/Domain"), Array([Real(0.0), Real(1.0)])),
    (@pdf.PdfName::of_bytes("/C0"), Array([Real(1.0)])),
    (@pdf.PdfName::of_bytes("/C1"), Array([Real(2.0)])),
    (@pdf.PdfName::of_bytes("/N"), Real(1.0)),
  ])
  let dict : @pdf.PdfObject = @pdf.PdfObject::Dictionary([
    (@pdf.PdfName::of_bytes("/FunctionType"), Integer(3)),
    (@pdf.PdfName::of_bytes("/Domain"), Array([Real(0.0), Real(1.0)])),
    (@pdf.PdfName::of_bytes("/Functions"), Array([f1, f2])),
    (@pdf.PdfName::of_bytes("/Bounds"), Array([Real(0.5)])),
    (
      @pdf.PdfName::of_bytes("/Encode"),
      Array([Real(0.0), Real(1.0), Real(0.0), Real(1.0)]),
    ),
  ])
  let fun = PdfFunction::parse(pdf, dict)
  let out1 = PdfFunction::eval(fun, [0.25])
  let out2 = PdfFunction::eval(fun, [0.75])
  assert_eq(out1.length(), 1)
  assert_eq(out2.length(), 1)
  assert_close(out1[0], 0.5)
  assert_close(out2[0], 1.5)
}

///|
test "PdfFunction::print covers kinds and array sizes" {
  @pdfe.with_logger(_ => (), fn() {
    let empty_doubles : Array[Double] = []
    let some_doubles : Array[Double] = [0.0, 1.0]
    let empty_ints : Array[Int] = []
    let some_ints : Array[Int] = [1, 2]
    let sampled_empty : PdfFunction = {
      func: Sampled({
        size: empty_ints,
        order: 1,
        encode: empty_doubles,
        decode: empty_doubles,
        bps: 8,
        samples: empty_ints,
      }),
      domain: empty_doubles,
      range: None,
    }
    let sampled_full : PdfFunction = {
      func: Sampled({
        size: some_ints,
        order: 1,
        encode: some_doubles,
        decode: some_doubles,
        bps: 8,
        samples: some_ints,
      }),
      domain: some_doubles,
      range: Some(some_doubles),
    }
    let interpolation : PdfFunction = {
      func: Interpolation({ c0: empty_doubles, c1: empty_doubles, n: 1.0 }),
      domain: empty_doubles,
      range: None,
    }
    let stitching : PdfFunction = {
      func: Stitching({
        functions: [interpolation],
        bounds: empty_doubles,
        stitch_encode: empty_doubles,
      }),
      domain: empty_doubles,
      range: None,
    }
    let calculator : PdfFunction = {
      func: Calculator([
        Bool(true),
        Bool(false),
        Add,
        Atan,
        Ceiling,
        Cos,
        If([Int(1)]),
        IfElse([Int(0)], [Int(1)]),
        Neg,
        Index,
        Round,
        Sin,
        Sqrt,
        Sub,
        Roll,
      ]),
      domain: empty_doubles,
      range: None,
    }
    sampled_empty.print()
    sampled_full.print()
    interpolation.print()
    stitching.print()
    calculator.print()
  })
}

///|
test "parse calculator keywords from stream" {
  let pdf = @pdf.Pdf::empty()
  let dict : @pdf.PdfObject = @pdf.PdfObject::Dictionary([
    (@pdf.PdfName::of_bytes("/FunctionType"), Integer(4)),
    (@pdf.PdfName::of_bytes("/Domain"), Array([Real(0.0), Real(1.0)])),
  ])
  let data = @pdfio.bytes_of_string(
    "{ true 1.5 add 2 round 3 1 roll 2 atan 30 sin ceiling sqrt cos sub 2 abs 1 neg 0 index { 1 } if { 0 } { 1 } ifelse }",
  )
  let stream : @pdf.PdfObject = Stream(Ref::new((dict, Got(data))))
  @pdfe.with_logger(_ => (), fn() {
    let fun = PdfFunction::parse(pdf, stream)
    match (fun.func : PdfFunctionKind) {
      Calculator(ops) => {
        assert_true(ops.length() >= 10)
        match (ops[0] : Calculator) {
          Bool(true) => ()
          _ => fail("expected boolean literal")
        }
        match (ops[1] : Calculator) {
          Float(f) => assert_close(f, 1.5)
          _ => fail("expected float literal")
        }
        match (ops[2] : Calculator) {
          Add => ()
          _ => fail("expected add operator")
        }
        match (ops[3] : Calculator) {
          Int(2) => ()
          _ => fail("expected int literal")
        }
        match (ops[4] : Calculator) {
          Round => ()
          _ => fail("expected round operator")
        }
        match (ops[5] : Calculator) {
          Int(3) => ()
          _ => fail("expected int literal")
        }
        match (ops[6] : Calculator) {
          Int(1) => ()
          _ => fail("expected int literal")
        }
        match (ops[7] : Calculator) {
          Roll => ()
          _ => fail("expected roll operator")
        }
      }
      _ => fail("expected calculator function")
    }
    fun.print()
  })
}

///|
test "parse calculator rejects multi-token group" {
  let pdf = @pdf.Pdf::empty()
  let dict : @pdf.PdfObject = @pdf.PdfObject::Dictionary([
    (@pdf.PdfName::of_bytes("/FunctionType"), Integer(4)),
    (@pdf.PdfName::of_bytes("/Domain"), Array([Real(0.0), Real(1.0)])),
  ])
  let data = @pdfio.bytes_of_string("{ 0 { 1 2 } }")
  let stream : @pdf.PdfObject = Stream(Ref::new((dict, Got(data))))
  let res : Result[PdfFunction, Error] = try? PdfFunction::parse(pdf, stream)
  assert_true(res is Err(_))
}

///|
test "calculator arithmetic ops" {
  let add = eval_calc([Int(2), Int(3), Add])
  assert_eq(add.length(), 1)
  assert_close(add[0], 5.0)
  let sub = eval_calc([Int(10), Int(3), Sub])
  assert_close(sub[0], 7.0)
  let mul = eval_calc([Int(4), Int(5), Mul])
  assert_close(mul[0], 20.0)
  let div = eval_calc([Int(8), Int(2), Div])
  assert_close(div[0], 0.25)
  let exp = eval_calc([Int(3), Int(2), Exp])
  assert_close(exp[0], 8.0)
  let idiv = eval_calc([Int(3), Int(10), Idiv])
  assert_close(idiv[0], 3.0)
  let mod = eval_calc([Int(3), Int(10), Mod])
  assert_close(mod[0], 1.0)
}

///|
test "calculator rounding and conversion ops" {
  let abs = eval_calc([Float(-1.4), Abs])
  assert_close(abs[0], 1.4)
  let neg = eval_calc([Int(5), Neg])
  assert_close(neg[0], -5.0)
  let ceil = eval_calc([Float(1.1), Ceiling])
  assert_close(ceil[0], 2.0)
  let floor = eval_calc([Float(1.9), Floor])
  assert_close(floor[0], 1.0)
  let round = eval_calc([Float(1.6), Round])
  assert_close(round[0], 2.0)
  let trunc = eval_calc([Float(1.9), Truncate])
  assert_close(trunc[0], 1.0)
  let cvi = eval_calc([Float(2.9), Cvi])
  assert_close(cvi[0], 2.0)
  let cvr = eval_calc([Int(5), Cvr])
  assert_close(cvr[0], 5.0)
}

///|
test "calculator trig and log ops" {
  let sin = eval_calc([Float(90.0), Sin])
  assert_close(sin[0], 1.0)
  let cos = eval_calc([Float(0.0), Cos])
  assert_close(cos[0], 1.0)
  let atan = eval_calc([Int(1), Int(0), Atan])
  assert_close(atan[0], 0.0)
  let ln = eval_calc([Float(1.0), Ln])
  assert_close(ln[0], 0.0)
  let log = eval_calc([Float(1.0), Log])
  assert_close(log[0], 0.0)
  let sqrt = eval_calc([Int(9), Sqrt])
  assert_close(sqrt[0], 3.0)
}

///|
test "calculator stack ops" {
  let dup = eval_calc([Int(3), Dup])
  assert_eq(dup.length(), 2)
  assert_close(dup[0], 3.0)
  assert_close(dup[1], 3.0)
  let exch = eval_calc([Int(1), Int(2), Exch])
  assert_eq(exch.length(), 2)
  assert_close(exch[0], 1.0)
  assert_close(exch[1], 2.0)
  let pop = eval_calc([Int(1), Int(2), Pop])
  assert_eq(pop.length(), 1)
  assert_close(pop[0], 1.0)
  let copy = eval_calc([Int(1), Int(2), Int(3), Int(2), Copy])
  assert_eq(copy.length(), 5)
  assert_close(copy[0], 3.0)
  assert_close(copy[1], 2.0)
  assert_close(copy[2], 3.0)
  assert_close(copy[3], 2.0)
  assert_close(copy[4], 1.0)
  let index = eval_calc([Int(7), Int(8), Int(9), Int(1), Index])
  assert_eq(index.length(), 4)
  assert_close(index[0], 8.0)
  assert_close(index[1], 9.0)
  assert_close(index[2], 8.0)
  assert_close(index[3], 7.0)
  let roll = eval_calc([Int(1), Int(2), Int(3), Int(3), Int(1), Roll])
  assert_eq(roll.length(), 3)
  assert_close(roll[0], 1.0)
  assert_close(roll[1], 3.0)
  assert_close(roll[2], 2.0)
}

///|
test "calculator boolean and comparison ops" {
  let and_int = eval_calc([Int(6), Int(3), And])
  assert_close(and_int[0], 2.0)
  let or_int = eval_calc([Int(2), Int(1), Or])
  assert_close(or_int[0], 3.0)
  let xor_int = eval_calc([Int(6), Int(3), Xor])
  assert_close(xor_int[0], 5.0)
  let not_int = eval_calc([Int(0), Not])
  assert_close(not_int[0], -1.0)
  let bitshift = eval_calc([Int(1), Int(2), Bitshift])
  assert_close(bitshift[0], 1.0)
  let bitshift_neg = eval_calc([Int(-1), Int(4), Bitshift])
  assert_close(bitshift_neg[0], 2.0)
  let and_bool = eval_calc([
    Bool(true),
    Bool(false),
    And,
    IfElse([Int(1)], [Int(0)]),
  ])
  assert_close(and_bool[0], 0.0)
  let or_bool = eval_calc([
    Bool(false),
    Bool(true),
    Or,
    IfElse([Int(1)], [Int(0)]),
  ])
  assert_close(or_bool[0], 1.0)
  let xor_bool = eval_calc([
    Bool(true),
    Bool(true),
    Xor,
    IfElse([Int(1)], [Int(0)]),
  ])
  assert_close(xor_bool[0], 0.0)
  let not_bool = eval_calc([
    Bool(false),
    Bool(true),
    Not,
    IfElse([Int(1)], [Int(0)]),
  ])
  assert_close(not_bool[0], 0.0)
  let eq_true = eval_calc([Int(2), Int(2), Eq, IfElse([Int(1)], [Int(0)])])
  assert_close(eq_true[0], 1.0)
  let eq_false = eval_calc([Int(1), Float(1.0), Eq, IfElse([Int(1)], [Int(0)])])
  assert_close(eq_false[0], 0.0)
  let gt = eval_calc([Int(1), Int(2), Gt, IfElse([Int(1)], [Int(0)])])
  assert_close(gt[0], 1.0)
  let ge = eval_calc([Int(2), Int(2), Ge, IfElse([Int(1)], [Int(0)])])
  assert_close(ge[0], 1.0)
  let lt = eval_calc([Int(3), Int(2), Lt, IfElse([Int(1)], [Int(0)])])
  assert_close(lt[0], 1.0)
  let le = eval_calc([Int(2), Int(2), Le, IfElse([Int(1)], [Int(0)])])
  assert_close(le[0], 1.0)
  let ne = eval_calc([Int(1), Int(2), Ne, IfElse([Int(1)], [Int(0)])])
  assert_close(ne[0], 1.0)
  let gt_cross = eval_calc([Int(2), Float(1.0), Gt, IfElse([Int(1)], [Int(0)])])
  assert_close(gt_cross[0], 0.0)
}

///|
test "calculator if and ifelse parse" {
  let pdf = @pdf.Pdf::empty()
  let dict_if : @pdf.PdfObject = @pdf.PdfObject::Dictionary([
    (@pdf.PdfName::of_bytes("/FunctionType"), Integer(4)),
    (@pdf.PdfName::of_bytes("/Domain"), Array([])),
  ])
  let data_if = @pdfio.bytes_of_string("{ true { 5 } if }")
  let if_stream : @pdf.PdfObject = Stream(Ref::new((dict_if, Got(data_if))))
  let fun_if = PdfFunction::parse(pdf, if_stream)
  let out_if = PdfFunction::eval(fun_if, [])
  assert_eq(out_if.length(), 1)
  assert_close(out_if[0], 5.0)
  let dict_ifelse : @pdf.PdfObject = @pdf.PdfObject::Dictionary([
    (@pdf.PdfName::of_bytes("/FunctionType"), Integer(4)),
    (@pdf.PdfName::of_bytes("/Domain"), Array([])),
  ])
  let data_ifelse = @pdfio.bytes_of_string("{ false { 1 } { 2 } ifelse }")
  let ifelse_stream : @pdf.PdfObject = Stream(
    Ref::new((dict_ifelse, Got(data_ifelse))),
  )
  let fun_ifelse = PdfFunction::parse(pdf, ifelse_stream)
  let out_ifelse = PdfFunction::eval(fun_ifelse, [])
  assert_eq(out_ifelse.length(), 1)
  assert_close(out_ifelse[0], 2.0)
}

///|
test "calculator errors on bad stack usage" {
  let bad_copy : Result[Array[Double], Error] = try? eval_calc([
    Int(1),
    Int(2),
    Int(3),
    Int(5),
    Copy,
  ])
  assert_true(bad_copy is Err(_))
  let bad_index : Result[Array[Double], Error] = try? eval_calc([
    Int(1),
    Int(1),
    Index,
  ])
  assert_true(bad_index is Err(_))
  let bad_roll : Result[Array[Double], Error] = try? eval_calc([
    Int(0),
    Int(1),
    Roll,
  ])
  assert_true(bad_roll is Err(_))
}

///|
test "eval_function clamps range and rejects bad domain" {
  let clamped_fun : PdfFunction = {
    func: Calculator([Int(2)]),
    domain: [],
    range: Some([0.0, 1.0]),
  }
  let clamped = PdfFunction::eval(clamped_fun, [])
  assert_eq(clamped.length(), 1)
  assert_close(clamped[0], 1.0)
  let bad_domain : PdfFunction = {
    func: Calculator([Int(1)]),
    domain: [0.0],
    range: None,
  }
  let bad_domain_result : Result[Array[Double], Error] = try? PdfFunction::eval(
    bad_domain,
    [0.0],
  )
  assert_true(bad_domain_result is Err(_))
}

///|
test "parse function rejects bad inputs" {
  @pdfe.with_logger(_ => (), fn() {
    let pdf = @pdf.Pdf::empty()
    let bad_type : @pdf.PdfObject = @pdf.PdfObject::Dictionary([
      (@pdf.PdfName::of_bytes("/FunctionType"), Integer(9)),
      (@pdf.PdfName::of_bytes("/Domain"), Array([])),
    ])
    let bad_type_result : Result[PdfFunction, Error] = try? PdfFunction::parse(
      pdf, bad_type,
    )
    assert_true(bad_type_result is Err(_))
    let bad_calc_dict : @pdf.PdfObject = @pdf.PdfObject::Dictionary([
      (@pdf.PdfName::of_bytes("/FunctionType"), Integer(4)),
      (@pdf.PdfName::of_bytes("/Domain"), Array([])),
    ])
    let bad_calc_data = @pdfio.bytes_of_string("{ nope }")
    let bad_calc_stream : @pdf.PdfObject = Stream(
      Ref::new((bad_calc_dict, Got(bad_calc_data))),
    )
    let bad_calc_result : Result[PdfFunction, Error] = try? PdfFunction::parse(
      pdf, bad_calc_stream,
    )
    assert_true(bad_calc_result is Err(_))
    let sampled_dict : @pdf.PdfObject = @pdf.PdfObject::Dictionary([
      (@pdf.PdfName::of_bytes("/FunctionType"), Integer(0)),
      (@pdf.PdfName::of_bytes("/Domain"), Array([Real(0.0), Real(1.0)])),
      (@pdf.PdfName::of_bytes("/Size"), Array([Integer(2)])),
      (@pdf.PdfName::of_bytes("/BitsPerSample"), Integer(1)),
    ])
    let sampled_data = @pdfio.bytes_of_list([0, 1])
    let sampled_stream : @pdf.PdfObject = Stream(
      Ref::new((sampled_dict, Got(sampled_data))),
    )
    let sampled_result : Result[PdfFunction, Error] = try? PdfFunction::parse(
      pdf, sampled_stream,
    )
    assert_true(sampled_result is Err(_))
  })
}

///|
test "PdfFunction::print covers extra calculator strings" {
  @pdfe.with_logger(_ => (), fn() {
    let fun : PdfFunction = {
      func: Calculator([
        Cvi,
        Cvr,
        Div,
        Exp,
        Floor,
        Idiv,
        Ln,
        Log,
        Mod,
        Mul,
        Truncate,
        And,
        Bitshift,
        Eq,
        Ge,
        Gt,
        Le,
        Lt,
        Ne,
        Not,
        Or,
        Xor,
        Copy,
        Exch,
        Pop,
        Dup,
      ]),
      domain: [],
      range: None,
    }
    fun.print()
  })
}

///|
test "parse calculator keywords covers remaining ops" {
  let pdf = @pdf.Pdf::empty()
  let dict : @pdf.PdfObject = @pdf.PdfObject::Dictionary([
    (@pdf.PdfName::of_bytes("/FunctionType"), Integer(4)),
    (@pdf.PdfName::of_bytes("/Domain"), Array([])),
  ])
  let data = @pdfio.bytes_of_string(
    "{ cvi cvr div exp floor idiv ln log mod mul truncate and bitshift eq ge gt le lt ne not or xor copy exch pop dup index roll }",
  )
  let stream : @pdf.PdfObject = Stream(Ref::new((dict, Got(data))))
  let fun = PdfFunction::parse(pdf, stream)
  match (fun.func : PdfFunctionKind) {
    Calculator(ops) => assert_true(ops.length() > 0)
    _ => fail("expected calculator function")
  }
}

///|
test "sampled function covers size multiplication" {
  let fun : PdfFunction = {
    func: Sampled({
      size: [2, 2],
      order: 1,
      encode: [0.0, 1.0, 0.0, 1.0],
      decode: [0.0, 1.0],
      bps: 8,
      samples: [0, 255, 255, 0],
    }),
    domain: [0.0, 1.0, 0.0, 1.0],
    range: Some([0.0, 1.0]),
  }
  let out = PdfFunction::eval(fun, [0.5, 0.5])
  assert_eq(out.length(), 1)
}

///|
test "sampled function errors on incompatible size" {
  let fun : PdfFunction = {
    func: Sampled({
      size: [2, 2],
      order: 1,
      encode: [0.0, 1.0, 0.0, 1.0],
      decode: [0.0, 1.0],
      bps: 8,
      samples: [0, 255, 255, 0],
    }),
    domain: [0.0, 1.0],
    range: Some([0.0, 1.0]),
  }
  assert_is_err(try? PdfFunction::eval(fun, [0.5]))
}

///|
test "sampled function errors on missing range" {
  let fun : PdfFunction = {
    func: Sampled({
      size: [2],
      order: 1,
      encode: [0.0, 1.0],
      decode: [0.0, 1.0],
      bps: 8,
      samples: [0, 255],
    }),
    domain: [0.0, 1.0],
    range: None,
  }
  assert_is_err(try? PdfFunction::eval(fun, [0.5]))
}

///|
test "sampled function errors on bad encode length" {
  let fun : PdfFunction = {
    func: Sampled({
      size: [2],
      order: 1,
      encode: [0.0, 1.0, 2.0],
      decode: [0.0, 1.0],
      bps: 8,
      samples: [0, 255],
    }),
    domain: [0.0, 1.0],
    range: Some([0.0, 1.0]),
  }
  assert_is_err(try? PdfFunction::eval(fun, [0.5]))
}

///|
test "eval_function rejects bad domain length" {
  let fun : PdfFunction = {
    func: Calculator([Int(1)]),
    domain: [0.0, 1.0],
    range: None,
  }
  assert_is_err(try? PdfFunction::eval(fun, [0.5, 0.5]))
}

///|
test "clamp_double clamps to min" {
  let fun : PdfFunction = {
    func: Calculator([Int(-1)]),
    domain: [],
    range: Some([0.0, 1.0]),
  }
  let out = PdfFunction::eval(fun, [])
  assert_close(out[0], 0.0)
}

///|
test "calculator type error cases" {
  assert_is_err(try? eval_calc([Add]))
  assert_is_err(try? eval_calc([Int(1), If([Int(1)])]))
  assert_is_err(try? eval_calc([Bool(true), Sin]))
  assert_is_err(try? eval_calc([Float(1.0), Int(2), Idiv]))
}

///|
test "calculator abs/add branches and ceiling int" {
  let abs_int = eval_calc([Int(-3), Abs])
  assert_close(abs_int[0], 3.0)
  let add_ff = eval_calc([Float(1.0), Float(2.0), Add])
  assert_close(add_ff[0], 3.0)
  let add_if = eval_calc([Int(1), Float(2.0), Add])
  assert_close(add_if[0], 3.0)
  let add_fi = eval_calc([Float(1.0), Int(2), Add])
  assert_close(add_fi[0], 3.0)
  let ceil_int = eval_calc([Int(3), Ceiling])
  assert_close(ceil_int[0], 3.0)
}

///|
test "calculator comparisons over bool and floats" {
  let bool_eq = eval_calc([
    Bool(true),
    Bool(true),
    Eq,
    IfElse([Int(1)], [Int(0)]),
  ])
  assert_close(bool_eq[0], 1.0)
  let bool_gt = eval_calc([
    Bool(false),
    Bool(true),
    Gt,
    IfElse([Int(1)], [Int(0)]),
  ])
  assert_close(bool_gt[0], 1.0)
  let bool_lt = eval_calc([
    Bool(true),
    Bool(false),
    Lt,
    IfElse([Int(1)], [Int(0)]),
  ])
  assert_close(bool_lt[0], 1.0)
  let float_lt = eval_calc([
    Float(2.0),
    Float(1.0),
    Lt,
    IfElse([Int(1)], [Int(0)]),
  ])
  assert_close(float_lt[0], 1.0)
  let float_gt = eval_calc([
    Float(1.0),
    Float(2.0),
    Gt,
    IfElse([Int(1)], [Int(0)]),
  ])
  assert_close(float_gt[0], 1.0)
  let float_eq = eval_calc([
    Float(1.0),
    Float(1.0),
    Ge,
    IfElse([Int(1)], [Int(0)]),
  ])
  assert_close(float_eq[0], 1.0)
}

///|
test "calculator comparisons across types" {
  let bool_int = eval_calc([Int(1), Bool(false), Lt, IfElse([Int(1)], [Int(0)])])
  assert_close(bool_int[0], 1.0)
  let float_int = eval_calc([Int(2), Float(1.0), Lt, IfElse([Int(1)], [Int(0)])])
  assert_close(float_int[0], 1.0)
  let float_bool = eval_calc([
    Bool(false),
    Float(1.0),
    Gt,
    IfElse([Int(1)], [Int(0)]),
  ])
  assert_close(float_bool[0], 1.0)
  let int_bool = eval_calc([Bool(false), Int(1), Gt, IfElse([Int(1)], [Int(0)])])
  assert_close(int_bool[0], 1.0)
}

///|
test "parse_function hits error branches" {
  let pdf = @pdf.Pdf::empty()
  let bad_domain : @pdf.PdfObject = @pdf.PdfObject::Dictionary([
    (@pdf.PdfName::of_bytes("/FunctionType"), Integer(2)),
    (@pdf.PdfName::of_bytes("/Domain"), Integer(1)),
    (@pdf.PdfName::of_bytes("/N"), Real(1.0)),
  ])
  assert_is_err(try? PdfFunction::parse(pdf, bad_domain))
  let bad_size : @pdf.PdfObject = @pdf.PdfObject::Dictionary([
    (@pdf.PdfName::of_bytes("/FunctionType"), Integer(0)),
    (@pdf.PdfName::of_bytes("/Domain"), Array([])),
    (@pdf.PdfName::of_bytes("/Size"), Array([Real(2.0)])),
    (@pdf.PdfName::of_bytes("/BitsPerSample"), Integer(8)),
  ])
  assert_is_err(try? PdfFunction::parse(pdf, bad_size))
  let bad_size_type : @pdf.PdfObject = @pdf.PdfObject::Dictionary([
    (@pdf.PdfName::of_bytes("/FunctionType"), Integer(0)),
    (@pdf.PdfName::of_bytes("/Domain"), Array([])),
    (@pdf.PdfName::of_bytes("/Size"), Integer(1)),
    (@pdf.PdfName::of_bytes("/BitsPerSample"), Integer(8)),
  ])
  assert_is_err(try? PdfFunction::parse(pdf, bad_size_type))
  let bad_bps : @pdf.PdfObject = @pdf.PdfObject::Dictionary([
    (@pdf.PdfName::of_bytes("/FunctionType"), Integer(0)),
    (@pdf.PdfName::of_bytes("/Domain"), Array([])),
    (@pdf.PdfName::of_bytes("/Size"), Array([Integer(2)])),
    (@pdf.PdfName::of_bytes("/BitsPerSample"), Name(PdfName("/Bad"))),
  ])
  assert_is_err(try? PdfFunction::parse(pdf, bad_bps))
  let to_get = @pdf.ToGet::new(@pdfio.Input::of_string("x"), 0, 1)
  let sample_dict : @pdf.PdfObject = @pdf.PdfObject::Dictionary([
    (@pdf.PdfName::of_bytes("/FunctionType"), Integer(0)),
    (@pdf.PdfName::of_bytes("/Domain"), Array([])),
    (@pdf.PdfName::of_bytes("/Size"), Array([Integer(1)])),
    (@pdf.PdfName::of_bytes("/BitsPerSample"), Integer(8)),
    (@pdf.PdfName::of_bytes("/Decode"), Array([Real(0.0)])),
  ])
  let sample_stream : @pdf.PdfObject = Stream(
    Ref::new((sample_dict, ToGet(to_get))),
  )
  assert_is_err(try? PdfFunction::parse(pdf, sample_stream))
  let calc_dict : @pdf.PdfObject = @pdf.PdfObject::Dictionary([
    (@pdf.PdfName::of_bytes("/FunctionType"), Integer(4)),
    (@pdf.PdfName::of_bytes("/Domain"), Array([])),
  ])
  let calc_stream : @pdf.PdfObject = Stream(
    Ref::new((calc_dict, ToGet(to_get))),
  )
  assert_is_err(try? PdfFunction::parse(pdf, calc_stream))
  let bad_functions : @pdf.PdfObject = @pdf.PdfObject::Dictionary([
    (@pdf.PdfName::of_bytes("/FunctionType"), Integer(3)),
    (@pdf.PdfName::of_bytes("/Domain"), Array([])),
    (@pdf.PdfName::of_bytes("/Functions"), Integer(1)),
    (@pdf.PdfName::of_bytes("/Bounds"), Array([])),
    (@pdf.PdfName::of_bytes("/Encode"), Array([])),
  ])
  assert_is_err(try? PdfFunction::parse(pdf, bad_functions))
  let bad_bounds : @pdf.PdfObject = @pdf.PdfObject::Dictionary([
    (@pdf.PdfName::of_bytes("/FunctionType"), Integer(3)),
    (@pdf.PdfName::of_bytes("/Domain"), Array([])),
    (@pdf.PdfName::of_bytes("/Functions"), Array([])),
    (@pdf.PdfName::of_bytes("/Bounds"), Integer(1)),
    (@pdf.PdfName::of_bytes("/Encode"), Array([])),
  ])
  assert_is_err(try? PdfFunction::parse(pdf, bad_bounds))
  let bad_encode : @pdf.PdfObject = @pdf.PdfObject::Dictionary([
    (@pdf.PdfName::of_bytes("/FunctionType"), Integer(3)),
    (@pdf.PdfName::of_bytes("/Domain"), Array([])),
    (@pdf.PdfName::of_bytes("/Functions"), Array([])),
    (@pdf.PdfName::of_bytes("/Bounds"), Array([])),
    (@pdf.PdfName::of_bytes("/Encode"), Integer(1)),
  ])
  assert_is_err(try? PdfFunction::parse(pdf, bad_encode))
}

///|
test "stitching eval errors on encode length" {
  let f : PdfFunction = {
    func: Calculator([Int(1)]),
    domain: [0.0, 1.0],
    range: None,
  }
  let fun : PdfFunction = {
    func: Stitching({ functions: [f], bounds: [0.5], stitch_encode: [] }),
    domain: [0.0, 1.0],
    range: None,
  }
  assert_is_err(try? PdfFunction::eval(fun, [0.25]))
}
