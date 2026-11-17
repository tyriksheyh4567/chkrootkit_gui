import 'package:material_ui/material_ui.dart';

import 'translations.dart';

class AppLanguage extends InheritedWidget {
  const AppLanguage({required this.code, required super.child, super.key});
  final String code;
  static String of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppLanguage>()?.code ?? 'ru';
  @override
  bool updateShouldNotify(AppLanguage oldWidget) => code != oldWidget.code;
}

String tr(BuildContext context, String text) {
  if (AppLanguage.of(context) != 'en') return text;
  return english[text] ?? _translateFragments(text);
}

String _translateFragments(String text) {
  var result = text;
  for (final entry in englishFragments.entries) {
    result = result.replaceAll(entry.key, entry.value);
  }
  return result;
}

/// Interface text only. Scanner output and model prose keep their original text.
class TrText extends StatelessWidget {
  const TrText(
    this.data, {
    super.key,
    this.style,
    this.overflow,
    this.maxLines,
    this.textAlign,
    this.softWrap,
  });
  final String data;
  final TextStyle? style;
  final TextOverflow? overflow;
  final int? maxLines;
  final TextAlign? textAlign;
  final bool? softWrap;
  @override
  Widget build(BuildContext context) => Text(
    tr(context, data),
    style: style,
    overflow: overflow,
    maxLines: maxLines,
    textAlign: textAlign,
    softWrap: softWrap,
  );
}

InputDecoration localizedDecoration(
  BuildContext context, {
  String? labelText,
  String? hintText,
  String? helperText,
  String? errorText,
  int? helperMaxLines,
  Widget? suffixIcon,
}) => InputDecoration(
  labelText: labelText == null ? null : tr(context, labelText),
  hintText: hintText == null ? null : tr(context, hintText),
  helperText: helperText == null ? null : tr(context, helperText),
  errorText: errorText == null ? null : tr(context, errorText),
  helperMaxLines: helperMaxLines,
  suffixIcon: suffixIcon,
);
