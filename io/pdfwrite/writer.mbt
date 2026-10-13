///|
pub struct PdfWrite {
  // Where warnings/debug output go during writing. Default is @pdfe.logger.val.
  logger : (String) -> Unit
}

///|
pub fn PdfWrite::new(logger~ : (String) -> Unit = @pdfe.logger.val) -> PdfWrite {
  { logger, }
}

///|
pub struct PdfWriteOptions {
  preserve_objstm : Bool
  generate_objstm : Bool
  compress_objstm : Bool
  recrypt : String?
  encryption : Encryption?
  build_new_id : Bool
}

///|
pub fn PdfWriteOptions::default() -> PdfWriteOptions {
  {
    preserve_objstm: false,
    generate_objstm: false,
    compress_objstm: false,
    recrypt: None,
    encryption: None,
    build_new_id: false,
  }
}

///|
type PdfObject = @pdf.PdfObject
