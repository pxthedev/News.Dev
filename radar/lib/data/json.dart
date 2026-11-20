import 'package:material_ui/material_ui.dart';

typedef Json = Map<String, dynamic>;

/// Erro de formato no JSON vindo do backend. A mensagem diz qual campo falhou.
class JsonFormatError implements Exception {
  JsonFormatError(this.message);
  final String message;
  @override
  String toString() => 'JsonFormatError: $message';
}

/// Leitura tolerante e tipada de JSON. Campo obrigatório ausente vira [JsonFormatError]
/// com o nome do campo, pra facilitar o debug com o backend.
extension JsonRead on Json {
  T _req<T>(String k) {
    final v = this[k];
    if (v is T) return v;
    throw JsonFormatError('campo "$k" deveria ser $T, veio ${v.runtimeType}');
  }

  String str(String k) => _req<String>(k);
  String? strOrNull(String k) => this[k] as String?;

  int integer(String k, {int? fallback}) {
    final v = this[k];
    if (v is num) return v.toInt();
    if (v == null && fallback != null) return fallback;
    throw JsonFormatError('campo "$k" deveria ser número, veio ${v.runtimeType}');
  }

  int? intOrNull(String k) => (this[k] as num?)?.toInt();

  double number(String k) => (this[k] as num?)?.toDouble() ?? 0;

  bool boolean(String k, {bool fallback = false}) => this[k] as bool? ?? fallback;

  /// RFC 3339 (o `time.Time` do Go já serializa assim). Convertido pro fuso local.
  DateTime date(String k) {
    final v = str(k);
    final d = DateTime.tryParse(v);
    if (d == null) throw JsonFormatError('campo "$k" não é uma data RFC 3339: $v');
    return d.toLocal();
  }

  List<dynamic> list(String k) => this[k] as List<dynamic>? ?? const [];

  Json obj(String k) => _req<Json>(k);

  List<Json> objects(String k) => list(k).cast<Json>();

  /// "#76B900" → Color. Ausente ou inválido → null.
  Color? color(String k) {
    final v = this[k];
    if (v is! String) return null;
    final hex = v.replaceFirst('#', '');
    final n = int.tryParse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
    return n == null ? null : Color(n);
  }
}

String colorToHex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

const _palette = [
  Color(0xFF0A84FF),
  Color(0xFFBF5AF2),
  Color(0xFFFF9F0A),
  Color(0xFFFF453A),
  Color(0xFF30B0C7),
  Color(0xFF5E5CE6),
  Color(0xFF64D2FF),
  Color(0xFFFF375F),
];

/// Cor estável a partir de um texto, pra avatares sem cor definida pelo backend.
Color colorFromText(String text) {
  var h = 0;
  for (final c in text.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return _palette[h % _palette.length];
}
