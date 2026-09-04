import 'package:flutter/material.dart';
import '../theme/payflex_tokens.dart';
import '../utils/money.dart';
import 'pf_mark.dart';

/// Branded loader — the ribbon motif tracing itself in a flat gradient
/// loop. Replaces every CircularProgressIndicator in the app; never the
/// default spinner (design brief §2, item 5).
class PfBrandedLoader extends StatefulWidget {
  final double size;
  final double strokeWidthFactor; // of size
  const PfBrandedLoader({
    super.key,
    this.size = 52,
    this.strokeWidthFactor = 0.17,
  });

  @override
  State<PfBrandedLoader> createState() => _PfBrandedLoaderState();
}

class _PfBrandedLoaderState extends State<PfBrandedLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: PfMarkPainter(
            t: _controller.value,
            loop: true,
            strokeWidth: 100 * widget.strokeWidthFactor,
          ),
        ),
      ),
    );
  }
}

/// Count-up money — the balance reveal (design brief §2, item 1). The
/// number rises from 0 and settles in ~450ms ease-out; ~once per session,
/// controlled by the caller's `animate` flag. Uses tabular figures so the
/// digits don't jitter while counting.
class PfCountUpMoney extends StatefulWidget {
  final String amount; // decimal string
  final String currency;
  final TextStyle style;
  final bool animate;

  const PfCountUpMoney({
    super.key,
    required this.amount,
    required this.currency,
    required this.style,
    this.animate = true,
  });

  @override
  State<PfCountUpMoney> createState() => _PfCountUpMoneyState();
}

class _PfCountUpMoneyState extends State<PfCountUpMoney>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _anim;
  late double _target;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _target = parseAmount(widget.amount);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _anim = CurvedAnimation(parent: _controller, curve: PfMotion.countUp);
    if (widget.animate) {
      _controller.forward().then((_) => _done = true);
    } else {
      _done = true;
    }
  }

  @override
  void didUpdateWidget(PfCountUpMoney old) {
    super.didUpdateWidget(old);
    if (old.amount != widget.amount) {
      _target = parseAmount(widget.amount);
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return Text(
        formatValueOnly(_target),
        style: widget.style,
        maxLines: 1,
      );
    }
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) => Text(
        formatValueOnly(_target * _anim.value),
        style: widget.style,
        maxLines: 1,
      ),
    );
  }
}
