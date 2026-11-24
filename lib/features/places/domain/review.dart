/// One review of a place: its stars, roughly when, and what it says. The
/// reviewer is never kept.
class Review {
  const Review({required this.rating, required this.text, this.month});

  /// 1 to 5.
  final int rating;
  final String text;

  /// The month it was written, as far as it is known.
  final DateTime? month;
}
