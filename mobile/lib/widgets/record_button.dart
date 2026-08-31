import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class RecordButton extends StatefulWidget {
  final bool isRecording;
  final bool enabled;
  final VoidCallback onPressed;

  const RecordButton({
    super.key,
    required this.isRecording,
    required this.onPressed,
    this.enabled = true,
  });

  @override
  State<RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<RecordButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    if (widget.isRecording) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant RecordButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.isRecording && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.isRecording
        ? const [Color(0xFFC45C72), Color(0xFF8E4458)]
        : const [AppColors.accentPurple, AppColors.accent];
    final glow = widget.isRecording ? AppColors.record : AppColors.accent;

    return SizedBox(
      width: 128,
      height: 128,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final scale = widget.isRecording ? 1 + (_pulse.value * 0.06) : 1.0;
          return Transform.scale(
            scale: scale,
            transformHitTests: false,
            child: child,
          );
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
            boxShadow: [
              BoxShadow(
                color: glow.withValues(alpha: 0.32),
                blurRadius: 22,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: widget.enabled ? widget.onPressed : null,
              child: SizedBox(
                width: 128,
                height: 128,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                      size: 44,
                      color: AppColors.text,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.isRecording ? 'DURDUR' : 'DİNLE',
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
