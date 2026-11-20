import 'package:flutter/widgets.dart';

import '../detection/detected_object.dart';

/// Draws [DetectedObject] boxes over an image shown with the same [fit] and
/// [alignment], mapping image pixels to widget space correctly.
///
/// ```dart
/// DetectionOverlay(
///   imageSize: Size(width.toDouble(), height.toDouble()),
///   detections: detections,
///   child: Image.file(file, fit: BoxFit.contain),
/// )
/// ```
class DetectionOverlay extends StatelessWidget {
  /// Creates an overlay.
  const DetectionOverlay({
    super.key,
    required this.imageSize,
    required this.detections,
    this.child,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.strokeWidth = 2,
    this.showLabels = true,
    this.colorFor = defaultColorFor,
    this.labelFor = defaultLabelFor,
    this.labelStyle = const TextStyle(
      color: Color(0xFF0B0D10),
      fontSize: 11,
      fontWeight: FontWeight.w600,
      height: 1.2,
    ),
  });

  /// Pixel size of the image the detections refer to.
  final Size imageSize;

  /// Boxes to draw.
  final List<DetectedObject> detections;

  /// The image (or anything) to draw over. Optional when stacking manually.
  final Widget? child;

  /// Must match the fit used to display the image.
  final BoxFit fit;

  /// Must match the alignment used to display the image.
  final Alignment alignment;

  /// Box outline width.
  final double strokeWidth;

  /// Whether to draw a label chip on each box.
  final bool showLabels;

  /// Colour per detection.
  final Color Function(DetectedObject detection) colorFor;

  /// Label text per detection.
  final String Function(DetectedObject detection) labelFor;

  /// Label chip text style.
  final TextStyle labelStyle;

  /// Default palette, one colour per detector type.
  static Color defaultColorFor(DetectedObject d) => switch (d.type) {
    DetectorType.face => const Color(0xFFFFC542),
    DetectorType.text => const Color(0xFF4FD1E8),
    DetectorType.pose => const Color(0xFF6EE7A0),
    DetectorType.object || null => const Color(0xFFFF7AB6),
  };

  /// Maps [box] from image pixels to widget coordinates for an image of
  /// [imageSize] painted into [widgetSize] with [fit] and [alignment].
  /// Useful for hit-testing taps against detections.
  static Rect mapRect(
    Rect box, {
    required Size imageSize,
    required Size widgetSize,
    BoxFit fit = BoxFit.contain,
    Alignment alignment = Alignment.center,
  }) {
    final fitted = applyBoxFit(fit, imageSize, widgetSize);
    final src = alignment.inscribe(fitted.source, Offset.zero & imageSize);
    final dst = alignment.inscribe(
      fitted.destination,
      Offset.zero & widgetSize,
    );
    final sx = dst.width / src.width;
    final sy = dst.height / src.height;
    return Rect.fromLTRB(
      dst.left + (box.left - src.left) * sx,
      dst.top + (box.top - src.top) * sy,
      dst.left + (box.right - src.left) * sx,
      dst.top + (box.bottom - src.top) * sy,
    );
  }

  /// Default label: the detection label, plus OCR text or confidence.
  static String defaultLabelFor(DetectedObject d) {
    if (d.type == DetectorType.text) {
      final text = (d.additionalData?['text'] as String? ?? '').replaceAll(
        '\n',
        ' ',
      );
      return text.length > 28 ? '${text.substring(0, 27)}…' : text;
    }
    if (d.type == DetectorType.object) {
      return '${d.label} ${(d.confidence * 100).round()}%';
    }
    return d.label;
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _DetectionPainter(
        imageSize: imageSize,
        detections: detections,
        fit: fit,
        alignment: alignment,
        strokeWidth: strokeWidth,
        showLabels: showLabels,
        colorFor: colorFor,
        labelFor: labelFor,
        labelStyle: labelStyle,
        textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
      ),
      child: child ?? const SizedBox.expand(),
    );
  }
}

class _DetectionPainter extends CustomPainter {
  _DetectionPainter({
    required this.imageSize,
    required this.detections,
    required this.fit,
    required this.alignment,
    required this.strokeWidth,
    required this.showLabels,
    required this.colorFor,
    required this.labelFor,
    required this.labelStyle,
    required this.textDirection,
  });

  final Size imageSize;
  final List<DetectedObject> detections;
  final BoxFit fit;
  final Alignment alignment;
  final double strokeWidth;
  final bool showLabels;
  final Color Function(DetectedObject) colorFor;
  final String Function(DetectedObject) labelFor;
  final TextStyle labelStyle;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    if (imageSize.isEmpty || size.isEmpty) return;
    final fitted = applyBoxFit(fit, imageSize, size);
    final dst = alignment.inscribe(fitted.destination, Offset.zero & size);

    canvas.save();
    canvas.clipRect(dst);
    for (final d in detections) {
      final rect = DetectionOverlay.mapRect(
        d.boundingBox,
        imageSize: imageSize,
        widgetSize: size,
        fit: fit,
        alignment: alignment,
      );
      final color = colorFor(d);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth,
      );
      if (showLabels) _label(canvas, rect, color, labelFor(d), dst);
    }
    canvas.restore();
  }

  void _label(Canvas canvas, Rect box, Color color, String text, Rect bounds) {
    if (text.isEmpty) return;
    final painter = TextPainter(
      text: TextSpan(text: text, style: labelStyle),
      textDirection: textDirection,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: bounds.width - 8);
    const padH = 6.0, padV = 3.0;
    final w = painter.width + padH * 2;
    final h = painter.height + padV * 2;
    var top = box.top - h - 2;
    if (top < bounds.top) top = box.top + 2;
    var left = box.left;
    if (left + w > bounds.right) left = bounds.right - w;
    if (left < bounds.left) left = bounds.left;
    final chip = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, w, h),
      const Radius.circular(4),
    );
    canvas.drawRRect(chip, Paint()..color = color);
    painter.paint(canvas, Offset(left + padH, top + padV));
    painter.dispose();
  }

  @override
  bool shouldRepaint(_DetectionPainter old) =>
      old.detections != detections ||
      old.imageSize != imageSize ||
      old.fit != fit ||
      old.alignment != alignment ||
      old.strokeWidth != strokeWidth ||
      old.showLabels != showLabels ||
      old.labelStyle != labelStyle;
}
