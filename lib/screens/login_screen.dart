import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../data/store.dart';
import '../widgets/common.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final u = TextEditingController(), p = TextEditingController();
  final pFocus = FocusNode();
  late final AnimationController _c;
  String? err;
  bool obscure = true;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 850))
      ..forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    pFocus.dispose();
    super.dispose();
  }

  Animation<double> _step(double begin, double end) => _c.drive(
      CurveTween(curve: Interval(begin, end, curve: Curves.easeOutCubic)));

  void _go() {
    final st = context.read<AppStore>();
    if (st.login(u.text, p.text)) {
      context.go('/');
    } else {
      setState(() => err = 'اسم المستخدم أو كلمة المرور غير صحيحة');
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.p.isDark;
    final accent = dark ? const Color(0xFF8FDCCF) : kPrimary;

    return Scaffold(
      backgroundColor: context.p.bg,
      body: Stack(children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, .6],
                colors: dark
                    ? const [Color(0xFF102220), Color(0xFF0E1111)]
                    : const [Color(0xFFEAF3F1), Color(0xFFFFFFFF)],
              ),
            ),
          ),
        ),
        // هالات لونية ناعمة تعطي عمقاً دون ازدحام.
        Positioned(
          top: -150,
          left: -110,
          child: _Glow(color: kPrimary, size: 360, alpha: dark ? .26 : .13),
        ),
        Positioned(
          bottom: -170,
          right: -130,
          child: _Glow(color: kGold, size: 380, alpha: dark ? .14 : .10),
        ),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Reveal(
                    animation: _step(0, .55),
                    scaleFrom: .94,
                    child: Center(
                      child: Container(
                        width: 224,
                        height: 132,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(
                            color: dark
                                ? Colors.white.withValues(alpha: .12)
                                : const Color(0xFFE5ECE9),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withValues(alpha: dark ? .18 : .07),
                              blurRadius: 28,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/logos/dept_logo.png',
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                          semanticLabel: 'الهيئة العامة للضرائب والرسوم',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Reveal(
                    animation: _step(.12, .65),
                    child: Column(children: [
                      Text('دائرة الإنفاق الاستهلاكي',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -.5,
                              color: dark ? Colors.white : kText)),
                      const SizedBox(height: 8),
                      Container(
                        width: 32,
                        height: 2,
                        decoration: BoxDecoration(
                            color: kGold,
                            borderRadius: BorderRadius.circular(2)),
                      ),
                      const SizedBox(height: 8),
                      Text('مديرية مالية اللاذقية',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: context.p.muted,
                              fontSize: 12.5,
                              letterSpacing: .2)),
                    ]),
                  ),
                  const SizedBox(height: 22),
                  _Reveal(
                    animation: _step(.24, .8),
                    offset: 16,
                    child: AppCard(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                  color: dark
                                      ? kPrimary.withValues(alpha: .28)
                                      : const Color(0xFFEAF3F1),
                                  borderRadius: BorderRadius.circular(10)),
                              child: Icon(CupertinoIcons.lock_shield,
                                  size: 18, color: accent),
                            ),
                            const SizedBox(width: 10),
                            const Text('تسجيل الدخول',
                                style: TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w700)),
                          ]),
                          const SizedBox(height: 16),
                          TextField(
                            controller: u,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.username],
                            onSubmitted: (_) => pFocus.requestFocus(),
                            decoration: const InputDecoration(
                                labelText: 'اسم المستخدم',
                                prefixIcon:
                                    Icon(CupertinoIcons.person, size: 18)),
                          ),
                          const SizedBox(height: 11),
                          TextField(
                            controller: p,
                            focusNode: pFocus,
                            obscureText: obscure,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            onSubmitted: (_) => _go(),
                            decoration: InputDecoration(
                              labelText: 'كلمة المرور',
                              prefixIcon:
                                  const Icon(CupertinoIcons.lock, size: 18),
                              suffixIcon: IconButton(
                                tooltip:
                                    obscure ? 'إظهار كلمة المرور' : 'إخفاؤها',
                                onPressed: () =>
                                    setState(() => obscure = !obscure),
                                icon: Icon(
                                    obscure
                                        ? CupertinoIcons.eye
                                        : CupertinoIcons.eye_slash,
                                    size: 18),
                              ),
                            ),
                          ),
                          if (err != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Row(children: [
                                const Icon(
                                    CupertinoIcons.exclamationmark_circle,
                                    size: 15,
                                    color: kRed),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(err!,
                                      style: const TextStyle(
                                          color: kRed, fontSize: 12.5)),
                                ),
                              ]),
                            ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 46,
                            child: FilledButton(
                              onPressed: _go,
                              child: const Text('دخول',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  _Reveal(
                    animation: _step(.36, .92),
                    child: TextButton.icon(
                      onPressed: () => context.go('/verify'),
                      icon:
                          const Icon(CupertinoIcons.doc_text_search, size: 16),
                      label: const Text('التحقق من محضر'),
                    ),
                  ),
                  _Reveal(
                    animation: _step(.44, 1),
                    child: Text('تجريبي: admin / 123456',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: context.p.muted,
                            fontSize: 10.5,
                            letterSpacing: .1)),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Positioned(top: 12, left: 12, child: ThemeToggle(compact: true)),
      ]),
    );
  }
}

/// يظهر العنصر بتلاشٍ وانزلاق خفيف عند فتح الشاشة.
class _Reveal extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  final double offset, scaleFrom;
  const _Reveal({
    required this.animation,
    required this.child,
    this.offset = 10,
    this.scaleFrom = 1,
  });

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: animation,
        builder: (c, ch) {
          final v = animation.value.clamp(0.0, 1.0);
          return Opacity(
            opacity: v,
            child: Transform.translate(
              offset: Offset(0, (1 - v) * offset),
              child: Transform.scale(
                  scale: scaleFrom + (1 - scaleFrom) * v, child: ch),
            ),
          );
        },
        child: child,
      );
}

/// هالة دائرية شفافة.
class _Glow extends StatelessWidget {
  final Color color;
  final double size, alpha;
  const _Glow({required this.color, required this.size, required this.alpha});

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              color.withValues(alpha: alpha),
              color.withValues(alpha: 0),
            ]),
          ),
        ),
      );
}
