import 'package:flutter/material.dart';
import 'widgets/create_concept_section.dart';

class GenerateFlashcardsScreen extends StatefulWidget {
  const GenerateFlashcardsScreen({super.key});

  @override
  State<GenerateFlashcardsScreen> createState() => _GenerateFlashcardsScreenState();
}

class _GenerateFlashcardsScreenState extends State<GenerateFlashcardsScreen> {
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
              
              // Create Concepts
              const CreateConceptSection(),
              
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

