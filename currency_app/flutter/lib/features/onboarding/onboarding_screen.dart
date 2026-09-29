import 'package:flutter/material.dart';

import '../../core/currencies.dart';
import '../../core/store.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../converter/currency_picker_sheet.dart';

/// 첫 실행 온보딩 — 기준 통화를 먼저 고르고, 그 통화가 맨 위로.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  String _q = '';

  void _choose(String code) => AppStore.i.completeOnboarding(code);

  @override
  Widget build(BuildContext context) {
    final fx = Fx.of(context);
    return Scaffold(
      backgroundColor: fx.appBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: fx.accent,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Text('\$',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: fx.accentInk)),
                  ),
                  const SizedBox(height: 18),
                  Text('어떤 통화를 기준으로\n쓰시겠어요?',
                      style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w700,
                          height: 1.32,
                          letterSpacing: -.5,
                          color: fx.text)),
                  const SizedBox(height: 9),
                  Text('고른 통화가 맨 위에 고정돼요.\n내 돈을 넣으면 다른 나라 돈으로 바로 환산됩니다.',
                      style: TextStyle(
                          fontSize: 13.5, height: 1.55, color: fx.text2)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
                    child: Eyebrow('많이 쓰는 통화'),
                  ),
                  GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 2.7,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      for (final code in popularCodes)
                        _PopTile(
                          currency: currencyByCode[code]!,
                          onTap: () => _choose(code),
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 22, 4, 12),
                    child: Row(
                      children: [
                        Expanded(child: Divider(color: fx.line, height: 1)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('또는 검색해서 고르기',
                              style: TextStyle(fontSize: 11, color: fx.muted)),
                        ),
                        Expanded(child: Divider(color: fx.line, height: 1)),
                      ],
                    ),
                  ),
                  CurrencySearchField(onChanged: (v) => setState(() => _q = v)),
                  const SizedBox(height: 4),
                  CurrencyList(query: _q, onPick: _choose),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              color: fx.appBg,
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: Text('나중에 앱에서 언제든 바꿀 수 있어요',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: fx.muted)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PopTile extends StatelessWidget {
  const _PopTile({required this.currency, required this.onTap});
  final Currency currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fx = Fx.of(context);
    return Material(
      color: fx.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: fx.line),
          ),
          child: Row(
            children: [
              FlagDot(currency, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(currency.code,
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .5,
                            fontFamily: 'monospace',
                            color: fx.text)),
                    Text(currency.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10.5, color: fx.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
