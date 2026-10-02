import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/controller.dart';
import '../core/prefs.dart';
import '../core/theme.dart';
import 'widgets.dart';
import '../core/units.dart';
import 'welcome_screen.dart';

const privacyUrl =
    'https://soulfulfillable.github.io/test-mvp/speedometer-privacy.html';

/// 링크 열기 — 테스트에서 가짜로 바꾼다.
Future<void> Function(Uri) openLink = (u) async {
  await launchUrl(u, mode: LaunchMode.externalApplication);
};

Future<void> showSettingsSheet(
  BuildContext context,
  SpeedController c,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (ctx) => ListenableBuilder(
    listenable: c,
    builder: (ctx, _) {
      Widget seg<T>(
        String keyPrefix,
        List<T> values,
        T selected,
        String Function(T) label,
        String Function(T) name,
        void Function(T) onTap,
      ) {
        return Container(
          height: 44,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: C.bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              for (final v in values)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: v == selected,
                    label: label(v),
                    excludeSemantics: true,
                    child: GestureDetector(
                      key: Key('$keyPrefix-${name(v)}'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTap(v),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: v == selected ? C.accent : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          label(v),
                          style: TextStyle(
                            color: v == selected ? C.bg : C.sub,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      }

      const h = TextStyle(
        color: C.sub,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      );
      return SheetFrame(
        title: 'Settings',
        doneKey: 'settings-done',
        children: [
          const SizedBox(height: 14),
          Text('UNITS · ${c.mode.label.toUpperCase()}', style: h),
          const SizedBox(height: 6),
          seg<SpeedUnit>(
            'unit',
            c.mode.units,
            c.unit,
            (u) => u.label,
            (u) => u.name,
            c.setUnit,
          ),
          const SizedBox(height: 14),
          const Text('DISPLAY', style: h),
          const SizedBox(height: 6),
          seg<Display>(
            'display',
            Display.values,
            c.display,
            (d) => d == Display.digital ? 'Digits' : 'Gauge',
            (d) => d.name,
            c.setDisplay,
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            key: const Key('mirror-switch'),
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Mirror in HUD mode',
              style: TextStyle(color: C.ink),
            ),
            subtitle: const Text(
              'Flip the numbers so they read right on the windshield.',
              style: TextStyle(color: C.sub),
            ),
            value: c.hudMirror,
            onChanged: c.setHudMirror,
          ),
          ListTile(
            key: const Key('safety'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.health_and_safety_outlined, color: C.sub),
            title: const Text('Driving safety', style: TextStyle(color: C.ink)),
            trailing: const Icon(Icons.chevron_right, color: C.muted),
            onTap: () => showSafetyDialog(ctx),
          ),
          ListTile(
            key: const Key('privacy'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.lock_outline, color: C.sub),
            title: const Text('Privacy Policy', style: TextStyle(color: C.ink)),
            trailing: const Icon(Icons.open_in_new, color: C.muted, size: 20),
            onTap: () => openLink(Uri.parse(privacyUrl)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Version 1.0 · No account, no subscription. Your location never leaves this device.',
            style: TextStyle(color: C.muted, fontSize: 12, height: 1.35),
          ),
        ],
      );
    },
  ),
);
