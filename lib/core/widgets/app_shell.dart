import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppBackdrop extends StatelessWidget {
  const AppBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.cream, Color(0xFFE8F1EB), Color(0xFFF7F1E6)],
            ),
          ),
        ),
        Positioned(
          top: -90,
          right: -30,
          child: _GlowOrb(
            size: 260,
            colors: const [Color(0x55C07A45), Color(0x00C07A45)],
          ),
        ),
        Positioned(
          left: -80,
          top: 120,
          child: _GlowOrb(
            size: 240,
            colors: const [Color(0x5517493D), Color(0x0017493D)],
          ),
        ),
        Positioned(
          right: 120,
          bottom: -100,
          child: _GlowOrb(
            size: 320,
            colors: const [Color(0x33268B73), Color(0x00268B73)],
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class AppPanel extends StatelessWidget {
  const AppPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.gradient,
    this.radius = 32,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;
  final double radius;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient:
            gradient ??
            LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.88),
                AppTheme.surfaceSoft.withValues(alpha: 0.78),
              ],
            ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: child,
    );
  }
}

class AppMetricChip extends StatelessWidget {
  const AppMetricChip({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.backgroundColor,
    this.labelColor,
    this.valueColor,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? labelColor;
  final Color? valueColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Container(
      constraints: const BoxConstraints(minWidth: 160),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.85)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: valueColor ?? AppTheme.pine),
            const SizedBox(width: 10),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: labelColor ?? AppTheme.ink.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: valueColor ?? AppTheme.ink,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: content,
      ),
    );
  }
}

class AppGuideStep extends StatelessWidget {
  const AppGuideStep({
    super.key,
    required this.step,
    required this.title,
    required this.description,
    this.dark = false,
  });

  final String step;
  final String title;
  final String description;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = dark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.74);
    final border = dark
        ? Colors.white.withValues(alpha: 0.18)
        : AppTheme.border;
    final stepFill = dark ? Colors.white : AppTheme.pine;
    final stepText = dark ? AppTheme.pine : Colors.white;
    final titleColor = dark ? Colors.white : AppTheme.ink;
    final bodyColor = dark
        ? Colors.white.withValues(alpha: 0.78)
        : AppTheme.ink.withValues(alpha: 0.72);

    return Container(
      constraints: const BoxConstraints(minWidth: 220),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: stepFill, shape: BoxShape.circle),
            child: Text(
              step,
              style: theme.textTheme.labelMedium?.copyWith(color: stepText),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(color: bodyColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.colors});

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: colors),
        ),
      ),
    );
  }
}
