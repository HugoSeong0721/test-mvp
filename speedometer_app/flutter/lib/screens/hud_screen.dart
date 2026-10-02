import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/controller.dart';
import '../core/theme.dart';
import 'speed_display.dart';
import 'widgets.dart';

/// HUD — 폰을 대시보드에 눕혀 두면 앞유리에 비친 숫자가 바로 읽히게 좌우 반전.
/// 까만 바탕에 숫자만. 광고 없음. 화면을 탭하면 나가기 버튼이 잠깐 나온다.
class HudScreen extends StatefulWidget {
  const HudScreen({super.key, required this.c});
  final SpeedController c;

  static const controlsFor = Duration(seconds: 4);

  @override
  State<HudScreen> createState() => _HudScreenState();
}

class _HudScreenState extends State<HudScreen> {
  bool _controls = true;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _showControls();
  }

  void _showControls() {
    setState(() => _controls = true);
    _hide?.cancel();
    _hide = Timer(HudScreen.controlsFor, () {
      if (mounted) setState(() => _controls = false);
    });
  }

  @override
  void dispose() {
    _hide?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.c,
    builder: (context, _) {
      final c = widget.c;
      final r = Reading(c);
      final color = r.over ? C.red : C.accent;
      return Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          key: const Key('hud-area'),
          behavior: HitTestBehavior.opaque,
          onTap: _showControls,
          child: Stack(
            children: [
              if (r.over)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: C.red, width: 14),
                      ),
                    ),
                  ),
                ),
              Positioned.fill(
                child: SafeArea(
                  child: Transform.flip(
                    flipX: c.hudMirror,
                    child: LayoutBuilder(
                      builder: (context, box) {
                        const style = TextStyle(
                          fontWeight: FontWeight.w800,
                          height: 1,
                          letterSpacing: -2,
                          fontFeatures: tabular,
                        );
                        final size = fitFontSize(
                          r.sample,
                          Size(box.maxWidth - 24, box.maxHeight * 0.5),
                          style,
                        );
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Opacity(
                              opacity: r.opacity,
                              child: Text(
                                r.big,
                                key: const Key('hud-speed'),
                                style: style.copyWith(
                                  fontSize: size,
                                  color: color,
                                ),
                              ),
                            ),
                            Text(
                              r.bigLabel,
                              style: TextStyle(
                                color: color,
                                fontSize: size * 0.18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 3,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
              // 반전되지 않는 조작 버튼
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                left: 16,
                right: 16,
                bottom: _controls ? 24 : -120,
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: BigButton(
                          key: const Key('hud-mirror'),
                          icon: Icons.flip,
                          label: c.hudMirror ? 'Mirror: On' : 'Mirror: Off',
                          active: c.hudMirror,
                          onTap: () {
                            c.setHudMirror(!c.hudMirror);
                            _showControls();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: BigButton(
                          key: const Key('hud-exit'),
                          icon: Icons.close,
                          label: 'Exit HUD',
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_controls)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        c.hudMirror
                            ? 'Lay your phone flat under the windshield at night.'
                            : 'Mirror is off — numbers read normally.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: C.sub, fontSize: 14),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
