import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/data/clinic_data_store.dart';
import '../../../core/services/app_firestore_service.dart';
import '../../../core/services/beta_session_service.dart';
import '../../../core/services/patient_profile_service.dart';
import '../../../core/settings/app_language_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/language_menu_button.dart';
import '../../../core/widgets/patient_shell.dart';
import '../../../core/widgets/patient_clinic_context_panel.dart';
import '../../patient_home/presentation/patient_home_screen.dart';

class VisitHistoryScreen extends StatefulWidget {
  const VisitHistoryScreen({super.key});

  static const routeName = '/patient-history';

  @override
  State<VisitHistoryScreen> createState() => _VisitHistoryScreenState();
}

class _VisitHistoryScreenState extends State<VisitHistoryScreen> {
  final ClinicDataStore _store = ClinicDataStore.instance;
  final Map<String, TextEditingController> _feedbackControllers = {};
  final Set<String> _submittingVisitIds = <String>{};
  PatientProfile? _sessionBackedProfile;

  PatientProfile get _currentProfile =>
      _sessionBackedProfile ?? _store.currentPatientProfile;

  List<ScheduledVisit> get _history =>
      _store.activeClinicForPatient(_currentProfile.id) == null
      ? const []
      : _store.historyForPatient(
          _currentProfile.id,
          clinicId: _store.activeClinicForPatient(_currentProfile.id)!.id,
        );

  @override
  void initState() {
    super.initState();
    unawaited(_initializeProfile());
  }

  @override
  void dispose() {
    for (final controller in _feedbackControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _initializeProfile() async {
    final session =
        BetaSessionService.currentSession ??
        await BetaSessionService.currentSessionAsync();
    if (!mounted) {
      return;
    }

    if (session == null) {
      setState(() => _sessionBackedProfile = null);
      return;
    }

    try {
      final localProfile = await PatientProfileService.loadLocalProfile(
        session.id,
      );
      if (mounted && localProfile != null) {
        setState(() {
          _sessionBackedProfile = localProfile;
        });
      }
    } catch (_) {}

    unawaited(
      PatientProfileService.ensureProfileForSession(session)
          .then((_) async {
            final refreshed = await PatientProfileService.loadLocalProfile(
              session.id,
            );
            if (!mounted || refreshed == null) {
              return;
            }
            setState(() {
              _sessionBackedProfile = refreshed;
            });
          })
          .catchError((_) {}),
    );
  }

  TextEditingController _controllerFor(String visitId, String initialText) {
    return _feedbackControllers.putIfAbsent(visitId, () {
      return TextEditingController(text: initialText);
    });
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  DateTime? _parseStoredDate(String value) {
    try {
      final parts = value.split('-');
      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    } catch (_) {
      return null;
    }
  }

  String _weekdayShort(DateTime date) {
    const english = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const korean = ['월', '화', '수', '목', '금', '토', '일'];
    return AppLanguageController.instance.tr(
      english[date.weekday - 1],
      korean[date.weekday - 1],
    );
  }

  String _formatDateWithWeekday(DateTime date) {
    return '${_formatDate(date)} (${_weekdayShort(date)})';
  }

  String _formatStoredDateWithWeekday(String value) {
    final parsed = _parseStoredDate(value);
    if (parsed == null) {
      return value;
    }
    return _formatDateWithWeekday(parsed);
  }

  String _formatVisitSlot(String date, String time) {
    return '${_formatStoredDateWithWeekday(date)} · $time';
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) {
      return '-';
    }
    final date = timestamp.toDate();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${_formatDateWithWeekday(date)} $hour:$minute';
  }

  Future<void> _submitFeedback({
    required ScheduledVisit scheduledVisit,
    required String feedbackText,
  }) async {
    final lang = AppLanguageController.instance;
    if (feedbackText.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.tr(
              'Please enter your update before sending.',
              '보내기 전에 수정 또는 추가 내용을 입력해주세요.',
            ),
          ),
        ),
      );
      return;
    }

    setState(() => _submittingVisitIds.add(scheduledVisit.visit.id));
    try {
      await AppFirestoreService.submitVisitRecordFeedback(
        patientId: scheduledVisit.profile.id,
        clinicId:
            _store.activeClinicForPatient(scheduledVisit.profile.id)?.id ??
            scheduledVisit.visit.clinicId,
        patientName: scheduledVisit.profile.name,
        visitId: scheduledVisit.visit.id,
        visitDate: scheduledVisit.visit.date,
        visitTime: scheduledVisit.visit.time,
        feedbackText: feedbackText,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.tr(
              'Your update was sent to the practitioner.',
              '수정/추가 내용이 침술사에게 전달되었습니다.',
            ),
          ),
        ),
      );
    } on StateError {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.tr(
              'The practitioner already reviewed this visit, so editing is locked.',
              '침술사가 이미 확인해서 더 이상 수정할 수 없습니다.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submittingVisitIds.remove(scheduledVisit.visit.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLanguageController.instance,
      builder: (context, _) {
        final lang = AppLanguageController.instance;
        final profile = _currentProfile;
        final activeClinic = _store.activeClinicForPatient(profile.id);
        final history = _history;
        final lastVisit = history.isNotEmpty ? history.first.visit : null;

        return PatientShell(
          currentItem: PatientNavItem.history,
          title: lang.tr('Visit History', '방문 기록'),
          actions: const [LanguageMenuButton()],
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppPanel(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      style: Theme.of(
                        context,
                      ).textTheme.headlineMedium?.copyWith(color: AppTheme.ink),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _HistorySummaryChip(
                          label: lang.tr('Total Visits', '총 방문'),
                          value: '${history.length}',
                          dark: false,
                        ),
                        _HistorySummaryChip(
                          label: lang.tr('Last Visit', '최근 방문'),
                          value: lastVisit == null
                              ? '-'
                              : _formatStoredDateWithWeekday(lastVisit.date),
                          dark: false,
                        ),
                        _HistorySummaryChip(
                          label: lang.tr('Most Recent Status', '최근 상태'),
                          value: lastVisit == null
                              ? '-'
                              : lastVisit.intakeStatus.label,
                          dark: false,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              PatientClinicContextPanel(
                clinic: activeClinic,
                onChooseClinic: () =>
                    Navigator.pushNamed(context, PatientHomeScreen.routeName),
              ),
              const SizedBox(height: 16),
              if (history.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(lang.tr('No visits', '방문 기록 없음')),
                  ),
                )
              else
                ...history.map((scheduledVisit) {
                  final visit = scheduledVisit.visit;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('visit_record_feedback')
                          .doc(
                            AppFirestoreService.visitFeedbackDocumentId(
                              patientId: profile.id,
                              visitId: visit.id,
                            ),
                          )
                          .snapshots(),
                      builder: (context, snapshot) {
                        final data = snapshot.data?.data();
                        final isReviewed = (data?['status'] == 'reviewed');
                        final hasFeedback =
                            data != null &&
                            ((data['feedbackText'] ?? '') as String)
                                .trim()
                                .isNotEmpty;
                        final controller = _controllerFor(
                          visit.id,
                          hasFeedback
                              ? (data['feedbackText'] as String? ?? '')
                              : '',
                        );
                        if (hasFeedback && controller.text.trim().isEmpty) {
                          controller.text =
                              data['feedbackText'] as String? ?? '';
                        }

                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _formatVisitSlot(
                                          visit.date,
                                          visit.time,
                                        ),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Chip(label: Text(visit.intakeStatus.label)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${lang.tr('Last Visit Before This', '그 전 방문')}: ${_formatStoredDateWithWeekday(visit.lastVisitDate)} (${visit.daysAgo} ${lang.tr('days ago', '일 전')})',
                                ),
                                Text(
                                  '${lang.tr('Treatment Focus', '치료 부위')}: ${visit.previousTreatmentArea}',
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  lang.tr('Session Note', '세션 메모'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(visit.previousSessionNote),
                                const SizedBox(height: 12),
                                _VisitTreatmentPointPreview(visitId: visit.id),
                                const SizedBox(height: 12),
                                Text(
                                  lang.tr(
                                    'Question / Answer Snapshot',
                                    '질문 / 답변 요약',
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                if (visit.qaList.isEmpty)
                                  Text(
                                    lang.tr(
                                      'No intake answers were saved for this visit.',
                                      '이 방문에는 저장된 문진 답변이 없습니다.',
                                    ),
                                  )
                                else
                                  ...visit.qaList.map(
                                    (qa) => Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '[${qa.category}] ${qa.question}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(qa.answer),
                                        ],
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 14),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF7FBFA),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFD7EAE6),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              lang.tr(
                                                'Request update',
                                                '수정 요청',
                                              ),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          Chip(
                                            label: Text(
                                              isReviewed
                                                  ? lang.tr('Reviewed', '확인 완료')
                                                  : hasFeedback
                                                  ? lang.tr('Sent', '보냄')
                                                  : lang.tr('Not sent', '미전송'),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: controller,
                                        enabled: !isReviewed,
                                        minLines: 4,
                                        maxLines: 6,
                                        decoration: InputDecoration(
                                          border: const OutlineInputBorder(),
                                          labelText: lang.tr(
                                            'Your correction / additional note',
                                            '수정 또는 추가 메모',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      if (hasFeedback) ...[
                                        Text(
                                          '${lang.tr('Sent at', '보낸 시각')}: ${_formatTimestamp(data['submittedAt'] as Timestamp?)}',
                                        ),
                                        const SizedBox(height: 4),
                                      ],
                                      if (isReviewed)
                                        Text(
                                          '${lang.tr('Reviewed', '확인 완료')} · ${_formatTimestamp(data?['reviewedAt'] as Timestamp?)}',
                                        ),
                                      if (isReviewed)
                                        const SizedBox(height: 12),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: FilledButton.icon(
                                          onPressed:
                                              isReviewed ||
                                                  _submittingVisitIds.contains(
                                                    visit.id,
                                                  )
                                              ? null
                                              : () => _submitFeedback(
                                                  scheduledVisit:
                                                      scheduledVisit,
                                                  feedbackText: controller.text,
                                                ),
                                          icon: const Icon(Icons.send_outlined),
                                          label: Text(
                                            _submittingVisitIds.contains(
                                                  visit.id,
                                                )
                                                ? lang.tr(
                                                    'Sending...',
                                                    '보내는 중...',
                                                  )
                                                : lang.tr('Send', '보내기'),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}

class _HistorySummaryChip extends StatelessWidget {
  const _HistorySummaryChip({
    required this.label,
    required this.value,
    this.dark = false,
  });

  final String label;
  final String value;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.14)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: dark ? Border.all(color: Colors.white24) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: dark ? Colors.white70 : Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: dark ? Colors.white : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _VisitTreatmentPointPreview extends StatefulWidget {
  const _VisitTreatmentPointPreview({required this.visitId});

  final String visitId;

  @override
  State<_VisitTreatmentPointPreview> createState() =>
      _VisitTreatmentPointPreviewState();
}

class _VisitTreatmentPointPreviewState
    extends State<_VisitTreatmentPointPreview> {
  double _rotation = -0.28;

  List<_TreatmentPoint> get _points {
    final seed = widget.visitId.codeUnits.fold<int>(
      0,
      (total, value) => total + value,
    );
    return [
      _treatmentPoints[seed % _treatmentPoints.length],
      _treatmentPoints[(seed + 2) % _treatmentPoints.length],
      _treatmentPoints[(seed + 5) % _treatmentPoints.length],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguageController.instance;
    final points = _points;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSoft.withValues(alpha: 0.64),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 620;
          final model = _RotatingTreatmentModel(
            points: points,
            rotation: _rotation,
            onRotate: (delta) {
              setState(() {
                _rotation =
                    (_rotation + delta.delta.dx * 0.012) % (math.pi * 2);
              });
            },
          );
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _PremiumBadge(label: 'Premium ready'),
                  _PremiumBadge(
                    label: lang.tr(
                      'Session treatment map',
                      'Session treatment map',
                    ),
                    soft: true,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                lang.tr(
                  'Needle points recorded for this visit',
                  'Needle points recorded for this visit',
                ),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                lang.tr(
                  'Drag the body to rotate it. Hover a marker to see the point name.',
                  'Drag the body to rotate it. Hover a marker to see the point name.',
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.ink.withValues(alpha: 0.66),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: points
                    .map((point) => Chip(label: Text(point.shortLabel)))
                    .toList(),
              ),
            ],
          );

          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(width: 220, child: model),
                const SizedBox(width: 18),
                Expanded(child: details),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: SizedBox(width: 220, child: model)),
              const SizedBox(height: 12),
              details,
            ],
          );
        },
      ),
    );
  }
}

class _PremiumBadge extends StatelessWidget {
  const _PremiumBadge({required this.label, this.soft = false});

  final String label;
  final bool soft;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: soft ? AppTheme.mint.withValues(alpha: 0.34) : AppTheme.pine,
        borderRadius: BorderRadius.circular(999),
        border: soft ? Border.all(color: AppTheme.border) : null,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: soft ? AppTheme.pine : Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _RotatingTreatmentModel extends StatelessWidget {
  const _RotatingTreatmentModel({
    required this.points,
    required this.rotation,
    required this.onRotate,
  });

  final List<_TreatmentPoint> points;
  final double rotation;
  final ValueChanged<DragUpdateDetails> onRotate;

  @override
  Widget build(BuildContext context) {
    final turn = math.cos(rotation);
    return AspectRatio(
      aspectRatio: 0.78,
      child: GestureDetector(
        onPanUpdate: onRotate,
        child: MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.74),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    Positioned.fill(
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0018)
                          ..rotateY(rotation),
                        child: CustomPaint(
                          painter: _RotatingBodyPainter(turn: turn),
                        ),
                      ),
                    ),
                    for (final point in points)
                      _buildMarker(context, constraints.biggest, point, turn),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMarker(
    BuildContext context,
    Size size,
    _TreatmentPoint point,
    double turn,
  ) {
    final projectedX = 0.5 + (point.x - 0.5) * (0.34 + turn.abs() * 0.72);
    final visible =
        point.side == _BodySide.center ||
        (point.side == _BodySide.front && turn >= -0.12) ||
        (point.side == _BodySide.back && turn <= 0.12);
    final opacity = visible ? 1.0 : 0.24;

    return Positioned(
      left: size.width * projectedX - 13,
      top: size.height * point.y - 13,
      child: Tooltip(
        message: '${point.code} - ${point.name}\n${point.area}',
        waitDuration: const Duration(milliseconds: 220),
        child: AnimatedOpacity(
          opacity: opacity,
          duration: const Duration(milliseconds: 160),
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: AppTheme.copper,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.pine, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RotatingBodyPainter extends CustomPainter {
  const _RotatingBodyPainter({required this.turn});

  final double turn;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final widthScale = 0.72 + turn.abs() * 0.28;
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          AppTheme.mint.withValues(alpha: 0.24),
          AppTheme.mint.withValues(alpha: 0.56),
          AppTheme.pine.withValues(alpha: 0.14),
        ],
      ).createShader(Offset.zero & size);
    final outlinePaint = Paint()
      ..color = AppTheme.pine.withValues(alpha: 0.36)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    Rect scaledRect(double x, double y, double w, double h) {
      final scaledWidth = w * widthScale;
      return Rect.fromCenter(
        center: Offset(size.width * x, size.height * y),
        width: size.width * scaledWidth,
        height: size.height * h,
      );
    }

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX, size.height * 0.91),
        width: size.width * 0.48,
        height: size.height * 0.05,
      ),
      shadowPaint,
    );

    canvas.drawOval(scaledRect(0.5, 0.14, 0.3, 0.2), bodyPaint);
    canvas.drawOval(scaledRect(0.5, 0.14, 0.3, 0.2), outlinePaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        scaledRect(0.5, 0.39, 0.42, 0.34),
        const Radius.circular(54),
      ),
      bodyPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        scaledRect(0.5, 0.39, 0.42, 0.34),
        const Radius.circular(54),
      ),
      outlinePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        scaledRect(0.27, 0.43, 0.13, 0.34),
        const Radius.circular(36),
      ),
      bodyPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        scaledRect(0.73, 0.43, 0.13, 0.34),
        const Radius.circular(36),
      ),
      bodyPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        scaledRect(0.27, 0.43, 0.13, 0.34),
        const Radius.circular(36),
      ),
      outlinePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        scaledRect(0.73, 0.43, 0.13, 0.34),
        const Radius.circular(36),
      ),
      outlinePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        scaledRect(0.43, 0.72, 0.14, 0.34),
        const Radius.circular(34),
      ),
      bodyPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        scaledRect(0.57, 0.72, 0.14, 0.34),
        const Radius.circular(34),
      ),
      bodyPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        scaledRect(0.43, 0.72, 0.14, 0.34),
        const Radius.circular(34),
      ),
      outlinePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        scaledRect(0.57, 0.72, 0.14, 0.34),
        const Radius.circular(34),
      ),
      outlinePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RotatingBodyPainter oldDelegate) =>
      oldDelegate.turn != turn;
}

enum _BodySide { front, back, center }

class _TreatmentPoint {
  const _TreatmentPoint({
    required this.code,
    required this.name,
    required this.area,
    required this.x,
    required this.y,
    this.side = _BodySide.front,
  });

  final String code;
  final String name;
  final String area;
  final double x;
  final double y;
  final _BodySide side;

  String get shortLabel => '$code - $name';
}

const List<_TreatmentPoint> _treatmentPoints = [
  _TreatmentPoint(
    code: 'GB20',
    name: 'Fengchi',
    area: 'neck / occiput',
    x: 0.42,
    y: 0.18,
    side: _BodySide.back,
  ),
  _TreatmentPoint(
    code: 'GB21',
    name: 'Jianjing',
    area: 'upper trapezius',
    x: 0.64,
    y: 0.28,
  ),
  _TreatmentPoint(
    code: 'LI11',
    name: 'Quchi',
    area: 'lateral elbow',
    x: 0.25,
    y: 0.46,
  ),
  _TreatmentPoint(
    code: 'PC6',
    name: 'Neiguan',
    area: 'inner forearm',
    x: 0.74,
    y: 0.58,
  ),
  _TreatmentPoint(
    code: 'REN12',
    name: 'Zhongwan',
    area: 'upper abdomen',
    x: 0.5,
    y: 0.43,
    side: _BodySide.center,
  ),
  _TreatmentPoint(
    code: 'ST36',
    name: 'Zusanli',
    area: 'anterolateral lower leg',
    x: 0.42,
    y: 0.78,
  ),
  _TreatmentPoint(
    code: 'BL23',
    name: 'Shenshu',
    area: 'lower back',
    x: 0.58,
    y: 0.54,
    side: _BodySide.back,
  ),
];
