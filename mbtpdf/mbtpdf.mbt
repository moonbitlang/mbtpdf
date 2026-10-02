///|
/// mbtpdf - A pure MoonBit PDF library
///
/// This facade package provides a unified entry point to the mbtpdf library.
/// Import this single package to access core PDF functionality.
///
/// # Example
///
/// ```mbt
/// // Read a PDF
/// let pdf = @mbtpdf.read_file("input.pdf")
///
/// // Get page count
/// let pages = @mbtpdf.page_count(pdf)
///
/// // Write a PDF
/// @mbtpdf.write_file(pdf, "output.pdf")
/// ```

// ============================================================================
// Core Types (re-exported via type alias)
// ============================================================================

///|
/// The core PDF object type representing all PDF values.
pub type PdfObject = @pdf.PdfObject

///|
/// An in-memory PDF document.
pub type Pdf = @pdf.Pdf

///|
/// A single page in a PDF document.
pub type Page = @pdfpage.Page

///|
/// Byte buffer for stream data.
pub type Bytes = @pdfio.MutableBytes

///|
/// 2D transformation matrix.
pub type Matrix = @pdftransform.TransformMatrix

///|
/// Paper size specification.
pub type Paper = @pdfpaper.Paper

///|
/// Page rotation.
pub type Rotation = @pdfpage.Rotation

///|
/// PDF destination (for bookmarks and links).
pub type Destination = @pdfdest.Destination

///|
/// Encryption method.
pub type EncryptionMethod = @pdfcrypt.EncryptionMethod

///|
/// Permission flags for encrypted documents.
pub type Permission = @pdfcrypt.Permission

// ============================================================================
// Reading PDFs
// ============================================================================

///|
/// Read a PDF from a file.
pub async fn read_file(
  filename : String,
  user_password? : String,
  owner_password? : String,
) -> @pdf.Pdf {
  @pdfread.pdf_of_file(user_password, owner_password, filename)
}

///|
/// Read a PDF from bytes.
pub fn read_bytes(
  bytes : @pdfio.MutableBytes,
  user_password? : String,
  owner_password? : String,
) -> @pdf.Pdf raise {
  let input = @pdfio.input_of_bytes(bytes)
  @pdfread.pdf_of_input(user_password, owner_password, input)
}

///|
/// Read a PDF from a string (for testing).
pub fn read_string(
  content : String,
  user_password? : String,
  owner_password? : String,
) -> @pdf.Pdf raise {
  let input = @pdfio.input_of_string(content)
  @pdfread.pdf_of_input(user_password, owner_password, input)
}

// ============================================================================
// Writing PDFs
// ============================================================================

///|
/// Write a PDF to a file.
pub async fn write_file(pdf : @pdf.Pdf, filename : String) -> Unit {
  @pdfwrite.pdf_to_file(pdf, filename)
}

///|
/// Write a PDF to a file with options.
pub async fn write_file_options(
  pdf : @pdf.Pdf,
  filename : String,
  compress? : Bool = false,
  encryption? : @pdfwrite.Encryption,
) -> Unit {
  @pdfwrite.pdf_to_file_options(
    generate_objstm=compress,
    compress_objstm=compress,
    encryption,
    true,
    pdf,
    filename,
  )
}

///|
/// Write a PDF to bytes.
pub fn write_bytes(pdf : @pdf.Pdf) -> @pdfio.MutableBytes raise {
  let (output, data) = @pdfio.input_output_of_bytes(65536)
  @pdfwrite.pdf_to_output(None, true, pdf, output)
  @pdfio.extract_bytes_from_input_output(output, data)
}

// ============================================================================
// Page Operations
// ============================================================================

///|
/// Get pages from a PDF document.
pub fn pages(pdf : @pdf.Pdf) -> Array[@pdfpage.Page] raise {
  @pdfpage.pages_of_pagetree(pdf)
}

///|
/// Get the number of pages in a PDF document.
pub fn page_count(pdf : @pdf.Pdf) -> Int raise {
  @pdfpage.endpage_fast(pdf)
}

///|
/// Create a blank page with the given paper size.
pub fn blank_page(paper : @pdfpaper.Paper) -> @pdfpage.Page {
  @pdfpage.blankpage(paper)
}

///|
/// Extract specific pages from a PDF.
pub fn extract_pages(pdf : @pdf.Pdf, range : Array[Int]) -> @pdf.Pdf raise {
  @pdfpage.pdf_of_pages(pdf, range)
}

// ============================================================================
// Merging PDFs
// ============================================================================

///|
/// Merge multiple PDFs into one.
pub fn merge(
  pdfs : Array[@pdf.Pdf],
  remove_duplicate_fonts? : Bool = true,
) -> @pdf.Pdf raise {
  let names = pdfs.mapi(fn(i, _) { "doc\{i + 1}" })
  let ranges = pdfs.map(fn(pdf) {
    let count = @pdfpage.endpage_fast!(pdf)
    Array::makei(count, fn(i) { i + 1 })
  })
  @pdfmerge.merge_pdfs(false, remove_duplicate_fonts, names, pdfs, ranges)
}

///|
/// Merge PDFs with specific page ranges.
pub fn merge_ranges(
  pdfs : Array[@pdf.Pdf],
  ranges : Array[Array[Int]],
  remove_duplicate_fonts? : Bool = true,
) -> @pdf.Pdf raise {
  let names = pdfs.mapi(fn(i, _) { "doc\{i + 1}" })
  @pdfmerge.merge_pdfs(false, remove_duplicate_fonts, names, pdfs, ranges)
}

// ============================================================================
// Transformations
// ============================================================================

///|
/// Identity transformation matrix.
pub let identity_matrix : @pdftransform.TransformMatrix = @pdftransform.i_matrix

///|
/// Create a translation matrix.
pub fn translate(tx : Double, ty : Double) -> @pdftransform.TransformMatrix {
  @pdftransform.mktranslate(tx, ty)
}

///|
/// Create a scaling matrix.
pub fn scale(
  sx : Double,
  sy : Double,
  center? : (Double, Double) = (0.0, 0.0),
) -> @pdftransform.TransformMatrix {
  @pdftransform.mkscale(center, sx, sy)
}

///|
/// Create a rotation matrix (angle in radians).
pub fn rotate(
  angle : Double,
  center? : (Double, Double) = (0.0, 0.0),
) -> @pdftransform.TransformMatrix {
  @pdftransform.mkrotate(center, angle)
}

// ============================================================================
// Paper Sizes
// ============================================================================

///|
/// A4 paper size (210 x 297 mm).
pub let a4 : @pdfpaper.Paper = @pdfpaper.a4

///|
/// US Letter paper size (8.5 x 11 inches).
pub let letter : @pdfpaper.Paper = @pdfpaper.usletter

///|
/// US Legal paper size (8.5 x 14 inches).
pub let legal : @pdfpaper.Paper = @pdfpaper.uslegal

///|
/// Convert paper to landscape orientation.
pub fn landscape(paper : @pdfpaper.Paper) -> @pdfpaper.Paper {
  @pdfpaper.landscape(paper)
}

// ============================================================================
// Document Information
// ============================================================================

///|
/// Get the PDF version as (major, minor).
pub fn version(pdf : @pdf.Pdf) -> (Int, Int) {
  (pdf.major, pdf.minor)
}

///|
/// Check if a PDF is encrypted.
pub fn is_encrypted(pdf : @pdf.Pdf) -> Bool {
  @pdfread.what_encryption(pdf) is Some(_)
}

///|
/// Get encryption method if encrypted.
pub fn encryption_method(pdf : @pdf.Pdf) -> @pdfcrypt.EncryptionMethod? {
  @pdfread.what_encryption(pdf)
}

///|
/// Get permissions for an encrypted PDF.
pub fn permissions(pdf : @pdf.Pdf) -> Array[@pdfcrypt.Permission] {
  @pdfread.permissions(pdf)
}

// ============================================================================
// Object Manipulation
// ============================================================================

///|
/// Create an empty PDF document.
pub fn empty() -> @pdf.Pdf {
  @pdf.empty()
}

///|
/// Look up an object by number.
pub fn lookup_object(pdf : @pdf.Pdf, objnum : Int) -> @pdf.PdfObject {
  @pdf.lookup_obj(pdf, objnum)
}

///|
/// Add an object to a PDF, returning its object number.
pub fn add_object(pdf : @pdf.Pdf, obj : @pdf.PdfObject) -> Int {
  @pdf.addobj(pdf, obj)
}

///|
/// Remove unreferenced objects from a PDF.
pub fn garbage_collect(pdf : @pdf.Pdf) -> Unit raise {
  @pdf.remove_unreferenced(pdf)
}

///|
/// Create a deep copy of a PDF.
pub fn copy(pdf : @pdf.Pdf) -> @pdf.Pdf {
  @pdf.deep_copy(pdf)
}
