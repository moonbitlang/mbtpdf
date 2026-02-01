///|
fn encrypt_pdf_128bit_inner(
  owner : String,
  user : String,
  p : Int,
  user_pw : String,
  id : String,
  pdf : @pdf.Pdf,
) -> @pdf.Pdf raise {
  let crypt_dict = @pdf.PdfObject::Dictionary([
    (@pdf.n("/Filter"), Name(PdfName("/Standard"))),
    (@pdf.n("/V"), Integer(2)),
    (@pdf.n("/R"), Integer(3)),
    (@pdf.n("/O"), String(owner)),
    (@pdf.n("/U"), String(user)),
    (@pdf.n("/Length"), Integer(128)),
    (@pdf.n("/P"), Integer(p)),
  ])
  match
    process_cryption(
      false,
      true,
      pdf,
      ARC4(128, 3),
      user_pw,
      3,
      user,
      owner,
      p,
      id,
      128,
      None,
    ) {
    Some(pdf_val) => {
      let crypt_dict_num = pdf_val.addobj(crypt_dict)
      pdf_val.trailerdict = pdf_val.trailerdict.add_entry(
        "/Encrypt",
        Indirect(crypt_dict_num),
      )
      pdf_val
    }
    None => raise @pdf.PdfError::Msg("Encryption 128 failed")
  }
}

///|
fn encrypt_pdf_128bit_inner_r4(
  owner : String,
  user : String,
  p : Int,
  user_pw : String,
  id : String,
  pdf : @pdf.Pdf,
  encrypt_metadata : Bool,
) -> @pdf.Pdf raise {
  let crypt_dict = @pdf.PdfObject::Dictionary([
    (@pdf.n("/Filter"), Name(PdfName("/Standard"))),
    (@pdf.n("/V"), Integer(4)),
    (
      @pdf.n("/CF"),
      @pdf.PdfObject::Dictionary([
        (
          @pdf.n("/StdCF"),
          @pdf.PdfObject::Dictionary([
            (@pdf.n("/Length"), Integer(16)),
            (@pdf.n("/AuthEvent"), Name(PdfName("/DocOpen"))),
            (@pdf.n("/CFM"), Name(PdfName("/V2"))),
          ]),
        ),
      ]),
    ),
    (@pdf.n("/EncryptMetadata"), Boolean(encrypt_metadata)),
    (@pdf.n("/Length"), Integer(128)),
    (@pdf.n("/R"), Integer(4)),
    (@pdf.n("/O"), String(owner)),
    (@pdf.n("/U"), String(user)),
    (@pdf.n("/P"), Integer(p)),
    (@pdf.n("/StrF"), Name(PdfName("/StdCF"))),
    (@pdf.n("/StmF"), Name(PdfName("/StdCF"))),
  ])
  match
    process_cryption(
      !encrypt_metadata,
      true,
      pdf,
      ARC4(128, 4),
      user_pw,
      4,
      user,
      owner,
      p,
      id,
      128,
      None,
    ) {
    Some(pdf_val) => {
      let crypt_dict_num = pdf_val.addobj(crypt_dict)
      pdf_val.trailerdict = pdf_val.trailerdict.add_entry(
        "/Encrypt",
        Indirect(crypt_dict_num),
      )
      pdf_val
    }
    None => raise @pdf.PdfError::Msg("Encryption 128 r4 failed")
  }
}

///|
/// Encrypt a PDF document using 128-bit encryption.
pub fn PdfCrypt::encrypt_pdf_128bit(
  _self : PdfCrypt,
  user_pw : String,
  owner_pw : String,
  banlist : Array[Permission],
  pdf : @pdf.Pdf,
) -> @pdf.Pdf raise {
  let p = p_of_banlist(banlist)
  let owner = mk_owner(3, owner_pw, user_pw, 128)
  let (id, pdf_updated) = get_or_add_id(pdf)
  let user = mk_user(false, user_pw, owner, p, id, 3, 128)
  encrypt_pdf_128bit_inner(owner, user, p, user_pw, id, pdf_updated)
}
