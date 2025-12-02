import 'package:flutter/material.dart';
import 'package:green/screens/3d_monitor.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const Color _bg = Color(0xFF050505);
  static const Color _accent = Color(0xFFFF2D55);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headline = theme.textTheme.displaySmall?.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w600,
      letterSpacing: -1,
    );
    final body = theme.textTheme.bodyLarge?.copyWith(color: Colors.white70);

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 520;
            final horizontal = isCompact ? 16.0 : 24.0;
            final vertical = isCompact ? 24.0 : 32.0;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _heroSection(context, headline, body, compact: isCompact),
                      const SizedBox(height: 24),
                      const Text(
                        '© Simone / See You in 3D',
                        style: TextStyle(color: Colors.white38, letterSpacing: 1),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _heroSection(
    BuildContext context,
    TextStyle? headline,
    TextStyle? body, {
    required bool compact,
  }) {
    return _card(
      padding: EdgeInsets.symmetric(horizontal: compact ? 24 : 36, vertical: compact ? 28 : 40),
      borderRadius: compact ? 26 : 32,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, color: _accent, size: 10),
                  SizedBox(width: 8),
                  Text('Live prototype', style: TextStyle(color: Colors.white70, letterSpacing: 1)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('See You in 3D', style: headline),
          const SizedBox(height: 12),
          Text(
            'A monochrome stage with a single red pulse. Stream your camera and watch your hand + face fuse into one mesh. Crafted by Simone.',
            style: body,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: compact ? double.infinity : null,
            child: FilledButton(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const Monitor3D()));
              },
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 18),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              child: const Text('Launch live capture'),
            ),
          ),
        ],
      ),
    );
  }


  Widget _card({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(24),
    double borderRadius = 32,
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: child,
    );
  }
}

