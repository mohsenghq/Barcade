/// Shared animated widgets for the Cosmic Toybox system. Everything here is
/// hand-rolled with Flutter's implicit animations (no animation-package magic)
/// so motion, easing and timing come from one place — the Ct tokens.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'cosmic_toybox.dart';

// ------------------------------------------------------------- background

/// Deep-space gradient + drifting motes behind every screen.
class CosmicBackground extends StatelessWidget {
  const CosmicBackground({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(gradient: Ct.background),
        ),
        const _MoteField(count: 24),
        ?child,
      ],
    );
  }
}

class _MoteField extends StatefulWidget {
  const _MoteField({required this.count});
  final int count;
  @override
  State<_MoteField> createState() => _MoteFieldState();
}

class _MoteFieldState extends State<_MoteField> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 22),
  )..repeat();

  // Deterministic pseudo-random layout so the field is stable across frames.
  late final List<_Mote> _motes = List.generate(widget.count, (i) {
    final rnd = math.Random(i * 7919);
    return _Mote(
      x: rnd.nextDouble(),
      y: rnd.nextDouble(),
      size: 1.5 + rnd.nextDouble() * 2.5,
      opacity: 0.25 + rnd.nextDouble() * 0.55,
      speed: 0.6 + rnd.nextDouble() * 1.4,
      drift: rnd.nextDouble() * 2 * math.pi,
    );
  });

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return CustomPaint(
          painter: _MotePainter(motes: _motes, t: _c.value),
        );
      },
    );
  }
}

class _Mote {
  const _Mote({
    required this.x,
    required this.y,
    required this.size,
    required this.opacity,
    required this.speed,
    required this.drift,
  });
  final double x, y, size, opacity, speed, drift;
}

class _MotePainter extends CustomPainter {
  _MotePainter({required this.motes, required this.t});
  final List<_Mote> motes;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Ct.cyan;
    for (final m in motes) {
      final yy = (m.y + t * 0.05 * m.speed) % 1.0;
      final xx = (m.x + 0.02 * math.sin(t * m.speed * 2 + m.drift)) % 1.0;
      paint.color = Ct.cyan.withValues(alpha: m.opacity * (0.6 + 0.4 * math.sin(t * 2 * math.pi * m.speed + m.drift)));
      canvas.drawCircle(
        Offset(xx * size.width, yy * size.height),
        m.size * 0.6 + m.size * 0.4 * math.sin(t * 3 + m.drift),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MotePainter old) => old.t != t;
}

// ---------------------------------------------------------------- entrance

/// Scale + fade entrance with easeOutBack. Wrap any element that should pop
/// into view (cards, headers, result panels).
class PopIn extends StatelessWidget {
  const PopIn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Ct.popIn,
      curve: Ct.easeOutBack,
      builder: (context, t, c) => Transform.scale(
        // easeOutBack overshoots past 1; keep that for scale, clamp for opacity.
        scale: 0.6 + 0.4 * t,
        child: Opacity(opacity: t.clamp(0.0, 1.0), child: c),
      ),
      child: child,
    );
  }
}

/// Small entrance used for chips/pills.
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({super.key, required this.child, this.offset = 12});
  final Widget child;
  final double offset;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Ct.enter,
      curve: Curves.easeOutCubic,
      builder: (context, v, c) => Transform.translate(
        offset: Offset(0, offset * (1 - v)),
        child: Opacity(opacity: v, child: c),
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------- buttons

/// The primary action button: squash on press, soft glow behind.
class GlowButton extends StatefulWidget {
  const GlowButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.filled = true,
    this.minSize = const Size(200, 56),
  });

  final Widget child;
  final VoidCallback onPressed;
  final bool filled;
  final Size minSize;

  @override
  State<GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<GlowButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.filled
        ? Ct.coral
        : Ct.surfaceStrong;
    final border = widget.filled ? null : Border.all(color: Ct.surfaceStroke);
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _down ? 0.92 : 1,
        duration: Ct.press,
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: Ct.press,
          curve: Curves.easeOutCubic,
          constraints: BoxConstraints(
            minWidth: widget.minSize.width,
            minHeight: widget.minSize.height,
          ),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: Ct.radius,
            border: border,
            boxShadow: widget.filled && !_down ? [Ct.glowShadow] : null,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Small tappable chip (settings toggle, hub secondary action).
class PillButton extends StatelessWidget {
  const PillButton({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Ct.surfaceStrong,
      borderRadius: Ct.radiusSmall,
      child: InkWell(
        borderRadius: Ct.radiusSmall,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge!.copyWith(fontSize: 14),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- indicators

/// Counts from zero to [value] on change. Animates currency/score numbers.
class AnimatedCounter extends StatelessWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    this.duration = const Duration(milliseconds: 550),
    this.style,
  });

  final int value;
  final Duration duration;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(
        v.round().toString(),
        style: style,
      ),
    );
  }
}

/// XP bar with the level badge. Progress animates whenever XP changes.
class XpBar extends StatelessWidget {
  const XpBar({
    super.key,
    required this.level,
    required this.progress,
    this.height = 10,
  });

  final int level;
  final double progress;
  final double height;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: Stack(
          children: [
            Container(height: height, color: Ct.surfaceStrong),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: v,
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Ct.cyan, Ct.mint],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Ct.cyan.withValues(alpha: 0.5),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Row of 1-3 stars that pop in sequentially. [count] 0 renders nothing.
class StarsRow extends StatelessWidget {
  const StarsRow({super.key, required this.count, this.size = 26});

  final int count;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final filled = i < count;
        final visible = filled;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: visible ? 1 : 0),
            duration: const Duration(milliseconds: 450),
            curve: Ct.easeOutBack,
            builder: (context, v, c) => Transform.scale(
              scale: 0.3 + 0.7 * v,
              child: Opacity(
                opacity: v.clamp(0.0, 1.0),
                child: Icon(
                  Icons.star_rounded,
                  size: size,
                  color: filled ? Ct.gold : Ct.white.withValues(alpha: 0.15),
                ),
              ),
            ),
            child: const SizedBox.shrink(),
          ),
        );
      }),
    );
  }
}

// ------------------------------------------------------------- celebration

/// One-shot confetti burst behind a victory / level-up overlay. Particles rise
/// from the bottom, arc under gravity, and fade. Deterministic seed so golden
/// tests stay stable.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, this.count = 40, this.duration = const Duration(milliseconds: 1600)});

  final int count;
  final Duration duration;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration)..forward();

  late final List<_Confetto> _pieces = List.generate(widget.count, (i) {
    final rnd = math.Random(104729 + i * 31); // deterministic per index
    return _Confetto(
      x: rnd.nextDouble(),
      vx: (rnd.nextDouble() - 0.5) * 0.7,
      vy: 0.55 + rnd.nextDouble() * 0.5,
      spin: (rnd.nextDouble() - 0.5) * 10,
      size: 5 + rnd.nextDouble() * 4,
      color: const [Ct.gold, Ct.coral, Ct.cyan, Ct.mint][rnd.nextInt(4)],
    );
  });

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          painter: _ConfettiPainter(pieces: _pieces, t: _c.value),
        ),
      ),
    );
  }
}

class _Confetto {
  const _Confetto({
    required this.x,
    required this.vx,
    required this.vy,
    required this.spin,
    required this.size,
    required this.color,
  });

  final double x, vx, vy, spin, size;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.pieces, required this.t});

  final List<_Confetto> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    // k compresses the burst into the first half of the timeline; after that the
    // pieces have mostly fallen out of view and only the fade remains.
    final k = (t * 2.2).clamp(0.0, 1.0);
    final alpha = (1 - t / 1.1).clamp(0.0, 1.0);
    for (final p in pieces) {
      final y = size.height * (0.92 - p.vy * k + 0.5 * k * k * 2.6);
      final x = (p.x + p.vx * k) * size.width;
      if (y < -20 || y > size.height + 20) continue;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * t * 3);
      paint.color = p.color.withValues(alpha: alpha);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => oldDelegate.t != t;
}
