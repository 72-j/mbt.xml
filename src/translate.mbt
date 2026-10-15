///|
/// 底座错误 → moonxml 错误面:kind 与 span 逐字段翻译(契约三:位置透传)。
fn translate_error(base_error : @xml.XmlError) -> XmlError {
  match base_error {
    @xml.At(error~, span~) =>
      XmlError::At(error=kind_of(error), span=translate_span(span))
  }
}

///|
/// 底座错误词表 → 本包词表(变体名对位,规范拼写保留)。
fn kind_of(base_kind : @xml.XmlErrorKind) -> XmlErrorKind {
  match base_kind {
    @xml.UnexpectedEof => XmlErrorKind::UnexpectedEof
    @xml.InvalidSyntax(message) => XmlErrorKind::InvalidSyntax(message)
    @xml.UnmatchedTag(expected~, found~) =>
      XmlErrorKind::UnmatchedTag(expected~, found~)
    @xml.InvalidAttribute(message) => XmlErrorKind::InvalidAttribute(message)
    @xml.InvalidEntity(message) => XmlErrorKind::InvalidEntity(message)
  }
}

///|
fn translate_span(base_span : @xml.SourceSpan) -> SourceSpan {
  {
    start: translate_position(base_span.start),
    end: translate_position(base_span.end),
  }
}

///|
fn translate_position(base_position : @xml.SourcePosition) -> SourcePosition {
  {
    offset: base_position.offset,
    line: base_position.line,
    column: base_position.column,
  }
}
