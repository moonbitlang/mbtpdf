///|
/// Parsing PDF graphics content stream operators.
///
pub(all) enum Op {
  Opw(Double)
  OpJ(Int)
  Opj(Int)
  OpM(Double)
  Opd(Array[Double], Double)
  Opri(String)
  Opi(Int)
  Opgs(String)
  Opq
  OpQ
  Opcm(@pdftransform.TransformMatrix)
  Opm(Double, Double)
  Opl(Double, Double)
  Opc(Double, Double, Double, Double, Double, Double)
  Opv(Double, Double, Double, Double)
  Opy(Double, Double, Double, Double)
  Oph
  Opre(Double, Double, Double, Double)
  OpS
  Ops
  Opf
  OpF
  OpfStar
  OpB
  OpBStar
  Opb
  OpbStar
  Opn
  OpW
  OpWStar
  OpBT
  OpET
  OpTc(Double)
  OpTw(Double)
  OpTz(Double)
  OpTL(Double)
  OpTf(String, Double)
  OpTr(Int)
  OpTs(Double)
  OpTd(Double, Double)
  OpTD(Double, Double)
  OpTm(@pdftransform.TransformMatrix)
  OpTStar
  OpTj(String)
  OpTJ(@pdf.PdfObject)
  OpSingleQuote(String)
  OpDoubleQuote(Double, Double, String)
  Opd0(Double, Double)
  Opd1(Double, Double, Double, Double, Double, Double)
  OpCS(String)
  Opcs(String)
  OpSC(Array[Double])
  Opsc(Array[Double])
  OpSCN(Array[Double])
  Opscn(Array[Double])
  OpSCNName(String, Array[Double])
  OpscnName(String, Array[Double])
  OpG(Double)
  Opg(Double)
  OpRG(Double, Double, Double)
  Oprg(Double, Double, Double)
  OpK(Double, Double, Double, Double)
  Opk(Double, Double, Double, Double)
  Opsh(String)
  InlineImage((@pdf.PdfObject, @pdf.PdfObject?, Array[Byte]))
  OpDo(String)
  OpMP(String)
  OpDP(String, @pdf.PdfObject)
  OpBMC(String)
  OpBDC(String, @pdf.PdfObject)
  OpEMC
  OpBX
  OpEX
  OpUnknown(String)
  OpComment(String)
} derive(Debug)

///|
type PdfObject = @pdf.PdfObject

///|
type Token = @pdftoken.Token

///|
priv enum Lexeme {
  Op(String)
  Obj(Token)
  PdfObj(PdfObject)
  LexInlineImage((PdfObject, PdfObject?, Array[Byte]))
  LexComment
}

///|
priv suberror LexingEnd

///|
priv suberror CouldntHandleContent

///|
let write_comments : Ref[Bool] = { val: false, }

///|
let whitespace : Ref[String] = { val: " ", }

///|
let always_add_whitespace : Ref[Bool] = { val: false, }

///|
/// Begin a marked-content section tagged as `/Artifact`.
///
/// Many PDF producers mark decorative / non-semantic drawing as artifacts so
/// downstream processors (accessibility, reflow, text extraction) can ignore it.
pub let begin_artifact : Op = OpBMC("/Artifact")

///|
/// End a marked-content section (pairs with `begin_artifact`).
pub let end_artifact : Op = OpEMC

// Explicit method promotion for derived/implemented traits.
// (Previously implicit; see warning [0079] implicit_impl_as_method.)

///|
pub extend Op with Debug::{to_repr}
