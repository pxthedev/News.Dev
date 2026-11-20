// Formatação em pt-BR: tempo relativo, horários e datas.

const _weekdays = ['segunda-feira', 'terça-feira', 'quarta-feira', 'quinta-feira', 'sexta-feira', 'sábado', 'domingo'];
const _months = [
  'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
  'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
];

/// "9:37", "21:14"
String hhmm(DateTime t) => '${t.hour}:${t.minute.toString().padLeft(2, '0')}';

bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// "agora", "há 4 min", "há 1 h", "ontem às 21:14", "3 de novembro"
String relativeTime(DateTime t, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final d = n.difference(t);
  if (d.inMinutes < 1) return 'agora';
  if (d.inMinutes < 60) return 'há ${d.inMinutes} min';
  if (isSameDay(t, n)) return 'há ${d.inHours} h';
  if (isSameDay(t, n.subtract(const Duration(days: 1)))) return 'ontem às ${hhmm(t)}';
  return '${t.day} de ${_months[t.month - 1]}';
}

/// "quinta-feira, 12 de novembro"
String longDate(DateTime t) => '${_weekdays[t.weekday - 1]}, ${t.day} de ${_months[t.month - 1]}';

String greeting(String firstName, {DateTime? now}) {
  final h = (now ?? DateTime.now()).hour;
  final g = h < 12 ? 'Bom dia' : (h < 18 ? 'Boa tarde' : 'Boa noite');
  return '$g, $firstName';
}

String plural(int n, String singular, String pluralForm) => n == 1 ? '$n $singular' : '$n $pluralForm';

/// "outubro de 2026"
String monthYear(DateTime t) => '${_months[t.month - 1]} de ${t.year}';

/// 980 → "980", 12400 → "12,4 mil", 3000000 → "3 mi"
String compactCount(int n) {
  String one(double v) {
    final s = v.toStringAsFixed(1).replaceAll('.', ',');
    return s.endsWith(',0') ? s.substring(0, s.length - 2) : s;
  }

  if (n < 1000) return '$n';
  if (n < 1000000) return '${one(n / 1000)} mil';
  return '${one(n / 1000000)} mi';
}

/// Normaliza pra busca: minúsculas e sem acento.
String fold(String s) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ';
  const to = 'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC';
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = from.indexOf(ch);
    b.write(i >= 0 ? to[i] : ch);
  }
  return b.toString().toLowerCase();
}
