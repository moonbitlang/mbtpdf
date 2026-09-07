///|
/// PDF whitespace predicate.
pub fn is_whitespace(c : Char) -> Bool {
  let v = c.to_int()
  v == 0 || v == 9 || v == 10 || v == 12 || v == 13 || v == 32
}

///|
fn is_not_whitespace(c : Char) -> Bool {
  !is_whitespace(c)
}

///|
pub fn is_newline(c : Char) -> Bool {
  c is ('\n' | '\r')
}

///|
pub fn is_delimiter(c : Char) -> Bool {
  c is ('(' | ')' | '<' | '>' | '[' | ']' | '{' | '}' | '%' | '/')
}

///|
pub fn is_whitespace_or_delimiter(c : Char) -> Bool {
  is_whitespace(c) || is_delimiter(c)
}

///|
/// Read chars until whitespace or delimiter.
pub fn Input::getuntil_white_or_delimiter_string(self : Input) -> String raise {
  self.getuntil_string(true, c => is_whitespace_or_delimiter(c))
}

///|
/// Read chars until predicate is true.
pub fn Input::getuntil(
  self : Input,
  eof_is_delimiter : Bool,
  pred : (Char) -> Bool,
) -> Array[Char] raise {
  let out = Array()
  let mut done = false
  while !done {
    let b = (self.input_byte)()
    if b == no_more {
      if eof_is_delimiter {
        done = true
      } else {
        fail("End_of_file")
      }
    } else {
      let c = b.to_byte().to_char()
      if pred(c) {
        self.rewind()
        done = true
      } else {
        out.push(c)
      }
    }
  }
  out
}

///|
/// Read chars until predicate is true, returning a string.
pub fn Input::getuntil_string(
  self : Input,
  eof_is_delimiter : Bool,
  pred : (Char) -> Bool,
) -> String raise {
  let sb = StringBuilder()
  let mut done = false
  while !done {
    let b = (self.input_byte)()
    if b == no_more {
      if eof_is_delimiter {
        done = true
      } else {
        fail("End_of_file")
      }
    } else {
      let c = b.to_byte().to_char()
      if pred(c) {
        self.rewind()
        done = true
      } else {
        sb.write_char(c)
      }
    }
  }
  sb.to_string()
}

///|
/// Ignore chars until predicate is true.
pub fn Input::ignoreuntil(
  self : Input,
  eof_is_delimiter : Bool,
  pred : (Char) -> Bool,
) -> Unit raise {
  let mut done = false
  while !done {
    let b = (self.input_byte)()
    if b == no_more {
      if eof_is_delimiter {
        done = true
      } else {
        fail("End_of_file")
      }
    } else {
      let c = b.to_byte().to_char()
      if pred(c) {
        self.rewind()
        done = true
      }
    }
  }
}

///|
/// Drop PDF whitespace.
pub fn Input::dropwhite(self : Input) -> Unit raise {
  self.ignoreuntil(true, is_not_whitespace)
}

///|
/// Read a line from input (newline not included).
///
/// Unlike `Input::read_line`, this returns `""` at EOF instead of raising.
pub fn Input::input_line(self : Input) -> String {
  let sb = StringBuilder()
  let mut got_eol = false
  let mut finished = false
  while !finished {
    let b = (self.input_byte)()
    if b == no_more {
      finished = true
    } else {
      let c = b.to_byte().to_char()
      if is_newline(c) {
        got_eol = true
      } else if got_eol {
        self.rewind()
        finished = true
      } else {
        sb.write_char(c)
      }
    }
  }
  sb.to_string()
}

///|
/// Read back until predicate is true.
fn read_back_until(pred : (Char) -> Bool, input : Input) -> Unit raise {
  match input.read_char_back() {
    Some(ch) => if !pred(ch) { read_back_until(pred, input) }
    None => fail("End_of_file")
  }
}

///|
/// Go back one line.
pub fn Input::backline(self : Input) -> Unit raise {
  read_back_until(is_newline, self)
  read_back_until(c => !is_newline(c), self)
  read_back_until(is_newline, self)
  self.nudge()
}

///|
/// Read `count` characters from `input` without advancing the cursor.
pub fn Input::read_chunk(self : Input, count : Int) -> String raise {
  let pos = (self.pos_in)()
  let sb = StringBuilder()
  let mut i = 0
  while i < count {
    match (self.input_char)() {
      Some(ch) => sb.write_char(ch)
      None => {
        (self.seek_in)(pos)
        fail("read_chunk")
      }
    }
    i = i + 1
  }
  (self.seek_in)(pos)
  sb.to_string()
}
