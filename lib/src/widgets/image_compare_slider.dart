import 'package:flutter/widgets.dart';

/// A draggable before/after comparison.
///
/// [before] shows on the leading side of the divider and [after] on the
/// trailing side. Both children are laid out at the full size of the slider,
/// so give them the same fit (e.g. `BoxFit.cover`) to keep them aligned.
///
/// ```dart
/// ImageCompareSlider(
///   before: Image.memory(original, fit: BoxFit.cover),
///   after: Image.memory(edited, fit: BoxFit.cover),
/// )
/// ```
class ImageCompareSlider extends StatefulWidget {
  /// Creates a comparison slider.
  const ImageCompareSlider({
    super.key,
    required this.before,
    required this.after,
    this.initialPosition = 0.5,
    this.axis = Axis.horizontal,
    this.dividerColor = const Color(0xFFFFFFFF),
    this.dividerThickness = 2,
    this.handleSize = 40,
    this.beforeLabel,
    this.afterLabel,
    this.onChanged,
    this.semanticLabel = 'Before and after comparison',
  }) : assert(initialPosition >= 0 && initialPosition <= 1);

  /// Shown before the divider (left, or top for [Axis.vertical]).
  final Widget before;

  /// Shown after the divider.
  final Widget after;

  /// Starting divider position, `0..1`.
  final double initialPosition;

  /// Direction the divider moves in.
  final Axis axis;

  /// Divider and handle colour.
  final Color dividerColor;

  /// Divider thickness in logical pixels.
  final double dividerThickness;

  /// Diameter of the drag handle.
  final double handleSize;

  /// Optional caption pinned to the [before] side, e.g. `Text('Before')`.
  final Widget? beforeLabel;

  /// Optional caption pinned to the [after] side.
  final Widget? afterLabel;

  /// Called with the new position while dragging.
  final ValueChanged<double>? onChanged;

  /// Accessibility label announced with the current percentage.
  final String semanticLabel;

  @override
  State<ImageCompareSlider> createState() => _ImageCompareSliderState();
}

class _ImageCompareSliderState extends State<ImageCompareSlider> {
  late double _position = widget.initialPosition;

  bool get _horizontal => widget.axis == Axis.horizontal;

  void _setPosition(double value) {
    final next = value.clamp(0.0, 1.0);
    if (next == _position) return;
    setState(() => _position = next);
    widget.onChanged?.call(next);
  }

  void _updateFrom(Offset local, Size size) {
    _setPosition(_horizontal ? local.dx / size.width : local.dy / size.height);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final extent = _horizontal ? size.width : size.height;
        final offset = extent * _position;
        final percent = (_position * 100).round();

        return Semantics(
          container: true,
          slider: true,
          label: widget.semanticLabel,
          value: '$percent%',
          increasedValue: '${(percent + 5).clamp(0, 100)}%',
          decreasedValue: '${(percent - 5).clamp(0, 100)}%',
          onIncrease: () => _setPosition(_position + 0.05),
          onDecrease: () => _setPosition(_position - 0.05),
          textDirection: Directionality.maybeOf(context),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _updateFrom(d.localPosition, size),
            onHorizontalDragUpdate: _horizontal
                ? (d) => _updateFrom(d.localPosition, size)
                : null,
            onVerticalDragUpdate: _horizontal
                ? null
                : (d) => _updateFrom(d.localPosition, size),
            child: MouseRegion(
              cursor: _horizontal
                  ? SystemMouseCursors.resizeLeftRight
                  : SystemMouseCursors.resizeUpDown,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ExcludeSemantics(child: widget.after),
                  ClipRect(
                    clipper: _RevealClipper(offset, widget.axis),
                    child: ExcludeSemantics(child: widget.before),
                  ),
                  if (widget.beforeLabel != null)
                    Positioned(
                      left: 12,
                      top: 12,
                      child: Opacity(
                        opacity: _position > 0.12 ? 1 : 0,
                        child: widget.beforeLabel,
                      ),
                    ),
                  if (widget.afterLabel != null)
                    Positioned(
                      right: _horizontal ? 12 : null,
                      left: _horizontal ? null : 12,
                      top: _horizontal ? 12 : null,
                      bottom: _horizontal ? null : 12,
                      child: Opacity(
                        opacity: _position < 0.88 ? 1 : 0,
                        child: widget.afterLabel,
                      ),
                    ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _DividerPainter(
                          offset: offset,
                          axis: widget.axis,
                          color: widget.dividerColor,
                          thickness: widget.dividerThickness,
                          handleSize: widget.handleSize,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RevealClipper extends CustomClipper<Rect> {
  const _RevealClipper(this.offset, this.axis);

  final double offset;
  final Axis axis;

  @override
  Rect getClip(Size size) => axis == Axis.horizontal
      ? Rect.fromLTWH(0, 0, offset, size.height)
      : Rect.fromLTWH(0, 0, size.width, offset);

  @override
  bool shouldReclip(_RevealClipper old) =>
      old.offset != offset || old.axis != axis;
}

class _DividerPainter extends CustomPainter {
  const _DividerPainter({
    required this.offset,
    required this.axis,
    required this.color,
    required this.thickness,
    required this.handleSize,
  });

  final double offset;
  final Axis axis;
  final Color color;
  final double thickness;
  final double handleSize;

  @override
  void paint(Canvas canvas, Size size) {
    final horizontal = axis == Axis.horizontal;
    final line = Paint()
      ..color = color
      ..strokeWidth = thickness;
    final center = horizontal
        ? Offset(offset, size.height / 2)
        : Offset(size.width / 2, offset);
    if (horizontal) {
      canvas.drawLine(Offset(offset, 0), Offset(offset, size.height), line);
    } else {
      canvas.drawLine(Offset(0, offset), Offset(size.width, offset), line);
    }

    final r = handleSize / 2;
    canvas.drawCircle(
      center.translate(0, 1.5),
      r,
      Paint()
        ..color = const Color(0x40000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(center, r, Paint()..color = color);

    // Two chevrons pointing along the drag axis.
    final chevron = Paint()
      ..color = const Color(0xFF1F2328)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final s = r * 0.32;
    final gap = r * 0.22;
    for (final dir in const [-1.0, 1.0]) {
      final path = Path();
      if (horizontal) {
        final tip = center.translate(dir * (gap + s), 0);
        path
          ..moveTo(tip.dx - dir * s, tip.dy - s)
          ..lineTo(tip.dx, tip.dy)
          ..lineTo(tip.dx - dir * s, tip.dy + s);
      } else {
        final tip = center.translate(0, dir * (gap + s));
        path
          ..moveTo(tip.dx - s, tip.dy - dir * s)
          ..lineTo(tip.dx, tip.dy)
          ..lineTo(tip.dx + s, tip.dy - dir * s);
      }
      canvas.drawPath(path, chevron);
    }
  }

  @override
  bool shouldRepaint(_DividerPainter old) =>
      old.offset != offset ||
      old.axis != axis ||
      old.color != color ||
      old.thickness != thickness ||
      old.handleSize != handleSize;
}
