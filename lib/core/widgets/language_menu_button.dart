import 'package:flutter/material.dart';

import '../settings/app_language_controller.dart';

class LanguageMenuButton extends StatelessWidget {
  const LanguageMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLanguageController.instance,
      builder: (context, _) {
        final lang = AppLanguageController.instance;
        return PopupMenuButton<AppLanguage>(
          tooltip: lang.tr('Language', '언어'),
          onSelected: (value) => AppLanguageController.instance.setLanguage(value),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: AppLanguage.english,
              child: Row(
                children: [
                  Icon(
                    lang.language == AppLanguage.english
                        ? Icons.check
                        : Icons.language,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text('English'),
                ],
              ),
            ),
            PopupMenuItem(
              value: AppLanguage.korean,
              child: Row(
                children: [
                  Icon(
                    lang.language == AppLanguage.korean
                        ? Icons.check
                        : Icons.language,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text('한국어'),
                ],
              ),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.translate, size: 18),
                const SizedBox(width: 6),
                Text(lang.tr('Language', '언어')),
              ],
            ),
          ),
        );
      },
    );
  }
}
