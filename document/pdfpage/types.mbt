///|
type PdfObject = @pdf.PdfObject

///|
/// The type of the four rotations of pages.
pub(all) enum Rotation {
  Rotate0
  Rotate90
  Rotate180
  Rotate270
} derive(Debug)

///|
/// A type representing a PDF page.
pub struct Page {
  /// Content streams containing the page's graphics operators (text, images, paths).
  content : Array[PdfObject]
  /// Page dimensions as a rectangle [minX, minY, maxX, maxY] in points (1/72 inch).
  mediabox : PdfObject
  /// Resource dictionary mapping names to fonts, images, color spaces, etc.
  resources : PdfObject
  /// Page rotation (0, 90, 180, or 270 degrees clockwise).
  rotate : Rotation
  /// Additional page dictionary entries not captured by other fields.
  rest : PdfObject
}

///|
pub fn Page::Page(
  content~ : Array[PdfObject],
  mediabox~ : PdfObject,
  resources~ : PdfObject,
  rotate~ : Rotation,
  rest~ : PdfObject,
) -> Page {
  { content, mediabox, resources, rotate, rest, }
}

///|
pub struct PdfPageDoc {
  pdf : @pdf.Pdf
}

///|
pub fn PdfPageDoc::new(pdf : @pdf.Pdf) -> PdfPageDoc {
  { pdf, }
}

///|
/// Create a page with empty content and no extra dictionary entries.
pub fn Page::custom(rectangle : PdfObject) -> Page {
  Page(
    content=[],
    mediabox=rectangle,
    resources=Dictionary([]),
    rotate=Rotate0,
    rest=Dictionary([]),
  )
}

///|
/// Create a blank page using the given paper size.
pub fn Page::blank(paper : @pdfpaper.Paper) -> Page {
  Page::custom(paper.rectangle())
}

///|
/// Convert rotation to integers.
pub fn Rotation::to_int(self : Rotation) -> Int {
  match self {
    Rotate0 => 0
    Rotate90 => 90
    Rotate180 => 180
    Rotate270 => 270
  }
}

///|
/// Convert an integer to rotation.
pub fn Rotation::from_int(i : Int) -> Rotation raise {
  let r = i % 360
  match r {
    0 => Rotate0
    90 | -270 => Rotate90
    180 | -180 => Rotate180
    270 | -90 => Rotate270
    _ => raise @pdf.PdfError::Msg("Bad /Rotate")
  }
}

// Explicit method promotion for derived/implemented traits.
// (Previously implicit; see warning [0079] implicit_impl_as_method.)

///|
pub extend Rotation with Debug::{to_repr}
