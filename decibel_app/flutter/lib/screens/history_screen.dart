import 'package:flutter/material.dart';

import '../core/history.dart';
import '../core/levels.dart';
import '../core/store.dart';
import '../core/theme.dart';
import 'report_screen.dart';

/// 지난 측정 목록. 측정은 자동으로 여기 저장된다 — 나중에 리포트로 만들 수 있게.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  Future<void> _delete(BuildContext context, NoiseRecord r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this measurement?'),
        content: Text('${fmtDate(r.startedAt)}, ${fmtClock(r.startedAt)}'),
        actions: [
          TextButton(
            key: const Key('delete-cancel'),
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('delete-ok'),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete', style: TextStyle(color: C.red)),
          ),
        ],
      ),
    );
    if (ok == true) await AppStore.i.deleteRecord(r.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: AnimatedBuilder(
        animation: AppStore.i,
        builder: (context, _) {
          final rs = AppStore.i.records;
          if (rs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No measurements yet.\nEvery measurement is saved here automatically, so you can make a report later.',
                  key: Key('history-empty'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: C.sub, fontSize: 15, height: 1.5),
                ),
              ),
            );
          }
          return ListView.separated(
            key: const Key('history-list'),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: rs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final r = rs[i];
              final band = bandOf(r.average);
              return Material(
                color: C.card,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  key: Key('record-${r.id}'),
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ReportScreen(recordId: r.id),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: band.color.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            fmtDb(r.average),
                            style: TextStyle(
                              color: band.color,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${fmtDateShort(r.startedAt)}, ${fmtClock(r.startedAt)}',
                                style: const TextStyle(
                                  color: C.ink,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                recordSummary(r),
                                style: const TextStyle(
                                  color: C.sub,
                                  fontSize: 13,
                                ),
                              ),
                              if (r.note.isNotEmpty)
                                Text(
                                  r.note,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: C.muted,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          key: Key('delete-${r.id}'),
                          tooltip: 'Delete',
                          icon: const Icon(
                            Icons.delete_outline,
                            color: C.muted,
                          ),
                          onPressed: () => _delete(context, r),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
