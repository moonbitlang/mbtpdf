# mbtpdf

A pure MoonBit PDF library - unified entry point.

## Overview

This is the main entry point for the mbtpdf library. Import this single package to access all core PDF functionality without needing to import individual packages.

## Quick Start

```mbt
// Read a PDF
let pdf = @mbtpdf.read_file("input.pdf")

// Get page count
let count = @mbtpdf.page_count!(pdf)

// Extract first 3 pages
let extracted = @mbtpdf.extract_pages!(pdf, [1, 2, 3])

// Write to file
@mbtpdf.write_file(extracted, "output.pdf")
```

## Reading PDFs

```mbt
// From file
let pdf = @mbtpdf.read_file("document.pdf")

// From file with password
let pdf = @mbtpdf.read_file(
  "encrypted.pdf",
  user_password="secret",
)

// From bytes
let pdf = @mbtpdf.read_bytes!(bytes)

// From string (for testing)
let pdf = @mbtpdf.read_string!(pdf_content)
```

## Writing PDFs

```mbt
// Simple write
@mbtpdf.write_file(pdf, "output.pdf")

// With compression
@mbtpdf.write_file_options(
  pdf,
  "compressed.pdf",
  compress=true,
)

// To bytes
let bytes = @mbtpdf.write_bytes!(pdf)
```

## Page Operations

```mbt
// Get all pages
let pages = @mbtpdf.pages!(pdf)

// Get page count
let count = @mbtpdf.page_count!(pdf)

// Create blank page
let page = @mbtpdf.blank_page(@mbtpdf.a4)

// Extract pages
let subset = @mbtpdf.extract_pages!(pdf, [1, 3, 5])
```

## Merging

```mbt
// Merge all pages from multiple PDFs
let merged = @mbtpdf.merge!([pdf1, pdf2, pdf3])

// Merge with specific page ranges
let merged = @mbtpdf.merge_ranges!(
  [pdf1, pdf2],
  [[1, 2, 3], [1, 2]],  // pages from each
)
```

## Transformations

```mbt
// Translation
let m = @mbtpdf.translate(100.0, 200.0)

// Scaling
let m = @mbtpdf.scale(2.0, 2.0)

// Rotation (radians)
let m = @mbtpdf.rotate(1.5708)  // 90 degrees

// Identity matrix
let m = @mbtpdf.identity_matrix
```

## Paper Sizes

```mbt
@mbtpdf.a4       // 210 x 297 mm
@mbtpdf.letter   // 8.5 x 11 inches
@mbtpdf.legal    // 8.5 x 14 inches

// Landscape orientation
let landscape_a4 = @mbtpdf.landscape(@mbtpdf.a4)
```

## Document Info

```mbt
// Version
let (major, minor) = @mbtpdf.version(pdf)

// Encryption
if @mbtpdf.is_encrypted(pdf) {
  let method = @mbtpdf.encryption_method(pdf)
  let perms = @mbtpdf.permissions(pdf)
}
```

## Object Manipulation

```mbt
// Empty document
let pdf = @mbtpdf.empty()

// Lookup object
let obj = @mbtpdf.lookup_object(pdf, 1)

// Add object
let objnum = @mbtpdf.add_object(pdf, obj)

// Garbage collect
@mbtpdf.garbage_collect!(pdf)

// Deep copy
let copy = @mbtpdf.copy(pdf)
```

## Type Aliases

For convenience, this package provides type aliases:

- `PdfObject` - PDF object values
- `Pdf` - PDF document
- `Page` - Document page
- `Bytes` - Byte buffer
- `Matrix` - Transform matrix
- `Paper` - Paper size
- `Rotation` - Page rotation
- `Destination` - Link destination
- `EncryptionMethod` - Encryption type
- `Permission` - Access permission
