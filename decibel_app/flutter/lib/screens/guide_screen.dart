import 'package:flutter/material.dart';

import '../core/levels.dart';
import '../core/theme.dart';

/// "얼마나 시끄러운 거야?" — 숫자를 소리 비유로. 지금 레벨에 해당하는 줄을 강조한다.
class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key, this.current, this.unit = 'dBA'});
  final double? current;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final here = current == null ? null : refOf(current!);
    return Scaffold(
      appBar: AppBar(title: const Text('How loud is that?')),
      body: ListView(
        key: const Key('guide-list'),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          if (current != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Right now: ${fmtDb(current!)} $unit — ${likeText(current!).toLowerCase()}.',
                key: const Key('guide-now'),
                style: const TextStyle(
                  color: C.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          for (final r in refs.reversed) _row(r, r == here),
          const SizedBox(height: 20),
          _safety(),
          const SizedBox(height: 14),
          const Text(
            'Typical levels from the CDC and NIDCD. Real sounds vary with distance.',
            style: TextStyle(color: C.muted, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _row(Ref r, bool here) {
    final band = bandOf(r.db.toDouble());
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: here ? band.color.withValues(alpha: 0.18) : C.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: here ? band.color : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              '${r.db}',
              style: TextStyle(
                color: band.color,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Icon(r.icon, color: C.sub, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              r.title,
              style: const TextStyle(color: C.ink, fontSize: 15),
            ),
          ),
          if (here)
            Container(
              key: const Key('guide-here'),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: band.color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'NOW',
                style: TextStyle(
                  color: Color(0xFF10151D),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _safety() {
    const rows = [
      (85, '8 hours'),
      (88, '4 hours'),
      (91, '2 hours'),
      (94, '1 hour'),
      (97, '30 minutes'),
      (100, '15 minutes'),
      (106, 'under 4 minutes'),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: C.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.hearing, color: C.accent, size: 20),
              SizedBox(width: 8),
              Text(
                'Hearing safety',
                style: TextStyle(
                  color: C.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'NIOSH recommends limiting daily exposure. Every 3 dB louder halves the safe time.',
            style: TextStyle(color: C.sub, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 10),
          for (final (db, t) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(
                      '$db dBA',
                      style: TextStyle(
                        color: bandOf(db.toDouble()).color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(t, style: const TextStyle(color: C.ink)),
                ],
              ),
            ),
          const SizedBox(height: 6),
          const Text(
            'Source: CDC/NIOSH recommended exposure limit (85 dBA for 8 hours). '
            'This is general information, not medical advice.',
            style: TextStyle(color: C.muted, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}
