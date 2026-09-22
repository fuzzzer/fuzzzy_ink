enum MessageType {
  text,
  file;

  bool get isText => this == text;
  bool get isFile => this == file;
}
