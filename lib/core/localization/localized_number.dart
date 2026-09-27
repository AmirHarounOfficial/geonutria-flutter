/// Accept Arabic-Indic and Persian digits without changing API numeric values.
String normalizeNumber(String value) {
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  var result = value
      .trim()
      .replaceAll('٫', '.')
      .replaceAll('٬', '')
      .replaceAll('−', '-');
  for (var i = 0; i < 10; i++) {
    result = result.replaceAll(arabic[i], '$i').replaceAll(persian[i], '$i');
  }
  return result;
}

double? parseLocalizedDouble(String value) {
  final number = double.tryParse(normalizeNumber(value));
  return number != null && number.isFinite ? number : null;
}

int? parseLocalizedInt(String value) => int.tryParse(normalizeNumber(value));
