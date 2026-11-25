/// One review of a place: its stars, roughly when, and what it says. The
/// reviewer is never kept.
class Review {
  const Review({required this.rating, required this.text, this.month});

  /// 1 to 5.
  final int rating;
  final String text;

  /// The month it was written, as far as it is known.
  final DateTime? month;

  /// The places list keeps at most this many characters of a review
  /// (tool/scraper), so a text this long was cut before the app.
  static const int keptLength = 600;

  bool get mayBeCut => text.length >= keptLength;
}
