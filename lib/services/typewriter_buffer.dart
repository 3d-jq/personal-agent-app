class TypewriterBuffer {
  TypewriterBuffer({this.charsPerTick = 3});

  final int charsPerTick;
  final StringBuffer _full = StringBuffer();
  var _visibleLength = 0;

  String get fullText => _full.toString();
  String get visibleText => fullText.substring(0, _visibleLength);
  bool get hasPending => _visibleLength < _full.length;

  void append(String text) {
    if (text.isEmpty) return;
    _full.write(text);
  }

  bool revealNext() {
    if (!hasPending) return false;
    _visibleLength = (_visibleLength + charsPerTick).clamp(0, _full.length);
    return true;
  }

  void revealAll() {
    _visibleLength = _full.length;
  }
}
