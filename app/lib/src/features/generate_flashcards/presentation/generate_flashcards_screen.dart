import 'package:flutter/material.dart';
import '../../../features/profile/domain/language.dart';
import '../../../features/profile/data/language_service.dart';
import 'widgets/create_concept_section.dart';
import 'widgets/generate_cards_section.dart';

class GenerateFlashcardsScreen extends StatefulWidget {
  const GenerateFlashcardsScreen({super.key});

  @override
  State<GenerateFlashcardsScreen> createState() => _GenerateFlashcardsScreenState();
}

class _GenerateFlashcardsScreenState extends State<GenerateFlashcardsScreen> {
  List<Language> _languages = [];
  bool _isLoadingLanguages = false;

  @override
  void initState() {
    super.initState();
    _loadLanguages();
  }

  Future<void> _loadLanguages() async {
    setState(() {
      _isLoadingLanguages = true;
    });

    // Load languages
    final languages = await LanguageService.getLanguages();
    
    setState(() {
      _languages = languages;
      _isLoadingLanguages = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              
              // Part 1: Create Concepts
              const CreateConceptSection(),
              
              const SizedBox(height: 32),
              
              // Part 2: Generate Cards
              GenerateCardsSection(
                languages: _languages,
                isLoadingLanguages: _isLoadingLanguages,
              ),
              
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

