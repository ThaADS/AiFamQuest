import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../api/client.dart';

class VisionScreen extends StatefulWidget {
  const VisionScreen({super.key});
  @override
  State<VisionScreen> createState() => _VisionScreenState();
}

class _VisionScreenState extends State<VisionScreen> {
  String? _originalPhotoPath;
  String? _imageUrl;
  Map<String, dynamic>? _visionTips;
  bool _busy = false;
  String? _errorMessage;
  final _descController = TextEditingController();

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickAndAnalyzeImage(ImageSource source) async {
    setState(() {
      _busy = true;
      _errorMessage = null;
      _visionTips = null;
    });

    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile == null) {
        setState(() => _busy = false);
        return;
      }

      // Save original photo path for before/after comparison
      _originalPhotoPath = pickedFile.path;

      // Upload photo and get AI analysis
      final bytes = await pickedFile.readAsBytes();
      final response = await ApiClient.instance.uploadVisionTips(
        pickedFile.name,
        bytes,
        description: _descController.text.trim(),
      );

      setState(() {
        _imageUrl = response['url'];
        _visionTips = response['tips'];
        _busy = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Fout bij analyseren: ${e.toString()}';
        _busy = false;
      });
    }
  }

  Widget _buildDetectedInfo() {
    if (_visionTips == null) return const SizedBox.shrink();

    final detected = _visionTips!['detected'] as Map<String, dynamic>?;
    if (detected == null) return const SizedBox.shrink();

    final surface = detected['surface'] ?? 'onbekend';
    final stain = detected['stain'] ?? 'onbekend';
    final confidence = (detected['confidence'] ?? 0.0) as num;

    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.search, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Gedetecteerd',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Oppervlak', surface),
            _buildInfoRow('Vlek/Vuil', stain),
            _buildInfoRow(
              'Zekerheid',
              '${(confidence * 100).toStringAsFixed(0)}%',
              valueColor: confidence > 0.7 ? Colors.green : Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? Colors.black87,
                fontWeight: valueColor != null ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSteps() {
    if (_visionTips == null) return const SizedBox.shrink();

    final steps = (_visionTips!['steps'] as List<dynamic>?) ?? [];
    if (steps.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.list, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Stappen',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...steps.asMap().entries.map((entry) {
              final index = entry.key;
              final step = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        step.toString(),
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildProducts() {
    if (_visionTips == null) return const SizedBox.shrink();

    final products = _visionTips!['products'] as Map<String, dynamic>?;
    if (products == null) return const SizedBox.shrink();

    final recommended = (products['recommended'] as List<dynamic>?) ?? [];
    final avoid = (products['avoid'] as List<dynamic>?) ?? [];

    if (recommended.isEmpty && avoid.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.cleaning_services, color: Colors.purple),
                SizedBox(width: 8),
                Text(
                  'Producten',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (recommended.isNotEmpty) ...[
              const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.orange),
                  SizedBox(width: 8),
                  Text(
                    'Aanbevolen:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ...recommended.map((product) => Padding(
                    padding: const EdgeInsets.only(left: 28, top: 4),
                    child: Text('• $product'),
                  )),
            ],
            if (avoid.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Row(
                children: [
                  Icon(Icons.cancel, color: Colors.orange),
                  SizedBox(width: 8),
                  Text(
                    'Vermijd:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ...avoid.map((product) => Padding(
                    padding: const EdgeInsets.only(left: 28, top: 4),
                    child: Text('• $product'),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWarnings() {
    if (_visionTips == null) return const SizedBox.shrink();

    final warnings = (_visionTips!['warnings'] as List<dynamic>?) ?? [];
    if (warnings.isEmpty) return const SizedBox.shrink();

    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'Waarschuwingen',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...warnings.map((warning) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('⚠️ ', style: TextStyle(fontSize: 16)),
                      Expanded(
                        child: Text(
                          warning.toString(),
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadata() {
    if (_visionTips == null) return const SizedBox.shrink();

    final estimatedMinutes = _visionTips!['estimatedMinutes'] as int? ?? 0;
    final difficulty = _visionTips!['difficulty'] as int? ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  const Icon(Icons.timer, color: Colors.blue),
                  const SizedBox(height: 8),
                  Text(
                    '$estimatedMinutes min',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text('Geschatte tijd', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  const Icon(Icons.show_chart, color: Colors.orange),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      5,
                      (index) => Icon(
                        index < difficulty ? Icons.star : Icons.star_border,
                        color: Colors.orange,
                        size: 18,
                      ),
                    ),
                  ),
                  const Text('Moeilijkheid', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBeforeAfterComparison() {
    if (_originalPhotoPath == null || _imageUrl == null) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Voor de schoonmaak',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(_originalPhotoPath!),
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tip: Maak een foto na het schoonmaken om je voortgang te zien!',
              style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Schoonmaaktips'),
        actions: [
          if (_visionTips != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() {
                  _visionTips = null;
                  _imageUrl = null;
                  _originalPhotoPath = null;
                  _errorMessage = null;
                  _descController.clear();
                });
              },
              tooltip: 'Nieuwe analyse',
            ),
        ],
      ),
      body: _busy
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('AI analyseert de foto...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_visionTips == null) ...[
                    const Text(
                      'Maak een foto van een vlek of vuil oppervlak en krijg AI-gestuurde schoonmaaktips!',
                      style: TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _descController,
                      decoration: const InputDecoration(
                        labelText: 'Omschrijving (optioneel)',
                        hintText: 'Bijv: Rode wijnvlek op marmeren aanrecht',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => _pickAndAnalyzeImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Maak foto'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _pickAndAnalyzeImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Kies uit galerij'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ],
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Card(
                      color: Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.error, color: Colors.red),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (_visionTips != null) ...[
                    _buildBeforeAfterComparison(),
                    const SizedBox(height: 16),
                    _buildDetectedInfo(),
                    const SizedBox(height: 16),
                    _buildMetadata(),
                    const SizedBox(height: 16),
                    _buildSteps(),
                    const SizedBox(height: 16),
                    _buildProducts(),
                    const SizedBox(height: 16),
                    _buildWarnings(),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () {
                        // Navigate to task creation with pre-filled data
                        final steps = (_visionTips!['steps'] as List<dynamic>?) ?? [];
                        final estimatedMinutes = _visionTips!['estimatedMinutes'] as int? ?? 15;

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Deze functie zou een taak aanmaken met ${steps.length} stappen '
                              'en geschatte duur van $estimatedMinutes minuten',
                            ),
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      },
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Markeer als klaar'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
