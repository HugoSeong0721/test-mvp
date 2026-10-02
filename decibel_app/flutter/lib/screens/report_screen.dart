import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../core/history.dart';
import '../core/levels.dart';
import '../core/meter.dart';
import '../core/share.dart';
import '../core/store.dart';
import '../core/theme.dart';
import 'widgets.dart';

/// 소음 기록 리포트 — 이웃·집주인에게 보낼 수 있게 한 장짜리 이미지로 저장/공유.
/// (1등 앱은 이 기능을 유료로 막았다. 여기서는 무료.)
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key, required this.recordId});
  final int recordId;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _shot = GlobalKey();
  late final TextEditingController _note;
  bool _busy = false;
  Timer? _noteSave;

  NoiseRecord? get record => AppStore.i.recordById(widget.recordId);

  @override
  void initState() {
    super.initState();
    _note = TextEditingController(text: record?.note ?? '');
  }

  @override
  void dispose() {
    _noteSave?.cancel();
    AppStore.i.setNote(widget.recordId, _note.text.trim());
    _note.dispose();
    super.dispose();
  }

  void _onNote(String _) {
    setState(() {}); // 리포트 미리보기에 바로 반영
    _noteSave?.cancel();
    _noteSave = Timer(
      const Duration(milliseconds: 600),
      () => AppStore.i.setNote(widget.recordId, _note.text.trim()),
    );
  }

  Future<void> _share() async {
    final r = record;
    if (r == null || _busy) return;
    setState(() => _busy = true);
    FocusScope.of(context).unfocus();
    final messenger = ScaffoldMessenger.of(context);
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    await AppStore.i.setNote(widget.recordId, _note.text.trim());
    var ok = false;
    try {
      final boundary =
          _shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data != null) {
        final t = r.startedAt;
        String two(int v) => v.toString().padLeft(2, '0');
        final name =
            'noise-report-${t.year}-${two(t.month)}-${two(t.day)}-${two(t.hour)}${two(t.minute)}.png';
        ok = await Outside.i.shareImage(
          data.buffer.asUint8List(),
          name,
          'Noise report — ${fmtDate(t)}',
          origin,
        );
      }
    } catch (e) {
      debugPrint('report image failed: $e');
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not share the image. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = record;
    return Scaffold(
      appBar: AppBar(title: const Text('Noise Report')),
      body: r == null
          ? const Center(
              child: Text(
                'This measurement was deleted.',
                style: TextStyle(color: C.sub),
              ),
            )
          : SingleChildScrollView(
              key: const Key('report-list'),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 메모 칸은 위에 — 키보드가 떠도 가려지지 않고, 적는 대로 아래 리포트에 들어간다.
                  TextField(
                    key: const Key('note'),
                    controller: _note,
                    onChanged: _onNote,
                    maxLength: 120,
                    textInputAction: TextInputAction.done,
                    style: const TextStyle(color: C.ink),
                    decoration: InputDecoration(
                      labelText: 'Add a note (optional)',
                      hintText: 'e.g. Upstairs neighbor, Apt 4B',
                      filled: true,
                      fillColor: C.card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  RepaintBoundary(
                    key: _shot,
                    child: ReportCard(record: r, note: _note.text.trim()),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    key: const Key('share'),
                    onPressed: _busy ? null : _share,
                    icon: const Icon(Icons.ios_share),
                    label: Text(_busy ? 'Preparing…' : 'Save or Share Image'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tip: choose "Save Image" in the share sheet to keep it in Photos.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: C.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
    );
  }
}

/// 리포트 한 장 (흰 종이). 화면과 저장 이미지가 똑같다.
class ReportCard extends StatelessWidget {
  const ReportCard({super.key, required this.record, required this.note});
  final NoiseRecord record;
  final String note;

  @override
  Widget build(BuildContext context) {
    final r = record;
    final unit = r.weighting.unit;
    final loud = r.loudestSecond;
    final stats = downsample(r.leq, r.peaks, 90);
    final per = r.secondsPerBand();
    final total = r.leq.isEmpty ? 1 : r.leq.length;
    final trim = r.offset - AppStore.defaultOffset;
    final trimText =
        '${trim >= 0 ? '+' : '−'}${trim.abs().toStringAsFixed(1)} dB';
    final mid = r.timeOfSecond(r.leq.length ~/ 2);
    const ink = TextStyle(color: C.paperInk);

    Widget big(String label, double v) => Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: C.paperSub,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text.rich(
            TextSpan(
              text: fmtDb(v),
              style: const TextStyle(
                color: C.paperInk,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
              children: [
                TextSpan(
                  text: ' $unit',
                  style: const TextStyle(
                    fontSize: 12,
                    color: C.paperSub,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Container(
      key: const Key('report-card'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: C.paper,
        borderRadius: BorderRadius.circular(16),
      ),
      child: DefaultTextStyle(
        style: ink,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.graphic_eq,
                  color: Color(0xFF1A8FC4),
                  size: 22,
                ),
                const SizedBox(width: 6),
                const Text(
                  'Noise Report',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: C.paperInk,
                  ),
                ),
                const Spacer(),
                Text(
                  unit,
                  style: const TextStyle(
                    fontSize: 12,
                    color: C.paperSub,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              fmtDate(r.startedAt),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: C.paperInk,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${fmtClock(r.startedAt)} – ${fmtClock(r.endedAt)}  ·  ${fmtDurationWords(r.duration)} measured',
              key: const Key('report-time'),
              style: const TextStyle(fontSize: 13, color: C.paperSub),
            ),
            if (note.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F5F8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  note,
                  key: const Key('report-note'),
                  style: const TextStyle(
                    fontSize: 13,
                    color: C.paperInk,
                    height: 1.35,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                big('AVERAGE', r.average),
                big('MAX', r.max),
                big('MIN', r.min),
              ],
            ),
            if (loud != null) ...[
              const SizedBox(height: 10),
              Text.rich(
                TextSpan(
                  text: 'Loudest moment: ',
                  style: const TextStyle(color: C.paperSub, fontSize: 13),
                  children: [
                    TextSpan(
                      text:
                          '${fmtClock(r.timeOfSecond(loud), seconds: true)} (${fmtDb(r.peaks[loud])} $unit)',
                      style: const TextStyle(
                        color: C.paperInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                key: const Key('report-loudest'),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              height: 130,
              child: ReportChart(
                stats: stats,
                labels: [
                  // 10분 안쪽이면 초까지 (안 그러면 "8:46 PM" 만 세 번 나온다)
                  for (final x in [r.startedAt, mid, r.endedAt])
                    fmtClock(x, seconds: r.duration.inMinutes < 10),
                ],
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Bars: average each moment · Line: peak',
              style: TextStyle(fontSize: 10, color: C.paperSub),
            ),
            const SizedBox(height: 12),
            const Text(
              'Time at each level',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: C.paperInk,
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: SizedBox(
                key: const Key('band-bar'),
                height: 10,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final b in bands)
                      if (per[b]! > 0)
                        Expanded(
                          flex: per[b]!,
                          child: ColoredBox(color: b.color),
                        ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              runSpacing: 2,
              children: [
                for (final b in bands)
                  if (per[b]! > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: b.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${b.name} ${(per[b]! * 100 / total).round()}%',
                          style: const TextStyle(
                            fontSize: 11,
                            color: C.paperSub,
                          ),
                        ),
                      ],
                    ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: C.paperLine),
            const SizedBox(height: 8),
            Text(
              'Measured with $kAppName on iPhone · ${r.weighting.name.toUpperCase()}-weighting, Fast · '
              'calibration $trimText. Phone microphones are not certified sound level meters; '
              'readings are estimates.',
              key: const Key('report-footer'),
              style: const TextStyle(
                fontSize: 10,
                color: C.paperSub,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 기록 목록 한 줄에 쓰는 요약.
String recordSummary(NoiseRecord r) =>
    'Avg ${fmtDb(r.average)} · Max ${fmtDb(r.max)} ${r.weighting.unit} · ${fmtDurationWords(r.duration)}';
