import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;

import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../field_monitoring/models.dart';
import '../../field_monitoring/services/field_location_service.dart';
import '../../field_monitoring/services/field_api_client.dart';

/// شاشة تتبع المراقب الميداني أثناء الجولة.
class FieldMonitorScreen extends StatefulWidget {
  final String apiBaseUrl;
  final String token;
  final String inspectorId;

  const FieldMonitorScreen({
    super.key,
    this.apiBaseUrl = '',
    this.token = '',
    this.inspectorId = '',
  });

  @override
  State<FieldMonitorScreen> createState() => _FieldMonitorScreenState();
}

class _FieldMonitorScreenState extends State<FieldMonitorScreen> {
  final FieldLocationService _locationService = FieldLocationService();
  FieldApiClient _apiClient = FieldApiClient(baseUrl: '', token: '');
  bool _tracking = false;
  FieldLocation? _current;
  String? _error;
  Duration _elapsed = Duration.zero;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _apiClient = FieldApiClient(baseUrl: widget.apiBaseUrl, token: widget.token);
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _error = null;
      _elapsed = Duration.zero;
    });
    try {
      final location = await _locationService.currentLocation(
        inspectorId: widget.inspectorId,
        inspectorName: widget.inspectorId,
        division: 'field',
      );
      if (!mounted) return;
      if (location == null) {
        if (mounted) setState(() => _error = 'تعذر تحديد الموقع');
        return;
      }
      setState(() => _current = location);
      final out = await _apiClient.sendLocation(location);
      if (!mounted) return;
      if (out.ok) {
        if (mounted) setState(() => _tracking = true);
        if (mounted) toast(context, 'تم تسجيل الموقع الحالي');
      } else {
        if (mounted) setState(() => _error = out.message);
      }
    } catch (error) {
      final message = error.toString();
      if (!mounted) return;
      setState(() => _error = message.contains('Exception')
          ? message.replaceFirst('Exception: ', '')
          : 'تعذر تحديد الموقع حالياً');
    }
  }

  Future<void> _stop() async {
    _clock?.cancel();
    if (mounted) setState(() => _elapsed = Duration.zero);
    if (mounted) {
      setState(() {
        _tracking = false;
        _current = null;
      });
    }
    if (mounted) toast(context, 'انتهت جولة التتبع');
  }

  @override
  Widget build(BuildContext context) {
    return PageBody(
      children: [
        BackBreadcrumb(
          parent: 'التتبع',
          current: 'جولة مراقب ميداني',
          fallbackLocation: '/field',
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                    colors: [
                      kPrimary.withValues(alpha: .09),
                      const Color(0xFF8B7FD1).withValues(alpha: .06),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: kPrimary.withValues(alpha: .16)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF2E8C7E), Color(0xFF17574E)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: kPrimary.withValues(alpha: .3),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(CupertinoIcons.location,
                          color: Colors.white, size: 25),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'تتبع المراقب الميداني',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'ابدأ جولة ميدانية لتحديد موقع المنشأة أثناء التحرك',
                            style: TextStyle(
                                color: context.p.muted, fontSize: 12.5, height: 1.45),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Divider(height: 1, color: context.p.border),
              const SizedBox(height: 14),
              if (!_tracking) ...[
                Text(
                  'لم تبدأ جولة تتبع بعد',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700, height: 1.25),
                ),
                const SizedBox(height: 6),
                Text(
                  'اضغط زر بدء الجولة ليقوم التطبيق بتحديد الموقع الحالي أثناء التحرك الميداني.',
                  style: TextStyle(color: context.p.muted, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _start,
                  icon: const Icon(CupertinoIcons.location, size: 18),
                  label: const Text('بدء تتبع الموقع'),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: AlignmentDirectional.topStart,
                      end: AlignmentDirectional.bottomEnd,
                      colors: [
                        kPrimary.withValues(alpha: .1),
                        const Color(0xFF8B7FD1).withValues(alpha: .07),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: kPrimary.withValues(alpha: .16)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF2E8C7E), Color(0xFF17574E)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: kPrimary.withValues(alpha: .28),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: const Icon(CupertinoIcons.location,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'التتبع جارٍ الآن',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'جولة ميدانية نشطة · تُحدَّث الموقع أثناء التحرك',
                              style: TextStyle(
                                color: context.p.muted,
                                fontSize: 12,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_current != null) InfoTileGrid(
                  tiles: [
                    InfoTile(
                      icon: CupertinoIcons.location,
                      label: 'الموقع',
                      value: _current!.locationLabel,
                      accent: kPrimary,
                    ),
                    InfoTile(
                      icon: CupertinoIcons.number,
                      label: 'الإحداثيات',
                      value: '${_current!.lat.toStringAsFixed(5)}, ${_current!.lng.toStringAsFixed(5)}',
                      accent: kPrimary,
                    ),
                    InfoTile(
                      icon: CupertinoIcons.map,
                      label: 'الدقة',
                      value: '${_current!.accuracy.toStringAsFixed(0)} م',
                      accent: kPrimary,
                    ),
                    InfoTile(
                      icon: CupertinoIcons.clock,
                      label: 'المدة',
                      value: '${_elapsed.inSeconds} ث',
                      accent: kPrimary,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                FilledButton.tonalIcon(
                  onPressed: _stop,
                  icon: const Icon(CupertinoIcons.location, size: 18),
                  label: const Text('إنهاء الجولة'),
                ),
              ],
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: kRed.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kRed.withValues(alpha: .25)),
            ),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.exclamationmark_circle_fill,
                  color: kRed,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: kRed,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
