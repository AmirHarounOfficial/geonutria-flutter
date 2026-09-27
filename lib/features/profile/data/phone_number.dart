import '../../../core/localization/localized_number.dart';

// Common calling codes are offered directly; other codes remain editable.
const phoneCountries = <String, (String, String)>{
  '20': ('Egypt', 'مصر'),
  '966': ('Saudi Arabia', 'السعودية'),
  '971': ('United Arab Emirates', 'الإمارات'),
  '965': ('Kuwait', 'الكويت'),
  '974': ('Qatar', 'قطر'),
  '973': ('Bahrain', 'البحرين'),
  '968': ('Oman', 'عمان'),
  '962': ('Jordan', 'الأردن'),
  '961': ('Lebanon', 'لبنان'),
  '970': ('Palestine', 'فلسطين'),
  '964': ('Iraq', 'العراق'),
  '963': ('Syria', 'سوريا'),
  '967': ('Yemen', 'اليمن'),
  '249': ('Sudan', 'السودان'),
  '218': ('Libya', 'ليبيا'),
  '216': ('Tunisia', 'تونس'),
  '213': ('Algeria', 'الجزائر'),
  '212': ('Morocco', 'المغرب'),
  '222': ('Mauritania', 'موريتانيا'),
  '252': ('Somalia', 'الصومال'),
  '253': ('Djibouti', 'جيبوتي'),
  '269': ('Comoros', 'جزر القمر'),
  '1': ('USA / Canada', 'أمريكا / كندا'),
  '44': ('United Kingdom', 'المملكة المتحدة'),
  '33': ('France', 'فرنسا'),
  '49': ('Germany', 'ألمانيا'),
  '39': ('Italy', 'إيطاليا'),
  '90': ('Türkiye', 'تركيا'),
  '91': ('India', 'الهند'),
  '92': ('Pakistan', 'باكستان'),
};

/// API storage uses digits only, while the UI displays the calling-code plus.
String? profilePhone(String code, String number) {
  code = normalizeNumber(code).replaceFirst(RegExp(r'^\+'), '');
  var national = normalizeNumber(number);
  if (national.isEmpty) return '';
  if (!RegExp(r'^[1-9][0-9]{0,2}$').hasMatch(code) ||
      !RegExp(r'^[0-9]+$').hasMatch(national))
    return null;
  // Italy retains its significant leading zero; other listed regions use a
  // domestic trunk zero that must not follow the international calling code.
  if (phoneCountries.containsKey(code) && code != '39' && code != '1') {
    national = national.replaceFirst(RegExp(r'^0'), '');
  }
  final full = '$code$national';
  if (national.length < 6 || full.length > 15 || full.length < 8) return null;
  if (code == '20' && !RegExp(r'^1[0125][0-9]{8}$').hasMatch(national))
    return null;
  return full;
}

(String, String) splitProfilePhone(String value) {
  var digits = normalizeNumber(value).replaceAll(RegExp(r'[\s()+-]'), '');
  if (digits.startsWith('00')) digits = digits.substring(2);
  if (!value.trim().startsWith('+') &&
      RegExp(r'^0?1[0125][0-9]{8}$').hasMatch(digits)) {
    return ('20', digits);
  }
  final codes = phoneCountries.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  for (final code in codes) {
    if (digits.startsWith(code) && digits.length - code.length >= 6) {
      return (code, digits.substring(code.length));
    }
  }
  // Leave unrecognized international numbers intact until the user edits them.
  return (digits.isEmpty || digits.startsWith('0') ? '20' : '', digits);
}
