///|
fn value_equal(a : Calculator, b : Calculator) -> Bool {
  match (a, b) {
    (Bool(x), Bool(y)) => x == y
    (Float(x), Float(y)) => x == y
    (Int(x), Int(y)) => x == y
    _ => false
  }
}

///|
fn value_compare(
  a : Calculator,
  b : Calculator,
) -> Int raise BadFunctionEvaluation {
  match (a, b) {
    (Bool(x), Bool(y)) => if x == y { 0 } else if x { 1 } else { -1 }
    (Float(x), Float(y)) => if x < y { -1 } else if x > y { 1 } else { 0 }
    (Int(x), Int(y)) => if x < y { -1 } else if x > y { 1 } else { 0 }
    (Bool(_), _) => -1
    (Float(_), Int(_)) => -1
    (Float(_), Bool(_)) => 1
    (Int(_), _) => 1
    _ => raise Msg("Type error")
  }
}

///|
fn pop_value(
  stack : Array[Calculator],
) -> Calculator raise BadFunctionEvaluation {
  match stack.pop() {
    Some(value) => value
    None => raise Msg("Type error")
  }
}

///|
fn pop_float(stack : Array[Calculator]) -> Double raise BadFunctionEvaluation {
  match pop_value(stack) {
    Float(f) => f
    Int(i) => i.to_double()
    _ => raise Msg("Type error")
  }
}

///|
fn pop_int(stack : Array[Calculator]) -> Int raise BadFunctionEvaluation {
  match pop_value(stack) {
    Int(i) => i
    _ => raise Msg("Type error")
  }
}

///|
fn pop_bool(stack : Array[Calculator]) -> Bool raise BadFunctionEvaluation {
  match pop_value(stack) {
    Bool(b) => b
    _ => raise Msg("Type error")
  }
}

///|
fn eval_function_calculator(
  clamped_inputs : Array[Double],
  ops : Array[Calculator],
) -> Array[Double] raise BadFunctionEvaluation {
  let stack = Array::new()
  for idx in (clamped_inputs.length() - 1)>=..0 {
    stack.push(Calculator::Float(clamped_inputs[idx]))
  }
  fn eval(
    op : Calculator,
    stack : Array[Calculator],
  ) -> Unit raise BadFunctionEvaluation {
    match op {
      If(body) => {
        let cond = pop_bool(stack)
        if cond {
          for inner in body {
            eval(inner, stack)
          }
        }
      }
      IfElse(a, b) => {
        let cond = pop_bool(stack)
        let body = if cond { a } else { b }
        for inner in body {
          eval(inner, stack)
        }
      }
      Bool(_) | Float(_) | Int(_) => stack.push(op)
      Abs =>
        match pop_value(stack) {
          Float(f) => stack.push(Float(f.abs()))
          Int(i) => stack.push(Int(i.abs()))
          _ => raise Msg("Type error")
        }
      Add => {
        let a = pop_value(stack)
        let b = pop_value(stack)
        match (a, b) {
          (Int(x), Int(y)) => stack.push(Int(x + y))
          (Float(x), Float(y)) => stack.push(Float(x + y))
          (Int(x), Float(y)) => stack.push(Float(x.to_double() + y))
          (Float(x), Int(y)) => stack.push(Float(x + y.to_double()))
          _ => raise Msg("Type error")
        }
      }
      Atan => {
        let num = pop_float(stack)
        let den = pop_float(stack)
        stack.push(Float(@math.atan2(num, den)))
      }
      Ceiling =>
        match pop_value(stack) {
          Float(f) => stack.push(Float(f.ceil()))
          Int(i) => stack.push(Int(i))
          _ => raise Msg("Type error")
        }
      Cos => {
        let f = pop_float(stack)
        stack.push(Float(@math.cos(rad_of_deg(f))))
      }
      Cvi =>
        match pop_value(stack) {
          Float(f) => stack.push(Int(f.floor().to_int()))
          Int(i) => stack.push(Int(i))
          _ => raise Msg("Type error")
        }
      Cvr =>
        match pop_value(stack) {
          Int(i) => stack.push(Float(i.to_double()))
          Float(f) => stack.push(Float(f))
          _ => raise Msg("Type error")
        }
      Div => {
        let n = pop_float(stack)
        let d = pop_float(stack)
        stack.push(Float(n / d))
      }
      Exp => {
        let bse = pop_float(stack)
        let exp = pop_float(stack)
        stack.push(Float(@math.pow(bse, exp)))
      }
      Floor =>
        match pop_value(stack) {
          Float(f) => stack.push(Int(f.floor().to_int()))
          Int(i) => stack.push(Int(i))
          _ => raise Msg("Type error")
        }
      Idiv => {
        let a = pop_int(stack)
        let b = pop_int(stack)
        stack.push(Int(a / b))
      }
      Ln => {
        let f = pop_float(stack)
        stack.push(Float(@math.ln(f)))
      }
      Log => {
        let f = pop_float(stack)
        stack.push(Float(@math.log10(f)))
      }
      Mod => {
        let a = pop_int(stack)
        let b = pop_int(stack)
        stack.push(Int(a % b))
      }
      Mul => {
        let a = pop_value(stack)
        let b = pop_value(stack)
        match (a, b) {
          (Int(x), Int(y)) => stack.push(Int(x * y))
          (Float(x), Float(y)) => stack.push(Float(x * y))
          (Int(x), Float(y)) => stack.push(Float(x.to_double() * y))
          (Float(x), Int(y)) => stack.push(Float(x * y.to_double()))
          _ => raise Msg("Type error")
        }
      }
      Neg =>
        match pop_value(stack) {
          Float(f) => stack.push(Float(-f))
          Int(i) => stack.push(Int(-i))
          _ => raise Msg("Type error")
        }
      Round =>
        match pop_value(stack) {
          Float(f) => stack.push(Int(f.round().to_int()))
          Int(i) => stack.push(Int(i))
          _ => raise Msg("Type error")
        }
      Sin => {
        let f = pop_float(stack)
        stack.push(Float(@math.sin(rad_of_deg(f))))
      }
      Sqrt => {
        let f = pop_float(stack)
        stack.push(Float(f.sqrt()))
      }
      Sub => {
        let a = pop_value(stack)
        let b = pop_value(stack)
        match (a, b) {
          (Int(x), Int(y)) => stack.push(Int(y - x))
          (Float(x), Float(y)) => stack.push(Float(y - x))
          (Int(x), Float(y)) => stack.push(Float(y - x.to_double()))
          (Float(x), Int(y)) => stack.push(Float(y.to_double() - x))
          _ => raise Msg("Type error")
        }
      }
      Truncate =>
        match pop_value(stack) {
          Float(f) => stack.push(Int(f.to_int()))
          Int(i) => stack.push(Int(i))
          _ => raise Msg("Type error")
        }
      And => {
        let a = pop_value(stack)
        let b = pop_value(stack)
        match (a, b) {
          (Int(x), Int(y)) => stack.push(Int(Int::land(x, y)))
          (Bool(x), Bool(y)) => stack.push(Bool(x && y))
          _ => raise Msg("Type error")
        }
      }
      Bitshift => {
        let i = pop_int(stack)
        let shift = pop_int(stack)
        let result = if i < 0 {
          i << shift
        } else {
          let u = i.reinterpret_as_uint()
          let shifted = u >> (if shift < 0 { -shift } else { shift })
          shifted.reinterpret_as_int()
        }
        stack.push(Int(result))
      }
      Eq => {
        let a = pop_value(stack)
        let b = pop_value(stack)
        stack.push(Bool(value_equal(a, b)))
      }
      Ge => {
        let a = pop_value(stack)
        let b = pop_value(stack)
        stack.push(Bool(value_compare(a, b) >= 0))
      }
      Gt => {
        let a = pop_value(stack)
        let b = pop_value(stack)
        stack.push(Bool(value_compare(a, b) > 0))
      }
      Le => {
        let a = pop_value(stack)
        let b = pop_value(stack)
        stack.push(Bool(value_compare(a, b) <= 0))
      }
      Lt => {
        let a = pop_value(stack)
        let b = pop_value(stack)
        stack.push(Bool(value_compare(a, b) < 0))
      }
      Ne => {
        let a = pop_value(stack)
        let b = pop_value(stack)
        stack.push(Bool(!value_equal(a, b)))
      }
      Not =>
        match pop_value(stack) {
          Int(i) => stack.push(Int(Int::lnot(i)))
          Bool(b) => {
            let _ = pop_bool(stack)
            stack.push(Bool(!b))
          }
          _ => raise Msg("Type error")
        }
      Or => {
        let a = pop_value(stack)
        let b = pop_value(stack)
        match (a, b) {
          (Int(x), Int(y)) => stack.push(Int(Int::lor(x, y)))
          (Bool(x), Bool(y)) => stack.push(Bool(x || y))
          _ => raise Msg("Type error")
        }
      }
      Xor => {
        let a = pop_value(stack)
        let b = pop_value(stack)
        match (a, b) {
          (Int(x), Int(y)) => stack.push(Int(Int::lxor(x, y)))
          (Bool(x), Bool(y)) => stack.push(Bool((x || y) && !(x && y)))
          _ => raise Msg("Type error")
        }
      }
      Copy =>
        match pop_value(stack) {
          Int(i) if i >= 0 => {
            let count = i
            let original_len = stack.length()
            let start = original_len - count
            if start < 0 {
              raise Msg("Type error")
            }
            let slice = stack[start:original_len].to_array()
            for value in slice {
              stack.push(value)
            }
          }
          _ => raise Msg("Type error")
        }
      Exch => {
        let a = pop_value(stack)
        let b = pop_value(stack)
        stack.push(a)
        stack.push(b)
      }
      Pop => {
        let _ = pop_value(stack)
      }
      Dup => {
        let a = pop_value(stack)
        stack.push(a)
        stack.push(a)
      }
      Index =>
        match pop_value(stack) {
          Int(i) if i >= 0 => {
            let idx = stack.length() - 1 - i
            if idx < 0 || idx >= stack.length() {
              raise Msg("Type error")
            }
            stack.push(stack[idx])
          }
          _ => raise Msg("Type error")
        }
      Roll => {
        let j = pop_int(stack)
        let n = pop_int(stack)
        if n < 1 {
          raise Msg("Type error")
        }
        let count = n
        let start = stack.length() - count
        if start < 0 {
          raise Msg("Type error")
        }
        let slice = stack[start:].to_array()
        stack.truncate(start)
        let mut rotated = Array::new(capacity=slice.length())
        if j > 0 {
          for k in 0..<slice.length() {
            rotated.push(slice[(k + j) % slice.length()])
          }
        } else if j < 0 {
          let shift = -j
          for k in 0..<slice.length() {
            rotated.push(
              slice[(k + slice.length() - shift % slice.length()) %
              slice.length()],
            )
          }
        } else {
          rotated = slice
        }
        for value in rotated {
          stack.push(value)
        }
      }
    }
  }

  for op in ops {
    eval(op, stack)
  }
  let out = Array::new(capacity=stack.length())
  for i in (stack.length() - 1)>=..0 {
    match stack[i] {
      Float(x) => out.push(x)
      Int(i) => out.push(i.to_double())
      _ => raise Msg("Type 4-a")
    }
  }
  out
}
