///|
fn encrypt_pdf_AES_inner(
  owner : String,
  user : String,
  p : Int,
  user_pw : String,
  id : String,
  encrypt_metadata : Bool,
  pdf : @pdf.Pdf,
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
            (@pdf.n("/CFM"), Name(PdfName("/AESV2"))),
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
      AESV2,
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
    None => raise @pdf.PdfError::Msg("Encryption AES failed")
  }
}

///|
/// Encrypt a PDF document using AES V2.
pub fn PdfCrypt::encrypt_pdf_AES(
  _self : PdfCrypt,
  encrypt_metadata : Bool,
  user_pw : String,
  owner_pw : String,
  banlist : Array[Permission],
  pdf : @pdf.Pdf,
) -> @pdf.Pdf raise {
  let p = p_of_banlist(banlist)
  let owner = mk_owner(4, owner_pw, user_pw, 128)
  let (id, pdf_updated) = get_or_add_id(pdf)
  let user = mk_user(!encrypt_metadata, user_pw, owner, p, id, 4, 128)
  encrypt_pdf_AES_inner(
    owner, user, p, user_pw, id, encrypt_metadata, pdf_updated,
  )
}
