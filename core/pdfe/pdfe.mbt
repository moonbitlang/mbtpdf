///|
/// Default error logger, writes the string to stderr (shim).
fn default(message : String) -> Unit {
  @pdfutil.PdfUtil::new().fleprint(message)
}

///|
pub type Logger = (String) -> Unit

///|
/// The current error logger, set to default upon startup.
pub let logger : Ref[Logger] = { val: default, }

///|
/// When true, @pdfe.log is suppressed.
pub let quiet : Ref[Bool] = { val: false, }

///|
/// Log a string using the current logger.
pub fn log(message : String) -> Unit {
  if !quiet.val {
    (logger.val)(message)
  }
}

///|
/// Debug flag for PDF reading operations.
pub let read_debug : Ref[Bool] = { val: false, }

///|
/// Log a warning message (ensures a trailing newline).
pub fn warn(message : String) -> Unit {
  if message.has_suffix("\n") {
    log(message)
  } else {
    log(message + "\n")
  }
}

///|
/// Log a string only when `read_debug` is enabled.
pub fn debug(message : String) -> Unit {
  if read_debug.val {
    log(message)
  }
}

///|
/// Run an action with logging suppressed, restoring the previous state.
pub fn[T] with_silenced_logs(action : () -> T raise) -> T raise {
  let prev = quiet.val
  quiet.val = true
  defer {
    quiet.val = prev
  }
  action()
}

///|
/// Async variant of with_silenced_logs.
pub async fn[T] with_silenced_logs_async(action : async () -> T) -> T {
  let prev = quiet.val
  quiet.val = true
  defer {
    quiet.val = prev
  }
  action()
}

///|
/// Run an action with a temporary logger, restoring the previous logger.
pub fn[T] with_logger(temp : Logger, action : () -> T raise) -> T raise {
  let prev = logger.val
  logger.val = temp
  defer {
    logger.val = prev
  }
  action()
}

///|
/// Async variant of with_logger.
pub async fn[T] with_logger_async(temp : Logger, action : async () -> T) -> T {
  let prev = logger.val
  logger.val = temp
  defer {
    logger.val = prev
  }
  action()
}
