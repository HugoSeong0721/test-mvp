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
              colors: [Color(0xFFF7F5F0), Color(0xFFF1F4EF)],
            ),
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
    this.padding = const EdgeInsets.all(22),
    this.gradient,
    this.radius = 18,
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
        gradient: gradient,
        color: gradient == null ? Colors.white.withValues(alpha: 0.94) : null,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? AppTheme.border.withValues(alpha: 0.78),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 14,
            offset: const Offset(0, 6),
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
    this.helper,
    this.helperColor,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? labelColor;
  final Color? valueColor;
  final String? helper;
  final Color? helperColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Container(
      constraints: const BoxConstraints(minWidth: 136),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                style: theme.textTheme.titleSmall?.copyWith(
                  color: valueColor ?? AppTheme.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (helper != null && helper!.trim().isNotEmpty) ...[
                const SizedBox(height: 5),
                SizedBox(
                  width: 104,
                  child: Text(
                    helper!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          helperColor ??
                          (labelColor ?? AppTheme.ink.withValues(alpha: 0.62)),
                      height: 1.2,
                    ),
                  ),
                ),
              ],
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
      constraints: const BoxConstraints(minWidth: 210),
      padding: const EdgeInsets.all(14),
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
