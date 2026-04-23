// lib/src/ui/screens/tamper_detected_screen.dart

import 'package:flutter/material.dart';

/// Shown when a critical tampering attempt is detected.
class TamperDetectedScreen extends StatelessWidget {
  const TamperDetectedScreen({
    super.key,
    this.tamperTypes = const [],
    this.onContactSupport,
  });

  final List<String> tamperTypes;
  final VoidCallback? onContactSupport;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0000),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Shield icon
              const Icon(Icons.gpp_bad_outlined,
                  size: 100, color: Colors.redAccent),
              const SizedBox(height: 24),

              // Title
              const Text(
                'Security Violation Detected',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              const Text(
                'This application has detected unauthorized modifications. '
                'For your security, the application has been locked.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Color(0xFFFFCDD2), fontSize: 14),
              ),
              const SizedBox(height: 24),

              // Tamper type list
              if (tamperTypes.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900.withAlpha(128),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.red.shade700),
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text('Detected Issues:',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                      const SizedBox(height: 8),
                      ...tamperTypes.map(
                        (t) => Padding(
                          padding:
                              const EdgeInsets.symmetric(
                                  vertical: 2),
                          child: Row(
                            children: [
                              const Icon(
                                  Icons.warning_amber_rounded,
                                  size: 14,
                                  color: Colors.redAccent),
                              const SizedBox(width: 8),
                              Text(
                                t.replaceAll('_', ' ')
                                    .toUpperCase(),
                                style: const TextStyle(
                                    color: Color(0xFFFFCDD2),
                                    fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 32),

              const Text(
                'Recommended actions:\n'
                '• Reinstall the application\n'
                '• Restore the system clock to the correct time\n'
                '• Contact support if the issue persists',
                style: TextStyle(
                    color: Color(0xFFFFCDD2), fontSize: 13),
              ),
              const SizedBox(height: 24),

              OutlinedButton.icon(
                onPressed: onContactSupport,
                icon: const Icon(Icons.support_agent_rounded,
                    color: Colors.white),
                label: const Text('Contact Support',
                    style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white54),
                  padding:
                      const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
