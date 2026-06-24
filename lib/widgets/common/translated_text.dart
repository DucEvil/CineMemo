import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/locale_provider.dart';
import '../../services/translation/translation_service.dart';

class TranslatedText extends StatefulWidget {
  const TranslatedText({
    super.key,
    required this.text,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.softWrap,
    this.localeLanguageCode,
    this.sourceLanguageCode = 'vi',
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final bool? softWrap;
  final String? localeLanguageCode;
  final String sourceLanguageCode;

  @override
  State<TranslatedText> createState() => _TranslatedTextState();
}

class _TranslatedTextState extends State<TranslatedText> {
  late Future<String> _translationFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _prepareTranslation();
  }

  @override
  void didUpdateWidget(covariant TranslatedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text ||
        widget.localeLanguageCode != oldWidget.localeLanguageCode ||
        widget.sourceLanguageCode != oldWidget.sourceLanguageCode) {
      _prepareTranslation();
    }
  }

  void _prepareTranslation() {
    final targetLanguage =
        widget.localeLanguageCode ??
        Provider.of<LocaleProvider>(context, listen: false).locale.languageCode;

    _translationFuture = _resolveTranslation(widget.text, targetLanguage);
  }

  Future<String> _resolveTranslation(String text, String targetLanguage) async {
    final translationService = Provider.of<TranslationService>(
      context,
      listen: false,
    );

    if (!translationService.isEnabled || text.trim().isEmpty) {
      return text;
    }

    return translationService.translateText(
      text: text,
      targetLanguage: targetLanguage,
      sourceLanguage: widget.sourceLanguageCode,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<String>(
      future: _translationFuture,
      builder: (context, snapshot) {
        final displayText = snapshot.data ?? widget.text;
        return Text(
          displayText,
          style: widget.style,
          maxLines: widget.maxLines,
          overflow: widget.overflow,
          textAlign: widget.textAlign,
          softWrap: widget.softWrap,
        );
      },
    );
  }
}
