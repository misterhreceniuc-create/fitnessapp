/// @file language_switcher.dart
/// @brief Widget for switching between languages
/// @details Displays a dropdown button with language flags/names

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../services/localization_service.dart';

class LanguageSwitcher extends StatelessWidget {
  const LanguageSwitcher({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();

    return PopupMenuButton<String>(
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _getFlag(languageProvider.currentLanguage),
          const SizedBox(width: 4),
          Text(
            languageProvider.currentLanguage.toUpperCase(),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      tooltip: 'Change Language',
      onSelected: (String languageCode) {
        languageProvider.setLanguage(languageCode);
      },
      itemBuilder: (BuildContext context) {
        return LocalizationService.getSupportedLanguages().map((String code) {
          return PopupMenuItem<String>(
            value: code,
            child: Row(
              children: [
                _getFlag(code),
                const SizedBox(width: 12),
                Text(
                  LocalizationService.getLanguageName(code),
                  style: TextStyle(
                    fontWeight: code == languageProvider.currentLanguage
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                if (code == languageProvider.currentLanguage) ...[
                  const Spacer(),
                  const Icon(Icons.check, size: 18, color: Colors.green),
                ],
              ],
            ),
          );
        }).toList();
      },
    );
  }

  Widget _getFlag(String code) {
    switch (code) {
      case 'en':
        return const Text('🇬🇧', style: TextStyle(fontSize: 20));
      case 'ro':
        return const Text('🇷🇴', style: TextStyle(fontSize: 20));
      default:
        return const Text('🌐', style: TextStyle(fontSize: 20));
    }
  }
}
