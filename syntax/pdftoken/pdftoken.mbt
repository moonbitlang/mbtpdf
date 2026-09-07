///|
/// Shared token vocabulary for PDF lexing/parsing.
///
/// This package intentionally contains only the token definitions (no lexer).
/// Different syntaxes can tokenize into this enum when it makes sense to share
/// downstream parsing/printing logic.
pub(all) enum Token {
  LexNull
  LexBool(Bool)
  LexInt(Int)
  LexReal(Double)
  LexString(String)
  LexName(String)
  LexLeftSquare
  LexRightSquare
  LexLeftDict
  LexRightDict
  LexStream(@pdf.Stream)
  LexEndStream
  LexObj
  LexEndObj
  LexR
  LexComment(String)
  StopLexing
  LexNone
} derive(Debug)

// Explicit method promotion for derived/implemented traits.
// (Previously implicit; see warning [0079] implicit_impl_as_method.)

///|
pub extend Token with Debug::{to_repr}
