import 'package:flutter/material.dart';

import '../core/brand.dart';
import '../core/theme.dart';

/// 앱 정보 — 계산 방식과 면책 문구. 계산기라 금융 서비스가 아님을 분명히 한다.
Future<void> showAbout(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Tk.of(context).surface,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
  builder: (c) {
    final tk = Tk.of(c);
    final body = TextStyle(fontSize: 14, color: tk.text2, height: 1.45);
    Widget h(String t) => Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Text(
        t,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: tk.text,
        ),
      ),
    );
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(c).height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      appName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: tk.text,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const Key('about-close'),
                    onPressed: () => Navigator.pop(c),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                'Version $appVersion',
                style: TextStyle(fontSize: 13, color: tk.muted),
              ),
              h('How it’s calculated'),
              Text(
                '• Monthly principal & interest uses the standard fixed-rate '
                'amortization formula, rounded to the cent like a lender’s schedule.\n'
                '• Property tax and home insurance are yearly amounts divided by 12.\n'
                '• PMI applies when the down payment is under 20% and stops once the '
                'balance reaches 78% of the home price (or halfway through the term).\n'
                '• Extra payments go straight to principal, so the payment stays the '
                'same and the loan ends sooner.\n'
                '• Car loans add sales tax on the price minus your trade-in.',
                style: body,
              ),
              h('Estimates only'),
              Text(
                'Results are estimates for planning and are not financial advice or an '
                'offer of credit. Interest rates in the app are examples, not today’s '
                'rates — use the rate from your lender. Your lender’s numbers may differ '
                'because of fees, escrow and rounding.',
                style: body,
              ),
              h('Privacy'),
              Text(
                'Your numbers stay on this iPhone. Nothing is sent to us. '
                'The app shows Google AdMob banner ads.\n$privacyUrl',
                style: body,
              ),
              const SizedBox(height: 16),
              Text(
                '© 2026 Soulfulfill',
                style: TextStyle(fontSize: 12, color: tk.muted),
              ),
            ],
          ),
        ),
      ),
    );
  },
);
