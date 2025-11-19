/// Cleaning Tips Card Widget
///
/// Displays AI-powered cleaning tips from Gemini Vision analysis
/// Shows surface detection, step-by-step instructions, product recommendations, and warnings

import 'package:flutter/material.dart';

class CleaningTipsCard extends StatefulWidget {
  final Map<String, dynamic> tips;
  final bool isLoading;
  final VoidCallback? onRefresh;

  const CleaningTipsCard({
    Key? key,
    required this.tips,
    this.isLoading = false,
    this.onRefresh,
  }) : super(key: key);

  @override
  State<CleaningTipsCard> createState() => _CleaningTipsCardState();
}

class _CleaningTipsCardState extends State<CleaningTipsCard> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(
                'Analyzing photo with AI...',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'This may take a few seconds',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ),
        ),
      );
    }

    final analysis = widget.tips['analysis'] as Map<String, dynamic>?;
    if (analysis == null) {
      return const SizedBox.shrink();
    }

    final detected = analysis['detected'] as Map<String, dynamic>?;
    final steps = (analysis['steps'] as List<dynamic>?)?.cast<String>() ?? [];
    final products = analysis['products'] as Map<String, dynamic>?;
    final warnings = (analysis['warnings'] as List<dynamic>?)?.cast<String>() ?? [];
    final estimatedMinutes = analysis['estimatedMinutes'] as int? ?? 0;
    final difficulty = analysis['difficulty'] as int? ?? 0;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          // Header
          ListTile(
            leading: Icon(
              Icons.lightbulb,
              color: Colors.amber[700],
              size: 32,
            ),
            title: const Text(
              'AI Cleaning Tips',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            subtitle: Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text('$estimatedMinutes min'),
                const SizedBox(width: 16),
                ...List.generate(
                  5,
                  (index) => Icon(
                    index < difficulty ? Icons.star : Icons.star_border,
                    size: 16,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.onRefresh != null)
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: widget.onRefresh,
                    tooltip: 'Get new tips',
                  ),
                IconButton(
                  icon: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
                  onPressed: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                ),
              ],
            ),
          ),

          if (_isExpanded) ...[
            const Divider(),

            // Detection Results
            if (detected != null) _buildDetectionSection(context, detected),

            // Steps
            if (steps.isNotEmpty) _buildStepsSection(context, steps),

            // Products
            if (products != null) _buildProductsSection(context, products),

            // Warnings
            if (warnings.isNotEmpty) _buildWarningsSection(context, warnings),

            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildDetectionSection(BuildContext context, Map<String, dynamic> detected) {
    final surface = detected['surface'] as String? ?? 'unknown';
    final stain = detected['stain'] as String? ?? 'unknown';
    final confidence = (detected['confidence'] as num?)?.toDouble() ?? 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detection',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildInfoChip(
                  context,
                  icon: Icons.layers,
                  label: 'Surface',
                  value: _formatLabel(surface),
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildInfoChip(
                  context,
                  icon: Icons.opacity,
                  label: 'Stain',
                  value: _formatLabel(stain),
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.verified, size: 16, color: Colors.green[700]),
              const SizedBox(width: 4),
              Text(
                'Confidence: ${(confidence * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  color: Colors.green[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(),
        ],
      ),
    );
  }

  Widget _buildInfoChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepsSection(BuildContext context, List<String> steps) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cleaning Steps',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          ...steps.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      step.replaceFirst(RegExp(r'^Step \d+:\s*', caseSensitive: false), ''),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          const Divider(),
        ],
      ),
    );
  }

  Widget _buildProductsSection(BuildContext context, Map<String, dynamic> products) {
    final recommended = (products['recommended'] as List<dynamic>?)?.cast<String>() ?? [];
    final avoid = (products['avoid'] as List<dynamic>?)?.cast<String>() ?? [];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Products',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          if (recommended.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                const SizedBox(width: 8),
                Text(
                  'Recommended',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...recommended.map((product) => Padding(
                  padding: const EdgeInsets.only(left: 28, bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, size: 6, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(child: Text(product)),
                    ],
                  ),
                )),
            const SizedBox(height: 12),
          ],
          if (avoid.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.cancel, color: Colors.red[700], size: 20),
                const SizedBox(width: 8),
                Text(
                  'Avoid',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.red[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...avoid.map((product) => Padding(
                  padding: const EdgeInsets.only(left: 28, bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, size: 6, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(child: Text(product)),
                    ],
                  ),
                )),
          ],
          const SizedBox(height: 8),
          const Divider(),
        ],
      ),
    );
  }

  Widget _buildWarningsSection(BuildContext context, List<String> warnings) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange[300]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange[900]),
                const SizedBox(width: 8),
                Text(
                  'Important Warnings',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[900],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...warnings.map((warning) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.circle,
                        size: 6,
                        color: Colors.orange[900],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          warning,
                          style: TextStyle(color: Colors.orange[900]),
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

  String _formatLabel(String label) {
    return label
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isEmpty ? word : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}
