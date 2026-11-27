import 'place.dart';

/// A place's name tidied for showing: [title] in Latin letters where it has
/// any, and [other] the same name in another script, such as the Chinese on
/// a kopitiam's sign, shown smaller under it.
typedef PlaceName = ({String title, String? other});

extension PlaceNameOf on Place {
  /// [name] tidied by [cleanName], worked out once per place.
  PlaceName get shownName => _names[this] ??= cleanName(name);
}

final Expando<PlaceName> _names = Expando<PlaceName>();

/// Tidies a name as Google lists it. Google's own name stays on the place,
/// for the Maps link and the kind rules; this is only what the app shows.
PlaceName cleanName(String raw) {
  final String bare = _plainLetters(raw).replaceAll(_emoji, '').trim();
  if (!_latin.hasMatch(bare)) return (title: bare, other: null);
  final String plain = bare
      .replaceAll('（', '(')
      .replaceAll('）', ')')
      .replaceAll('[', '(')
      .replaceAll(']', ')')
      .trim();

  // The other script's name, outside any brackets, before it is cut out.
  final String? other = _otherScript
      .allMatches(plain.replaceAll(_anyBracket, ' '))
      .map((Match m) => m[0]!.trim())
      .where((String s) => s.isNotEmpty)
      .firstOrNull;

  String s = plain.replaceAll(_bracketWithOther, ' ');
  s = s.replaceAll(_otherScript, ' ');
  s = s.replaceAll(_company, ' ');
  s = s.replaceAllMapped(
    _bracket,
    (Match m) => _dropBracket(m[1]!) ? ' ' : '(${m[1]!.trim()})',
  );
  // A bracket Google's name never closes, as in "(Cawangan Taman Selasih".
  s = s.replaceAllMapped(
    _openBracket,
    (Match m) => _dropBracket(m[1]!) ? ' ' : m[0]!,
  );
  s = _firstPart(s);
  s = _dropCommaPlace(s);
  s = _tidy(s);
  // The only Latin part was a bracket: "大快饭店 (Restaurant Tar Kuow)".
  if (RegExp(r'^\(([^()]*)\)$').firstMatch(s) case final Match m) {
    s = m[1]!.trim();
  }
  if (_letters(s) < 2) return (title: raw.trim(), other: null);
  return (title: _fixCase(s), other: other);
}

final RegExp _latin = RegExp('[A-Za-z]');

int _letters(String s) => s.replaceAll(RegExp('[^A-Za-z]'), '').length;

String _tidy(String s) =>
    s.replaceAll(RegExp(r'\s+'), ' ').replaceAll(_edges, '').trim();

const String _otherChars =
    r'　-ヿ㐀-䶿一-鿿豈-﫿＀-￯'
    r'฀-๿஀-௿';

/// A run of Chinese, Japanese kana, Thai or Tamil, with the spaces inside it.
final RegExp _otherScript = RegExp(
  '[$_otherChars](?:[\\s$_otherChars]*[$_otherChars])?',
);

final RegExp _emoji = RegExp(
  r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}\u{200D}]',
  unicode: true,
);

final RegExp _anyBracket = RegExp(r'\([^)]*\)');

/// Brackets with another script in them: a menu note or the name again.
final RegExp _bracketWithOther = RegExp('\\([^)]*[$_otherChars][^)]*\\)');

final RegExp _bracket = RegExp(r'\(([^()]*)\)');
final RegExp _openBracket = RegExp(r'\(([^()]*)$');

final RegExp _company = RegExp(
  r'\(\s*M\s*\)|\bSdn\.?\s*Bhd\.?|\bPLT\b|'
  r'\(\s*(?:SSM\s*NO:?\s*)?[A-Z]{0,3}\d{5,}-?[A-Z]?\s*\)',
  caseSensitive: false,
);

/// Towns, areas and words that say a place or a branch rather than a name.
final RegExp _placeWord = RegExp(
  r'\b(kepala batas|bertam|penang|pulau pinang|butterworth|seberang|perai|'
  r'penaga|tasek gelugor|sungai petani|kubang semang|permatang|padang serai|'
  r'kuala muda|lunas|kulim|raja uda|sama gagah|pokok sena|kedah|sg\.?|pdg|'
  r'sungai|taman|tmn|kampung|kampong|kg\.?|bandar|jalan|jln|lorong|'
  r'cawangan|branch|baru|new|outlet)\b',
  caseSensitive: false,
);

/// A menu list or a note in brackets: commas, "dll", "etc", numbers.
final RegExp _menuNote = RegExp(r',|\bdll\b|\betc\b|\d', caseSensitive: false);

bool _dropBracket(String inside) =>
    inside.trim().isEmpty ||
    _placeWord.hasMatch(inside) ||
    _menuNote.hasMatch(inside);

/// Words that say what a place is without naming it: a name made only of
/// these, such as "Kedai Makan", needs the part after it.
final RegExp _generic = RegExp(
  r'^(kedai|makan|makanan|minuman|kopi|restoran|restaurant|warung|warong|'
  r'gerai|cafe|kafe|&|dan|and|stall|the)$',
  caseSensitive: false,
);

bool _namesSomething(String part) =>
    _letters(part) >= 3 &&
    part
        .split(RegExp(r'\s+'))
        .where((String w) => w.isNotEmpty)
        .any((String w) => !_generic.hasMatch(w));

final RegExp _separator = RegExp(r'\s+[|•·@–—-]\s+|\s*[|•@]\s*|\s+-|-\s+');

/// The name before the first separator; what follows is a place, a slogan
/// or the name again in another script.
String _firstPart(String s) {
  final List<String> parts = s.split(_separator).map(_tidy).toList();
  return parts.firstWhere(_namesSomething, orElse: () => s);
}

String _dropCommaPlace(String s) {
  final int at = s.indexOf(',');
  if (at < 0 || !_placeWord.hasMatch(s.substring(at))) return s;
  final String before = s.substring(0, at);
  return _namesSomething(before) ? before : s;
}

final RegExp _edges = RegExp(r'^[\s,.\-–—|•·@:/]+|[\s,\-–—|•·@:&/]+$');

/// Shouted and flat names get title case; a name already in mixed case is
/// spelt the way its owner wants. A name in capitals but for a word or two,
/// as in "LI SARJAN NASI BURUNG Puyuh", counts as shouted.
String _fixCase(String s) {
  final String letters = s.replaceAll(RegExp('[^A-Za-z]'), '');
  if (letters.length < 4) return s;
  final int upper = letters.replaceAll(RegExp('[^A-Z]'), '').length;
  final bool shouted = upper >= letters.length * 0.8;
  final bool flat = upper == 0;
  if (!shouted && !flat) return s;
  final List<String> words = s.split(' ');
  return <String>[
    for (int i = 0; i < words.length; i++) _word(words[i], first: i == 0),
  ].join(' ');
}

const Set<String> _small = <String>{
  'dan',
  'di',
  'bin',
  'binti',
  'bt',
  'and',
  'of',
  'the',
  'by',
  'at',
  'n',
};

/// Short forms written one way: Mr, Kg, Hj, Sg.
const Map<String, String> _shortForms = <String, String>{
  'mr': 'Mr',
  'mrs': 'Mrs',
  'dr': 'Dr',
  'hj': 'Hj',
  'kg': 'Kg',
  'sg': 'Sg',
  'tmn': 'Tmn',
  'jln': 'Jln',
  'pdg': 'Pdg',
  'st': 'St',
};

/// Two-letter initials that have a vowel, so the no-vowel rule misses them.
const Set<String> _initials = <String>{'us'};

String _word(String w, {required bool first}) {
  final String lower = w.toLowerCase();
  if (_shortForms[lower] case final String form) return form;
  if (!first && _small.contains(lower)) return lower;
  final bool lettersOnly = RegExp(r'^[A-Za-z]+$').hasMatch(w);
  // KFC, BBQ, US, AA: initials rather than a word. Ah, Wu and Ee are
  // Chinese names, so a two-letter word with a vowel stays a word.
  if (lettersOnly &&
      (_initials.contains(lower) ||
          (w.length == 2 && lower[0] == lower[1]) ||
          (w.length <= 4 &&
              !RegExp('[aeiouy]', caseSensitive: false).hasMatch(w)))) {
    return w.toUpperCase();
  }
  // D'Aizy, D'Hasana: the D' prefix keeps a capital after it.
  final Match? d = RegExp(r"^([dD]['´’])(.+)$").firstMatch(w);
  if (d != null) return 'D${d[1]!.substring(1)}${_capital(d[2]!)}';
  // OVR.Roast: each part after a dot, but not a web address's ".com".
  if (w.contains('.') && !RegExp(r'\.(com|my|net)$').hasMatch(lower)) {
    return w.split('.').map(_capital).join('.');
  }
  return _capital(w);
}

/// Capitalises the first letter, after any bracket or quote: "(Alang".
/// A word led by a number, as in "12ekor", stays lowercase.
String _capital(String w) {
  final String lower = w.toLowerCase();
  final int at = lower.indexOf(RegExp('[a-z0-9]'));
  if (at < 0 || RegExp('[0-9]').hasMatch(lower[at])) return lower;
  return lower.substring(0, at) +
      lower[at].toUpperCase() +
      lower.substring(at + 1);
}

/// Turns the styled letters of Unicode's Mathematical Alphanumeric block
/// (bold, italic, script and the rest, used to make a name stand out) into
/// plain A to Z and 0 to 9. Dart has no Unicode normalising, so this does
/// the one part of it that names need.
String _plainLetters(String s) {
  if (!s.runes.any((int r) => r >= 0x1D400 && r <= 0x1D7FF)) return s;
  final StringBuffer out = StringBuffer();
  for (final int r in s.runes) {
    if (r >= 0x1D400 && r <= 0x1D6A3) {
      final int i = (r - 0x1D400) % 52;
      out.writeCharCode(i < 26 ? 0x41 + i : 0x61 + i - 26);
    } else if (r >= 0x1D7CE && r <= 0x1D7FF) {
      out.writeCharCode(0x30 + (r - 0x1D7CE) % 10);
    } else {
      out.writeCharCode(r);
    }
  }
  return out.toString();
}
