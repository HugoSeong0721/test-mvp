import 'package:flutter/material.dart';

import '../core/brand.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/units.dart';
import '../widgets/common.dart';

/// 처음 켰을 때: 차 이름 + 단위만. 계정·가입 없음.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _name = TextEditingController();
  late Units _units = AppStore.i.units;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _start() {
    final s = AppStore.i;
    if (_units != s.units) s.setUnits(_units);
    s.addVehicle(_name.text);
  }

  @override
  Widget build(BuildContext context) {
    final tk = Tk.of(context);
    return Scaffold(
      backgroundColor: tk.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          key: const Key('welcome'),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: tk.accent, borderRadius: BorderRadius.circular(20)),
                child: Icon(Icons.local_gas_station_rounded, size: 40, color: tk.onAccent),
              ),
              const SizedBox(height: 18),
              Text(
                appName,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: tk.text),
              ),
              const SizedBox(height: 6),
              Text(
                'Track MPG, gas spending and car maintenance.\nNo account. Everything is free.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, height: 1.4, color: tk.text2),
              ),
              const SizedBox(height: 28),
              SectionCard(
                title: 'Your car',
                child: TextField(
                  key: const Key('welcome-name'),
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _start(),
                  style: TextStyle(fontSize: 17, color: tk.text),
                  decoration: InputDecoration(
                    hintText: 'e.g. 2019 Honda Civic',
                    filled: true,
                    fillColor: tk.surface2,
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
              ),
              SectionCard(
                title: 'Units',
                child: Segmented<bool>(
                  keyPrefix: 'welcome-units',
                  items: const [(true, 'Miles · Gallons · MPG'), (false, 'km · Liters · L/100 km')],
                  value: _units.isUs,
                  onChanged: (us) => setState(() => _units = us ? Units.us : Units.metric),
                ),
              ),
              const SizedBox(height: 8),
              BigButton(
                key: const Key('welcome-start'),
                label: 'Start logging',
                icon: Icons.arrow_forward_rounded,
                onPressed: _start,
              ),
              const SizedBox(height: 14),
              Text(
                'Your log stays on $deviceWord. You can export it as a CSV file anytime.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: tk.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
