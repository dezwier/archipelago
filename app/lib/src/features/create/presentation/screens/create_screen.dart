import 'package:flutter/material.dart';
import '../widgets/create_concept_section.dart';

class GenerateFlashcardsScreen extends StatefulWidget {
  final Function(Function())? onRefreshCallbackReady;
  
  const GenerateFlashcardsScreen({
    super.key,
    this.onRefreshCallbackReady,
  });

  @override
  State<GenerateFlashcardsScreen> createState() => _GenerateFlashcardsScreenState();
}

class _GenerateFlashcardsScreenState extends State<GenerateFlashcardsScreen> {
  Function()? _refreshTopicsCallback;

  @override
  void initState() {
    super.initState();
    // Register refresh callback with parent
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onRefreshCallbackReady?.call(() {
        _refreshTopicsCallback?.call();
      });
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
              
              // Create Concepts
              CreateConceptSection(
                onRefreshCallbackReady: (callback) {
                  _refreshTopicsCallback = callback;
                },
              ),
              
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

