import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/widget_model.dart';
import '../utils/constants.dart';

/// ============ GAUGE PAINTER (با افکت‌های پیشرفته) ============
class GaugePainter extends CustomPainter {
  final ScadaWidget widget;
  final double blinkOpacity;

  GaugePainter(this.widget, {this.blinkOpacity = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = math.min(cx, cy) * 0.7;
    final alarmColor = _getAlarmColor();
    final primary = colorFromHex(widget.primaryColor);
    final color = alarmColor ?? primary;

    // Background
    _drawBackground(canvas, size, widget);

    final startAngle = -225.0;
    final endAngle = 45.0;
    final v = widget.scaledValue;
    final pct = _clamp((v - widget.minValue) / (widget.maxValue - widget.minValue));
    final valueAngle = startAngle + pct * (endAngle - startAngle);

    // Background arc with glow
    final trackPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      _degToRad(startAngle),
      _degToRad(endAngle - startAngle),
      false,
      trackPaint,
    );

    // Value arc with gradient and glow
    final arcRect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);
    
    // Glow effect
    final glowPaint = Paint()
      ..color = color.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    
    canvas.drawArc(arcRect, _degToRad(startAngle), _degToRad(valueAngle - startAngle), false, glowPaint);

    // Main arc with gradient
    final valuePaint = Paint()
      ..shader = ui.Gradient.sweep(
        Offset(cx, cy),
        [color.withOpacity(0.6), color, color],
        [0.0, 0.5, 1.0],
        TileMode.clamp,
        _degToRad(startAngle),
        _degToRad(endAngle),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(arcRect, _degToRad(startAngle), _degToRad(valueAngle - startAngle), false, valuePaint);

    // Needle with shadow
    final needleRad = _degToRad(valueAngle);
    final nx = cx + (radius - 20) * math.cos(needleRad);
    final ny = cy + (radius - 20) * math.sin(needleRad);
    
    // Needle shadow
    canvas.drawLine(
      Offset(cx + 2, cy + 2),
      Offset(nx + 2, ny + 2),
      Paint()
        ..color = Colors.black.withOpacity(0.3)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    
    // Needle
    canvas.drawLine(
      Offset(cx, cy),
      Offset(nx, ny),
      Paint()
        ..color = color
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    // Center dot with gradient
    final centerGradient = Paint()
      ..shader = ui.Gradient.radial(
        Offset(cx - 2, cy - 2),
        10,
        [Colors.white.withOpacity(0.3), color, color.withOpacity(0.8)],
        [0.0, 0.3, 1.0],
      );
    canvas.drawCircle(Offset(cx, cy), 8, centerGradient);
    
    // Highlight on center
    canvas.drawCircle(
      Offset(cx - 2, cy - 2),
      3,
      Paint()..color = Colors.white.withOpacity(0.5),
    );

    // Value text with shadow
    _drawTextWithShadow(canvas, cx, cy + 28, v.toStringAsFixed(1),
        size.width > 120 ? 20 : 16, color, weight: FontWeight.bold);

    // Unit
    if (widget.unit.isNotEmpty) {
      _drawText(canvas, cx, cy + 46, widget.unit,
          12, colorFromHex(widget.textColor).withOpacity(0.7), align: TextAlign.center);
    }

    // Label with glass effect
    final labelBg = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, size.height - 16), width: size.width - 20, height: 20),
      const Radius.circular(10),
    );
    canvas.drawRRect(labelBg, Paint()..color = Colors.black.withOpacity(0.2));
    _drawText(canvas, cx, size.height - 12, widget.label,
        10, colorFromHex(widget.textColor).withOpacity(0.8), align: TextAlign.center);
    
    // Scale marks
    for (int i = 0; i <= 10; i++) {
      final angle = startAngle + (endAngle - startAngle) * (i / 10);
      final rad = _degToRad(angle);
      final innerR = radius - 22;
      final outerR = radius - 16;
      final x1 = cx + innerR * math.cos(rad);
      final y1 = cy + innerR * math.sin(rad);
      final x2 = cx + outerR * math.cos(rad);
      final y2 = cy + outerR * math.sin(rad);
      canvas.drawLine(
        Offset(x1, y1),
        Offset(x2, y2),
        Paint()
          ..color = Colors.white.withOpacity(i % 5 == 0 ? 0.6 : 0.3)
          ..strokeWidth = i % 5 == 0 ? 2 : 1,
      );
    }
  }

  Color? _getAlarmColor() {
    if (!widget.alarm.enabled) return null;
    if (widget.isInAlarm) return colorFromHex(widget.alarm.alarmColor);
    return null;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// ============ VERTICAL TANK PAINTER (با افکت 3D) ============
class VerticalTankPainter extends CustomPainter {
  final ScadaWidget widget;
  final double blinkOpacity;
  VerticalTankPainter(this.widget, {this.blinkOpacity = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final v = widget.scaledValue;
    final pct = _clamp((v - widget.minValue) / (widget.maxValue - widget.minValue));
    final alarmColor = _getAlarmColor();
    final primary = colorFromHex(widget.primaryColor);
    final color = alarmColor ?? primary;

    // Background
    _drawBackground(canvas, size, widget);

    final tankX = 20.0;
    final tankW = size.width - 40;
    final tankY = 30.0;
    final tankH = size.height - 70;

    // Tank body with 3D effect
    final tankRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(tankX, tankY, tankW, tankH),
      const Radius.circular(8),
    );
    
    // Tank shadow
    canvas.drawRRect(
      tankRect.shift(const Offset(3, 3)),
      Paint()
        ..color = Colors.black.withOpacity(0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    
    // Tank gradient background
    canvas.drawRRect(
      tankRect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(tankX, tankY),
          Offset(tankX + tankW, tankY),
          [const Color(0xFF0A0F1A), const Color(0xFF1A2030), const Color(0xFF0A0F1A)],
          [0.0, 0.5, 1.0],
        ),
    );
    
    // Tank border with metallic effect
    canvas.drawRRect(
      tankRect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(tankX, tankY),
          Offset(tankX + tankW, tankY),
          [const Color(0xFF3A4050), const Color(0xFF5A6070), const Color(0xFF3A4050)],
          [0.0, 0.5, 1.0],
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Liquid fill with gradient and wave effect
    final fillH = tankH * pct;
    if (fillH > 4) {
      final fillRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(tankX + 3, tankY + tankH - fillH + 3, tankW - 6, fillH - 6),
        const Radius.circular(5),
      );
      
      // Liquid gradient
      canvas.drawRRect(
        fillRect,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(tankX, tankY + tankH - fillH),
            Offset(tankX + tankW, tankY + tankH - fillH),
            [color.withOpacity(0.6), color, color.withOpacity(0.6)],
            [0.0, 0.5, 1.0],
          ),
      );
      
      // Liquid surface highlight
      canvas.drawLine(
        Offset(tankX + 8, tankY + tankH - fillH + 6),
        Offset(tankX + tankW - 8, tankY + tankH - fillH + 6),
        Paint()
          ..color = Colors.white.withOpacity(0.4)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
      
      // Bubbles effect
      final random = math.Random(42);
      for (int i = 0; i < 5; i++) {
        final bx = tankX + 10 + random.nextDouble() * (tankW - 20);
        final by = tankY + tankH - fillH + 15 + random.nextDouble() * (fillH - 25);
        final br = 2 + random.nextDouble() * 3;
        canvas.drawCircle(
          Offset(bx, by),
          br,
          Paint()..color = Colors.white.withOpacity(0.2),
        );
      }
    }

    // Level lines with glow
    for (final l in [0.25, 0.5, 0.75]) {
      final y = tankY + tankH * (1 - l);
      canvas.drawLine(
        Offset(tankX + 5, y),
        Offset(tankX + tankW - 5, y),
        Paint()
          ..color = Colors.white.withOpacity(0.15)
          ..strokeWidth = 1,
      );
      // Level label
      _drawText(canvas, tankX + tankW + 5, y + 3, '${(l * 100).toInt()}%',
          8, Colors.white.withOpacity(0.4), align: TextAlign.left);
    }

    // Glass reflection
    final reflectionPath = Path()
      ..moveTo(tankX + 5, tankY + 5)
      ..lineTo(tankX + 15, tankY + 5)
      ..lineTo(tankX + 8, tankY + tankH - 5)
      ..lineTo(tankX + 5, tankY + tankH - 5)
      ..close();
    canvas.drawPath(
      reflectionPath,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(tankX, tankY),
          Offset(tankX + 15, tankY),
          [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.02)],
        ),
    );

    // Value display
    _drawTextWithShadow(canvas, cx, tankY + tankH / 2, '${v.toStringAsFixed(1)}${widget.unit}',
        16, Colors.white, weight: FontWeight.bold);

    // Label
    _drawText(canvas, cx, size.height - 10, widget.label,
        10, colorFromHex(widget.textColor).withOpacity(0.7), align: TextAlign.center);
  }

  Color? _getAlarmColor() {
    if (!widget.alarm.enabled) return null;
    if (widget.isInAlarm) return colorFromHex(widget.alarm.alarmColor);
    return null;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// ============ HORIZONTAL TANK PAINTER ============
class HorizontalTankPainter extends CustomPainter {
  final ScadaWidget widget;
  final double blinkOpacity;
  HorizontalTankPainter(this.widget, {this.blinkOpacity = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final v = widget.scaledValue;
    final pct = _clamp((v - widget.minValue) / (widget.maxValue - widget.minValue));
    final alarmColor = _getAlarmColor();
    final primary = colorFromHex(widget.primaryColor);
    final color = alarmColor ?? primary;

    // Background
    _drawBackground(canvas, size, widget);

    final tankX = 15.0;
    final tankW = size.width - 30;
    final tankY = 20.0;
    final tankH = size.height - 55;
    final fillW = tankW * pct;

    // Tank body with 3D cylinder effect
    // Shadow
    canvas.drawOval(
      Rect.fromCenter(center: Offset(tankX + tankW - 12, cy + 3), width: 24, height: tankH),
      Paint()
        ..color = Colors.black.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    
    // Cylinder ends
    canvas.drawOval(
      Rect.fromCenter(center: Offset(tankX + 12, cy), width: 24, height: tankH),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(tankX, tankY),
          Offset(tankX + 24, tankY),
          [const Color(0xFF1A2030), const Color(0xFF2A3040), const Color(0xFF1A2030)],
        ),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(tankX + tankW - 12, cy), width: 24, height: tankH),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(tankX + tankW - 24, tankY),
          Offset(tankX + tankW, tankY),
          [const Color(0xFF1A2030), const Color(0xFF2A3040), const Color(0xFF1A2030)],
        ),
    );
    
    // Tank body
    canvas.drawRect(
      Rect.fromLTWH(tankX + 12, tankY, tankW - 24, tankH),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(tankX, tankY),
          Offset(tankX, tankY + tankH),
          [const Color(0xFF1A2030), const Color(0xFF0A0F1A), const Color(0xFF1A2030)],
        ),
    );
    
    // Border
    canvas.drawRect(
      Rect.fromLTWH(tankX + 12, tankY, tankW - 24, tankH),
      Paint()
        ..color = const Color(0xFF4A5060)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Fill
    if (fillW > 20) {
      canvas.drawRect(
        Rect.fromLTWH(tankX + 14, tankY + 3, fillW - 28, tankH - 6),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(tankX, tankY),
            Offset(tankX, tankY + tankH),
            [color.withOpacity(0.6), color, color.withOpacity(0.6)],
          ),
      );
    }

    _drawTextWithShadow(canvas, cx, cy + 5, '${v.toStringAsFixed(1)}${widget.unit}',
        14, Colors.white, weight: FontWeight.bold);
    _drawText(canvas, cx, size.height - 8, widget.label,
        10, colorFromHex(widget.textColor).withOpacity(0.7), align: TextAlign.center);
  }

  Color? _getAlarmColor() {
    if (!widget.alarm.enabled) return null;
    if (widget.isInAlarm) return colorFromHex(widget.alarm.alarmColor);
    return null;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// ============ TEMPERATURE PAINTER (با افکت ترمومتر واقعی) ============
class TemperaturePainter extends CustomPainter {
  final ScadaWidget widget;
  final double blinkOpacity;
  TemperaturePainter(this.widget, {this.blinkOpacity = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final v = widget.scaledValue;
    final pct = _clamp((v - widget.minValue) / (widget.maxValue - widget.minValue));
    final alarmColor = widget.isInAlarm ? colorFromHex(widget.alarm.alarmColor) : null;
    
    // Temperature-based color
    Color color;
    if (alarmColor != null) {
      color = alarmColor;
    } else if (v > 80) {
      color = const Color(0xFFEF4444); // Red hot
    } else if (v > 50) {
      color = const Color(0xFFF97316); // Orange warm
    } else if (v > 25) {
      color = const Color(0xFFEAB308); // Yellow
    } else {
      color = const Color(0xFF3B82F6); // Blue cold
    }

    // Background
    _drawBackground(canvas, size, widget);

    final tubeW = 16.0;
    final tubeH = size.height - 90;
    final tubeY = 25.0;
    final bulbR = 22.0;

    // Tube shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - tubeW / 2 + 2, tubeY + 2, tubeW, tubeH),
        const Radius.circular(8),
      ),
      Paint()
        ..color = Colors.black.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Tube background with glass effect
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - tubeW / 2, tubeY, tubeW, tubeH),
        const Radius.circular(8),
      ),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(cx - tubeW / 2, tubeY),
          Offset(cx + tubeW / 2, tubeY),
          [const Color(0xFF1A2030), const Color(0xFF2A3545), const Color(0xFF1A2030)],
        ),
    );
    
    // Glass reflection
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - tubeW / 2 + 2, tubeY + 2, 4, tubeH - 4),
        const Radius.circular(6),
      ),
      Paint()..color = Colors.white.withOpacity(0.1),
    );

    // Mercury/Fill with glow
    final fillH = tubeH * pct;
    if (fillH > 4) {
      // Glow
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - tubeW / 2 - 4, tubeY + tubeH - fillH - 4, tubeW + 8, fillH + 8),
          const Radius.circular(10),
        ),
        Paint()
          ..color = color.withOpacity(0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      
      // Fill gradient
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - tubeW / 2 + 3, tubeY + tubeH - fillH, tubeW - 6, fillH),
          const Radius.circular(5),
        ),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(cx - tubeW / 2, tubeY),
            Offset(cx + tubeW / 2, tubeY),
            [color.withOpacity(0.7), color, color.withOpacity(0.7)],
          ),
      );
    }

    // Bulb with 3D effect
    // Shadow
    canvas.drawCircle(
      Offset(cx + 2, tubeY + tubeH + 15),
      bulbR,
      Paint()
        ..color = Colors.black.withOpacity(0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    
    // Bulb gradient
    canvas.drawCircle(
      Offset(cx, tubeY + tubeH + 12),
      bulbR,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(cx - 5, tubeY + tubeH + 8),
          bulbR,
          [color.withOpacity(0.9), color, color.withOpacity(0.6)],
          [0.0, 0.5, 1.0],
        ),
    );
    
    // Bulb highlight
    canvas.drawCircle(
      Offset(cx - 6, tubeY + tubeH + 6),
      6,
      Paint()..color = Colors.white.withOpacity(0.4),
    );
    
    // Bulb glow
    canvas.drawCircle(
      Offset(cx, tubeY + tubeH + 12),
      bulbR + 8,
      Paint()
        ..color = color.withOpacity(0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Scale marks
    for (final l in [0.0, 0.25, 0.5, 0.75, 1.0]) {
      final y = tubeY + tubeH * (1 - l);
      canvas.drawLine(
        Offset(cx + tubeW / 2 + 4, y),
        Offset(cx + tubeW / 2 + 12, y),
        Paint()
          ..color = Colors.white.withOpacity(0.5)
          ..strokeWidth = l == 0.5 ? 2 : 1,
      );
      final value = widget.minValue + (widget.maxValue - widget.minValue) * l;
      _drawText(canvas, cx + tubeW / 2 + 16, y + 3, value.toStringAsFixed(0),
          9, colorFromHex(widget.textColor).withOpacity(0.6), align: TextAlign.left);
    }

    // Value display
    _drawTextWithShadow(canvas, cx, size.height - 12, '${v.toStringAsFixed(1)}${widget.unit}',
        13, color, weight: FontWeight.bold);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// ============ LED PAINTER (با افکت Glow) ============
class LedPainter extends CustomPainter {
  final ScadaWidget widget;
  final double blinkOpacity;  // برای چشمک زدن (0.0 - 1.0)
  LedPainter(this.widget, {this.blinkOpacity = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 - 6;
    final on = widget.boolValue || widget.value > 0;
    final color = on ? colorFromHex(widget.activeColor) : colorFromHex(widget.inactiveColor);
    final r = math.min(size.width, size.height) / 2 - 14;

    // Background
    _drawBackground(canvas, size, widget);

    // LED housing (bezel)
    canvas.drawCircle(
      Offset(cx, cy),
      r + 6,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(cx - r, cy - r),
          Offset(cx + r, cy + r),
          [const Color(0xFF4A5060), const Color(0xFF2A3040), const Color(0xFF1A2030)],
        ),
    );

    if (on) {
      // Outer glow
      canvas.drawCircle(
        Offset(cx, cy),
        r + 15,
        Paint()
          ..color = color.withOpacity(0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15),
      );
      
      // Inner glow
      canvas.drawCircle(
        Offset(cx, cy),
        r + 5,
        Paint()
          ..color = color.withOpacity(0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    // LED body with gradient
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(cx - r * 0.3, cy - r * 0.3),
          r * 1.5,
          on
              ? [Colors.white.withOpacity(0.8), color, color.withOpacity(0.6)]
              : [color.withOpacity(0.4), color.withOpacity(0.2), color.withOpacity(0.1)],
          [0.0, 0.4, 1.0],
        ),
    );

    // Highlight
    if (on) {
      canvas.drawCircle(
        Offset(cx - r * 0.3, cy - r * 0.3),
        r * 0.3,
        Paint()..color = Colors.white.withOpacity(0.6),
      );
    }

    _drawText(canvas, cx, size.height - 8, widget.label,
        9, colorFromHex(widget.textColor).withOpacity(0.7), align: TextAlign.center);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// ============ LED DUAL PAINTER (دو ورودی با چشمک زدن) ============
class LedDualPainter extends CustomPainter {
  final ScadaWidget widget;
  final double blinkOpacity;  // برای چشمک زدن (0.0 - 1.0)
  
  LedDualPainter(this.widget, {this.blinkOpacity = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 - 6;
    final config = widget.ledDualConfig;
    final r = math.min(size.width, size.height) / 2 - 14;

    // تعیین وضعیت و رنگ
    final bool input1Active = config.input1 || widget.value > 0;
    final bool input2Active = config.input2 || widget.boolValue;
    
    Color color;
    bool shouldBlink = false;
    
    if (input2Active) {
      // حالت دوم (آلارم) - اولویت بالاتر
      color = colorFromHex(config.input2Color);
      shouldBlink = config.blinkOnInput2;
    } else if (input1Active) {
      // حالت عادی
      color = colorFromHex(config.input1Color);
    } else {
      // خاموش
      color = colorFromHex(widget.inactiveColor);
    }

    // محاسبه شفافیت برای چشمک زدن
    final opacity = shouldBlink ? blinkOpacity : 1.0;
    final isOn = input1Active || input2Active;

    // Background
    _drawBackground(canvas, size, widget);

    // LED housing (bezel)
    canvas.drawCircle(
      Offset(cx, cy),
      r + 6,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(cx - r, cy - r),
          Offset(cx + r, cy + r),
          [const Color(0xFF4A5060), const Color(0xFF2A3040), const Color(0xFF1A2030)],
        ),
    );

    if (isOn) {
      // Outer glow with blink
      canvas.drawCircle(
        Offset(cx, cy),
        r + 18,
        Paint()
          ..color = color.withOpacity(0.4 * opacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
      
      // Inner glow with blink
      canvas.drawCircle(
        Offset(cx, cy),
        r + 8,
        Paint()
          ..color = color.withOpacity(0.6 * opacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }

    // LED body with gradient and blink opacity
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(cx - r * 0.3, cy - r * 0.3),
          r * 1.5,
          isOn
              ? [
                  Colors.white.withOpacity(0.8 * opacity),
                  color.withOpacity(opacity),
                  color.withOpacity(0.6 * opacity)
                ]
              : [
                  color.withOpacity(0.4),
                  color.withOpacity(0.2),
                  color.withOpacity(0.1)
                ],
          [0.0, 0.4, 1.0],
        ),
    );

    // Highlight
    if (isOn) {
      canvas.drawCircle(
        Offset(cx - r * 0.3, cy - r * 0.3),
        r * 0.3,
        Paint()..color = Colors.white.withOpacity(0.6 * opacity),
      );
    }

    // Status indicators (دو نقطه کوچک برای نشان دادن ورودی‌ها)
    // Input 1 indicator
    canvas.drawCircle(
      Offset(cx - 12, size.height - 14),
      4,
      Paint()..color = input1Active 
          ? colorFromHex(config.input1Color) 
          : Colors.grey.withOpacity(0.3),
    );
    // Input 2 indicator
    canvas.drawCircle(
      Offset(cx + 12, size.height - 14),
      4,
      Paint()..color = input2Active 
          ? colorFromHex(config.input2Color).withOpacity(opacity) 
          : Colors.grey.withOpacity(0.3),
    );

    _drawText(canvas, cx, size.height - 26, widget.label,
        8, colorFromHex(widget.textColor).withOpacity(0.7), align: TextAlign.center);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// ============ SWITCH PAINTER (با افکت مدرن) ============
class SwitchPainter extends CustomPainter {
  final ScadaWidget widget;
  SwitchPainter(this.widget);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final on = widget.boolValue || widget.value > 0;
    final color = on ? colorFromHex(widget.activeColor) : const Color(0xFF475569);

    // Background
    _drawBackground(canvas, size, widget);

    // Track shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx - 26, 14, 52, 28), const Radius.circular(14)),
      Paint()
        ..color = Colors.black.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Track with gradient
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx - 24, 12, 48, 24), const Radius.circular(12)),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(cx - 24, 12),
          Offset(cx - 24, 36),
          on
              ? [color.withOpacity(0.8), color, color.withOpacity(0.9)]
              : [const Color(0xFF3A4050), const Color(0xFF2A3040), const Color(0xFF3A4050)],
        ),
    );
    
    // Track inner shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx - 22, 14, 44, 20), const Radius.circular(10)),
      Paint()
        ..color = Colors.black.withOpacity(0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Glow when on
    if (on) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(cx - 28, 8, 56, 32), const Radius.circular(16)),
        Paint()
          ..color = color.withOpacity(0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    // Thumb shadow
    final thumbX = on ? cx + 12 : cx - 12;
    canvas.drawCircle(
      Offset(thumbX + 1, 25),
      10,
      Paint()
        ..color = Colors.black.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Thumb with gradient
    canvas.drawCircle(
      Offset(thumbX, 24),
      10,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(thumbX - 3, 21),
          12,
          [Colors.white, const Color(0xFFE0E0E0), const Color(0xFFB0B0B0)],
          [0.0, 0.5, 1.0],
        ),
    );

    _drawText(canvas, cx, size.height - 8, '${widget.label}: ${on ? 'ON' : 'OFF'}',
        10, colorFromHex(widget.textColor), align: TextAlign.center);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// ============ DIGITAL DISPLAY PAINTER (با افکت LCD) ============
class DigitalDisplayPainter extends CustomPainter {
  final ScadaWidget widget;
  DigitalDisplayPainter(this.widget);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final v = widget.scaledValue;
    final alarmColor = widget.isInAlarm ? colorFromHex(widget.alarm.alarmColor) : null;
    final color = alarmColor ?? colorFromHex(widget.primaryColor);

    // Outer bezel
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(8)),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, 0),
          Offset(0, size.height),
          [const Color(0xFF3A4050), const Color(0xFF1A2030)],
        ),
    );

    // LCD screen with slight inset
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(4, 4, size.width - 8, size.height - 8), const Radius.circular(4)),
      Paint()..color = const Color(0xFF050810),
    );
    
    // Screen glow
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(6, 6, size.width - 12, size.height - 12), const Radius.circular(3)),
      Paint()
        ..color = color.withOpacity(0.05)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    
    // Scan line effect
    for (int i = 0; i < size.height.toInt(); i += 3) {
      canvas.drawLine(
        Offset(6, i.toDouble()),
        Offset(size.width - 6, i.toDouble()),
        Paint()..color = Colors.white.withOpacity(0.02),
      );
    }

    // Value with glow
    _drawTextWithGlow(canvas, cx, cy, v.toStringAsFixed(2),
        math.min(size.height * 0.45, 32), color, weight: FontWeight.bold, font: 'monospace');

    // Unit
    if (widget.unit.isNotEmpty) {
      _drawText(canvas, size.width - 12, cy, widget.unit,
          11, color.withOpacity(0.7), align: TextAlign.right);
    }

    // Label
    _drawText(canvas, 12, 14, widget.label, 9, colorFromHex(widget.textColor).withOpacity(0.5), align: TextAlign.left);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// ============ TEXT DISPLAY PAINTER ============
class TextDisplayPainter extends CustomPainter {
  final ScadaWidget widget;
  TextDisplayPainter(this.widget);

  @override
  void paint(Canvas canvas, Size size) {
    final v = widget.scaledValue;
    final alarmColor = widget.isInAlarm ? colorFromHex(widget.alarm.alarmColor) : null;
    final color = alarmColor ?? colorFromHex(widget.textColor);

    _drawBackground(canvas, size, widget);

    _drawText(canvas, 12, size.height / 2 - 8, widget.label, 10,
        colorFromHex(widget.textColor).withOpacity(0.6), align: TextAlign.left);
    _drawTextWithShadow(canvas, 12, size.height / 2 + 12, '${v.toStringAsFixed(1)} ${widget.unit}',
        16, color, weight: FontWeight.bold, alignLeft: true);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// ============ VERTICAL BAR PAINTER ============
class VerticalBarPainter extends CustomPainter {
  final ScadaWidget widget;
  VerticalBarPainter(this.widget);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final v = widget.scaledValue;
    final pct = _clamp((v - widget.minValue) / (widget.maxValue - widget.minValue));
    final alarmColor = widget.isInAlarm ? colorFromHex(widget.alarm.alarmColor) : null;
    final color = alarmColor ?? colorFromHex(widget.primaryColor);

    _drawBackground(canvas, size, widget);

    final barW = size.width - 24;
    final barH = size.height - 45;
    final bx = 12.0;
    final by = 12.0;

    // Bar background
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, barW, barH), const Radius.circular(4)),
      Paint()..color = const Color(0xFF0A0F1A),
    );

    // Fill with gradient
    final fillH = barH * pct;
    if (fillH > 2) {
      // Glow
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(bx - 3, by + barH - fillH - 3, barW + 6, fillH + 6),
          const Radius.circular(6),
        ),
        Paint()
          ..color = color.withOpacity(0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(bx + 2, by + barH - fillH, barW - 4, fillH), const Radius.circular(3)),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(bx, by),
            Offset(bx + barW, by),
            [color.withOpacity(0.6), color, color.withOpacity(0.6)],
          ),
      );
    }

    _drawTextWithShadow(canvas, cx, size.height - 10, '${v.toStringAsFixed(1)}${widget.unit}',
        11, color, weight: FontWeight.bold);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// ============ HORIZONTAL BAR PAINTER ============
class HorizontalBarPainter extends CustomPainter {
  final ScadaWidget widget;
  HorizontalBarPainter(this.widget);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final v = widget.scaledValue;
    final pct = _clamp((v - widget.minValue) / (widget.maxValue - widget.minValue));
    final alarmColor = widget.isInAlarm ? colorFromHex(widget.alarm.alarmColor) : null;
    final color = alarmColor ?? colorFromHex(widget.primaryColor);

    _drawBackground(canvas, size, widget);

    final barW = size.width - 20;
    final barH = size.height - 38;

    _drawText(canvas, 10, 12, widget.label, 9, colorFromHex(widget.textColor).withOpacity(0.6), align: TextAlign.left);

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(10, 20, barW, barH), const Radius.circular(4)),
      Paint()..color = const Color(0xFF0A0F1A),
    );

    final fillW = (barW - 4) * pct;
    if (fillW > 2) {
      // Glow
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(10, 18, fillW + 4, barH + 4), const Radius.circular(5)),
        Paint()
          ..color = color.withOpacity(0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(12, 22, fillW, barH - 4), const Radius.circular(2)),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(12, 20),
            Offset(12, 20 + barH),
            [color.withOpacity(0.7), color, color.withOpacity(0.7)],
          ),
      );
    }

    _drawTextWithShadow(canvas, cx, 20 + barH / 2 + 4, '${v.toStringAsFixed(1)}${widget.unit}',
        12, Colors.white, weight: FontWeight.bold);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// ============ FAN PAINTER (با انیمیشن چرخش واقعی) ============
class FanPainter extends CustomPainter {
  final ScadaWidget widget;
  final double rotation;
  FanPainter(this.widget, this.rotation);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 - 8;
    final on = widget.boolValue || widget.value > 0;
    final color = on ? colorFromHex(widget.activeColor) : colorFromHex(widget.inactiveColor);
    final r = math.min(cx, cy) * 0.6;

    // Background
    _drawBackground(canvas, size, widget);

    // Housing shadow
    canvas.drawCircle(
      Offset(cx + 2, cy + 3),
      r + 12,
      Paint()
        ..color = Colors.black.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Fan housing with metallic gradient
    canvas.drawCircle(
      Offset(cx, cy),
      r + 10,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(cx - 10, cy - 10),
          r + 20,
          [const Color(0xFF5A6070), const Color(0xFF3A4050), const Color(0xFF2A3040)],
          [0.0, 0.5, 1.0],
        ),
    );
    
    // Inner ring
    canvas.drawCircle(
      Offset(cx, cy),
      r + 5,
      Paint()
        ..color = const Color(0xFF1A2030)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Glow when running
    if (on) {
      canvas.drawCircle(
        Offset(cx, cy),
        r + 15,
        Paint()
          ..color = color.withOpacity(0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
    }

    // Fan blades
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(rotation);

    for (int i = 0; i < 4; i++) {
      final angle = i * math.pi / 2;
      canvas.save();
      canvas.rotate(angle);
      
      // Blade shape
      final bladePath = Path()
        ..moveTo(0, -8)
        ..quadraticBezierTo(r * 0.4, -r * 0.3, r * 0.8, -r * 0.1)
        ..quadraticBezierTo(r * 0.85, 0, r * 0.8, r * 0.1)
        ..quadraticBezierTo(r * 0.4, r * 0.3, 0, 8)
        ..close();
      
      // Blade shadow
      canvas.drawPath(
        bladePath.shift(const Offset(2, 2)),
        Paint()
          ..color = Colors.black.withOpacity(0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      
      // Blade with gradient
      canvas.drawPath(
        bladePath,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, -10),
            Offset(0, 10),
            [color.withOpacity(0.9), color.withOpacity(0.6)],
          ),
      );
      
      canvas.restore();
    }
    canvas.restore();

    // Center hub
    canvas.drawCircle(
      Offset(cx, cy),
      12,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(cx - 3, cy - 3),
          15,
          [const Color(0xFF6A7080), const Color(0xFF4A5060), const Color(0xFF3A4050)],
          [0.0, 0.5, 1.0],
        ),
    );
    canvas.drawCircle(
      Offset(cx - 3, cy - 3),
      4,
      Paint()..color = Colors.white.withOpacity(0.3),
    );

    _drawText(canvas, cx, size.height - 10, '${widget.label} ${on ? 'ON' : 'OFF'}',
        10, colorFromHex(widget.textColor), align: TextAlign.center);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// ============ MOTOR PAINTER ============
class MotorPainter extends CustomPainter {
  final ScadaWidget widget;
  MotorPainter(this.widget);

  @override
  void paint(Canvas canvas, Size size) {
    final on = widget.boolValue || widget.value > 0;
    final color = on ? colorFromHex(widget.activeColor) : colorFromHex(widget.inactiveColor);
    final mx = 20.0;
    final my = 18.0;
    final mw = size.width - 50;
    final mh = size.height - 48;

    // Background
    _drawBackground(canvas, size, widget);

    // Motor body shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(mx + 3, my + 3, mw, mh), const Radius.circular(10)),
      Paint()
        ..color = Colors.black.withOpacity(0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Motor body with metallic gradient
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(mx, my, mw, mh), const Radius.circular(10)),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(mx, my),
          Offset(mx, my + mh),
          [const Color(0xFF3A4050), const Color(0xFF2A3040), const Color(0xFF1A2030)],
        ),
    );
    
    // Motor body border
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(mx, my, mw, mh), const Radius.circular(10)),
      Paint()
        ..color = color.withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    
    // Cooling fins
    for (int i = 0; i < 4; i++) {
      final finY = my + 8 + i * (mh - 16) / 4;
      canvas.drawLine(
        Offset(mx + 8, finY),
        Offset(mx + mw - 8, finY),
        Paint()
          ..color = const Color(0xFF1A2030)
          ..strokeWidth = 2,
      );
    }

    // M label with glow
    if (on) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'M',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            foreground: Paint()
              ..color = color
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(mx + mw / 2 - textPainter.width / 2, my + mh / 2 - textPainter.height / 2));
    }
    
    final textPainter2 = TextPainter(
      text: TextSpan(text: 'M', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
      textDirection: TextDirection.ltr,
    );
    textPainter2.layout();
    textPainter2.paint(canvas, Offset(mx + mw / 2 - textPainter2.width / 2, my + mh / 2 - textPainter2.height / 2));

    // Shaft with 3D effect
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(mx + mw, my + mh / 2 - 5, 22, 10), const Radius.circular(2)),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(mx + mw, my + mh / 2 - 5),
          Offset(mx + mw, my + mh / 2 + 5),
          [const Color(0xFF7A8090), const Color(0xFF5A6070), const Color(0xFF4A5060)],
        ),
    );

    // Status LED
    if (on) {
      canvas.drawCircle(
        Offset(mx + 15, my + 15),
        8,
        Paint()
          ..color = const Color(0xFF22C55E).withOpacity(0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
    canvas.drawCircle(
      Offset(mx + 15, my + 15),
      5,
      Paint()..color = on ? const Color(0xFF22C55E) : const Color(0xFF64748B),
    );

    final label = on ? '${widget.scaledValue.toStringAsFixed(0)} RPM' : 'OFF';
    _drawText(canvas, size.width / 2, size.height - 8, '${widget.label} $label',
        9, colorFromHex(widget.textColor), align: TextAlign.center);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// ============ GATE VALVE PAINTER ============
class GateValvePainter extends CustomPainter {
  final ScadaWidget widget;
  GateValvePainter(this.widget);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 - 5;
    final state = widget.currentState ?? 'unknown';
    final stateColors = {
      'open': widget.states['open']?.color ?? '#22C55E',
      'closed': widget.states['closed']?.color ?? '#EF4444',
      'partial': widget.states['partial']?.color ?? '#EAB308',
      'unknown': widget.states['unknown']?.color ?? '#94A3B8',
    };
    final color = colorFromHex(stateColors[state] ?? '#94A3B8');

    // Background
    _drawBackground(canvas, size, widget);

    // Pipes with 3D effect
    _drawPipe(canvas, 5, cy - 8, cx - 22, 16);
    _drawPipe(canvas, cx + 17, cy - 8, cx - 22, 16);

    // Valve body shadow
    canvas.drawRect(
      Rect.fromCenter(center: Offset(cx + 2, cy + 2), width: 28, height: 38),
      Paint()
        ..color = Colors.black.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Valve body with gradient
    final valvePath = Path()
      ..moveTo(cx - 14, cy - 19)
      ..lineTo(cx + 14, cy - 19)
      ..lineTo(cx + 14, cy + 19)
      ..lineTo(cx - 14, cy + 19)
      ..close();
    
    canvas.drawPath(
      valvePath,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(cx - 14, cy),
          Offset(cx + 14, cy),
          [color.withOpacity(0.6), color, color.withOpacity(0.6)],
        ),
    );
    canvas.drawPath(valvePath, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2);

    // Glow for open state
    if (state == 'open') {
      canvas.drawPath(
        valvePath,
        Paint()
          ..color = color.withOpacity(0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }

    // Stem and handwheel
    canvas.drawRect(
      Rect.fromLTWH(cx - 3, cy - 35, 6, 18),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(cx - 3, cy - 35),
          Offset(cx + 3, cy - 35),
          [const Color(0xFF7A8090), const Color(0xFFA0A8B0), const Color(0xFF7A8090)],
        ),
    );
    
    // Handwheel
    canvas.drawCircle(
      Offset(cx, cy - 38),
      10,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(cx - 3, cy - 41),
          12,
          [const Color(0xFFB0B8C0), const Color(0xFF7A8090), const Color(0xFF5A6070)],
        ),
    );
    canvas.drawCircle(Offset(cx, cy - 38), 3, Paint()..color = const Color(0xFF3A4050));

    final label = (widget.states[state]?.label ?? state).toUpperCase();
    _drawText(canvas, cx, size.height - 8, '${widget.label}: $label',
        9, colorFromHex(widget.textColor), align: TextAlign.center);
  }

  void _drawPipe(Canvas canvas, double x, double y, double w, double h) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), const Radius.circular(2)),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(x, y),
          Offset(x, y + h),
          [const Color(0xFF5A6070), const Color(0xFF3A4050), const Color(0xFF2A3040)],
        ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// ============ CONTROL VALVE PAINTER ============
class ControlValvePainter extends CustomPainter {
  final ScadaWidget widget;
  ControlValvePainter(this.widget);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final v = widget.scaledValue;
    final pct = _clamp((v - widget.minValue) / (widget.maxValue - widget.minValue));
    final alarmColor = widget.isInAlarm ? colorFromHex(widget.alarm.alarmColor) : null;
    final color = alarmColor ?? colorFromHex(widget.primaryColor);

    _drawBackground(canvas, size, widget);

    // Pipes
    _drawPipe(canvas, 5, cy - 6, cx - 20, 12);
    _drawPipe(canvas, cx + 15, cy - 6, cx - 20, 12);

    // Valve triangles with gradient
    final leftPath = Path()
      ..moveTo(cx - 16, cy - 16)
      ..lineTo(cx, cy)
      ..lineTo(cx - 16, cy + 16)
      ..close();
    
    canvas.drawPath(leftPath, Paint()
      ..shader = ui.Gradient.linear(
        Offset(cx - 16, cy - 16),
        Offset(cx, cy),
        [color.withOpacity(0.5), color.withOpacity(0.9)],
      ));

    final rightPath = Path()
      ..moveTo(cx + 16, cy - 16)
      ..lineTo(cx, cy)
      ..lineTo(cx + 16, cy + 16)
      ..close();
    
    canvas.drawPath(rightPath, Paint()
      ..shader = ui.Gradient.linear(
        Offset(cx + 16, cy - 16),
        Offset(cx, cy),
        [color.withOpacity(0.5), color.withOpacity(0.9)],
      ));

    // Stem
    canvas.drawRect(
      Rect.fromLTWH(cx - 2, cy - 30, 4, 18),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(cx - 2, cy - 30),
          Offset(cx + 2, cy - 30),
          [const Color(0xFF7A8090), const Color(0xFFA0A8B0), const Color(0xFF7A8090)],
        ),
    );

    // Actuator
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx - 12, cy - 42, 24, 14), const Radius.circular(4)),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(cx, cy - 42),
          Offset(cx, cy - 28),
          [const Color(0xFF4A5060), const Color(0xFF2A3040)],
        ),
    );

    // Percentage display
    _drawText(canvas, cx, cy - 33, '${(pct * 100).toStringAsFixed(0)}%',
        9, Colors.white, align: TextAlign.center, weight: FontWeight.bold);
    _drawText(canvas, cx, size.height - 8, widget.label,
        9, colorFromHex(widget.textColor), align: TextAlign.center);
  }

  void _drawPipe(Canvas canvas, double x, double y, double w, double h) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), const Radius.circular(2)),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(x, y),
          Offset(x, y + h),
          [const Color(0xFF5A6070), const Color(0xFF3A4050), const Color(0xFF2A3040)],
        ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// ============ RELAY PAINTER ============
class RelayPainter extends CustomPainter {
  final ScadaWidget widget;
  RelayPainter(this.widget);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 - 5;
    final on = widget.boolValue || widget.value > 0;
    final color = on ? colorFromHex(widget.activeColor) : colorFromHex(widget.inactiveColor);

    _drawBackground(canvas, size, widget);

    // Relay body shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx - 22, cy - 20, 44, 40), const Radius.circular(6)),
      Paint()
        ..color = Colors.black.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Relay body
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx - 20, cy - 18, 40, 36), const Radius.circular(4)),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(cx - 20, cy - 18),
          Offset(cx - 20, cy + 18),
          [const Color(0xFF2A3040), const Color(0xFF1A2030)],
        ),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx - 20, cy - 18, 40, 36), const Radius.circular(4)),
      Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2,
    );

    // Contacts
    final contactPaint = Paint()..color = color..strokeWidth = 3..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx - 12, cy - 8), Offset(cx - 12, cy + 8), contactPaint);
    canvas.drawLine(Offset(cx + 12, cy - 8), Offset(cx + 12, cy + 8), contactPaint);
    
    // Moving contact
    if (on) {
      canvas.drawLine(Offset(cx - 12, cy), Offset(cx + 12, cy), contactPaint);
      // Spark effect
      canvas.drawCircle(Offset(cx, cy), 4, Paint()
        ..color = Colors.yellow.withOpacity(0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    } else {
      canvas.drawLine(Offset(cx - 12, cy), Offset(cx + 12, cy - 12), contactPaint);
    }

    // Status LED
    if (on) {
      canvas.drawCircle(Offset(cx, cy - 13), 5, Paint()
        ..color = const Color(0xFF22C55E).withOpacity(0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    }
    canvas.drawCircle(Offset(cx, cy - 13), 3, Paint()..color = on ? const Color(0xFF22C55E) : const Color(0xFF64748B));

    _drawText(canvas, cx, size.height - 8, '${widget.label} ${on ? 'ON' : 'OFF'}',
        9, colorFromHex(widget.textColor), align: TextAlign.center);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// ============ SLIDER PAINTER ============
class SliderPainter extends CustomPainter {
  final ScadaWidget widget;
  SliderPainter(this.widget);

  @override
  void paint(Canvas canvas, Size size) {
    final v = widget.scaledValue;
    final pct = _clamp((v - widget.minValue) / (widget.maxValue - widget.minValue));
    final trackY = size.height / 2;
    final trackX = 15.0;
    final trackW = size.width - 30;
    final color = colorFromHex(widget.primaryColor);

    _drawBackground(canvas, size, widget);

    _drawText(canvas, 10, 12, widget.label, 9, colorFromHex(widget.textColor).withOpacity(0.6), align: TextAlign.left);

    // Track background
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(trackX, trackY - 4, trackW, 8), const Radius.circular(4)),
      Paint()..color = const Color(0xFF0A0F1A),
    );

    // Track fill with glow
    final fillW = trackW * pct;
    if (fillW > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(trackX - 2, trackY - 6, fillW + 4, 12), const Radius.circular(6)),
        Paint()
          ..color = color.withOpacity(0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(trackX, trackY - 4, fillW, 8), const Radius.circular(4)),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(trackX, trackY - 4),
            Offset(trackX, trackY + 4),
            [color.withOpacity(0.8), color],
          ),
      );
    }

    // Thumb
    final thumbX = trackX + trackW * pct;
    canvas.drawCircle(Offset(thumbX, trackY), 12, Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawCircle(Offset(thumbX, trackY), 10, Paint()
      ..shader = ui.Gradient.radial(
        Offset(thumbX - 3, trackY - 3),
        12,
        [Colors.white, color, color.withOpacity(0.8)],
        [0.0, 0.5, 1.0],
      ));

    _drawText(canvas, size.width - 10, size.height - 10, '${v.toStringAsFixed(1)}${widget.unit}',
        10, color, align: TextAlign.right, weight: FontWeight.bold);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// ============ STATUS INDICATOR PAINTER ============
class StatusIndicatorPainter extends CustomPainter {
  final ScadaWidget widget;
  StatusIndicatorPainter(this.widget);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 - 10;
    final state = widget.currentState ?? 'unknown';
    final color = colorFromHex(widget.states[state]?.color ?? '#94A3B8');
    final label = widget.states[state]?.label ?? state;
    final r = math.min(cx, cy) * 0.45;

    _drawBackground(canvas, size, widget);

    // Outer ring
    canvas.drawCircle(Offset(cx, cy), r + 8, Paint()
      ..shader = ui.Gradient.radial(
        Offset(cx, cy),
        r + 10,
        [const Color(0xFF4A5060), const Color(0xFF2A3040)],
      ));
    canvas.drawCircle(Offset(cx, cy), r + 5, Paint()..color = const Color(0xFF1A2030));

    // Glow
    canvas.drawCircle(Offset(cx, cy), r + 12, Paint()
      ..color = color.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));

    // Main indicator with gradient
    canvas.drawCircle(Offset(cx, cy), r, Paint()
      ..shader = ui.Gradient.radial(
        Offset(cx - r * 0.3, cy - r * 0.3),
        r * 1.5,
        [Colors.white.withOpacity(0.5), color, color.withOpacity(0.7)],
        [0.0, 0.4, 1.0],
      ));

    // Highlight
    canvas.drawCircle(Offset(cx - r * 0.3, cy - r * 0.3), r * 0.25,
        Paint()..color = Colors.white.withOpacity(0.5));

    _drawTextWithShadow(canvas, cx, cy + r + 20, label,
        11, colorFromHex(widget.textColor), weight: FontWeight.bold);
    _drawText(canvas, cx, size.height - 8, widget.label,
        9, colorFromHex(widget.textColor).withOpacity(0.6), align: TextAlign.center);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// ============ GRAPH PAINTER ============
class GraphPainter extends CustomPainter {
  final ScadaWidget widget;
  final List<double> history;
  GraphPainter(this.widget, this.history);

  @override
  void paint(Canvas canvas, Size size) {
    final alarmColor = widget.isInAlarm ? colorFromHex(widget.alarm.alarmColor) : null;
    final color = alarmColor ?? colorFromHex(widget.primaryColor);
    final v = widget.scaledValue;

    _drawBackground(canvas, size, widget);

    _drawText(canvas, 12, 16, widget.label, 10, colorFromHex(widget.textColor).withOpacity(0.6), align: TextAlign.left);

    // Grid
    for (final l in [0.25, 0.5, 0.75]) {
      final y = 35 + (size.height - 65) * l;
      canvas.drawLine(Offset(45, y), Offset(size.width - 12, y),
          Paint()..color = Colors.white.withOpacity(0.1)..strokeWidth = 0.5);
    }

    if (history.isNotEmpty && history.length > 1) {
      final path = Path();
      final fillPath = Path();
      final stepX = (size.width - 60) / (history.length - 1);
      
      for (var i = 0; i < history.length; i++) {
        final pct = _clamp(history[i]);
        final x = 45 + stepX * i;
        final y = 35 + (size.height - 65) * (1 - pct);
        if (i == 0) {
          path.moveTo(x, y);
          fillPath.moveTo(x, size.height - 30);
          fillPath.lineTo(x, y);
        } else {
          path.lineTo(x, y);
          fillPath.lineTo(x, y);
        }
      }
      fillPath.lineTo(size.width - 15, size.height - 30);
      fillPath.close();

      // Fill gradient
      canvas.drawPath(fillPath, Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, 35),
          Offset(0, size.height - 30),
          [color.withOpacity(0.3), color.withOpacity(0.0)],
        ));

      // Line glow
      canvas.drawPath(path, Paint()
        ..color = color.withOpacity(0.5)
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));

      // Main line
      canvas.drawPath(path, Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round);
    }

    _drawTextWithShadow(canvas, size.width - 12, 16, '${v.toStringAsFixed(1)}${widget.unit}',
        13, color, weight: FontWeight.bold, alignLeft: false);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// ============ CHART PAINTER ============
class ChartPainter extends CustomPainter {
  final ScadaWidget widget;
  final List<double> history;
  ChartPainter(this.widget, this.history);

  @override
  void paint(Canvas canvas, Size size) {
    final color = colorFromHex(widget.primaryColor);
    final v = widget.scaledValue;

    _drawBackground(canvas, size, widget);

    _drawText(canvas, 12, 16, widget.label, 10, colorFromHex(widget.textColor).withOpacity(0.6), align: TextAlign.left);

    final barCount = history.isNotEmpty ? history.length : 8;
    final barW = (size.width - 65) / barCount - 4;
    final chartH = size.height - 65;

    for (var i = 0; i < barCount; i++) {
      final value = history.isNotEmpty ? history[i] : 0.5;
      final h = chartH * math.max(0.05, math.min(1, value));
      final x = 45 + i * (barW + 4);
      final y = 35 + chartH - h;

      // Bar glow
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x - 2, y - 2, barW + 4, h + 4), const Radius.circular(4)),
        Paint()
          ..color = color.withOpacity(0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );

      // Bar with gradient
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, barW, h), const Radius.circular(3)),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(x, y),
            Offset(x, y + h),
            [color, color.withOpacity(0.6)],
          ),
      );
    }

    _drawTextWithShadow(canvas, size.width - 12, 16, '${v.toStringAsFixed(1)}${widget.unit}',
        13, color, weight: FontWeight.bold, alignLeft: false);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// ============ STATIC LABEL PAINTER ============
class StaticLabelPainter extends CustomPainter {
  final ScadaWidget widget;
  StaticLabelPainter(this.widget);

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size, widget);
    final color = colorFromHex(widget.staticFontColor);
    canvas.save();
    if (widget.staticRotation != 0) {
      canvas.translate(size.width / 2, size.height / 2);
      canvas.rotate(widget.staticRotation * math.pi / 180);
      canvas.translate(-size.width / 2, -size.height / 2);
    }
    final tp = TextPainter(
      text: TextSpan(
        text: widget.staticText.isEmpty ? widget.label : widget.staticText,
        style: TextStyle(
          fontSize: widget.staticFontSize,
          fontWeight: widget.staticBold ? FontWeight.bold : FontWeight.normal,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    tp.layout(maxWidth: size.width - 8);
    tp.paint(canvas, Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// ============ STATIC IMAGE PAINTER ============
class StaticImagePainter extends CustomPainter {
  final ScadaWidget widget;
  StaticImagePainter(this.widget);

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size, widget);
    // تصویر از طریق ویجت Flutter بارگذاری می‌شود نه Canvas
    // اینجا placeholder
    final iconPaint = Paint()..color = Colors.white.withOpacity(0.3);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(10, 10, size.width - 20, size.height - 20), const Radius.circular(8)),
      iconPaint..style = PaintingStyle.stroke..strokeWidth = 2,
    );
    _drawText(canvas, size.width / 2, size.height / 2, '🖼️', 24, Colors.white.withOpacity(0.4));
    if (widget.staticImageUrl.isEmpty) {
      _drawText(canvas, size.width / 2, size.height / 2 + 20, 'Set Image URL', 10, Colors.white.withOpacity(0.3));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// ============ STATIC SHAPE PAINTER ============
class StaticShapePainter extends CustomPainter {
  final ScadaWidget widget;
  StaticShapePainter(this.widget);

  @override
  void paint(Canvas canvas, Size size) {
    if (!widget.bgTransparent) _drawBackground(canvas, size, widget);
    final color = colorFromHex(widget.staticShapeColor);
    final borderColor = colorFromHex(widget.staticBorderColor);
    final fillPaint = Paint()..color = color;
    final strokePaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = widget.staticShapeBorder;

    canvas.save();
    if (widget.staticRotation != 0) {
      canvas.translate(size.width / 2, size.height / 2);
      canvas.rotate(widget.staticRotation * math.pi / 180);
      canvas.translate(-size.width / 2, -size.height / 2);
    }

    final m = 4.0;
    switch (widget.staticShapeType) {
      case 'circle':
        final r = math.min(size.width, size.height) / 2 - m;
        if (widget.staticFilled) canvas.drawCircle(Offset(size.width / 2, size.height / 2), r, fillPaint);
        canvas.drawCircle(Offset(size.width / 2, size.height / 2), r, strokePaint);
        break;
      case 'ellipse':
        final rect = Rect.fromLTWH(m, m, size.width - m * 2, size.height - m * 2);
        if (widget.staticFilled) canvas.drawOval(rect, fillPaint);
        canvas.drawOval(rect, strokePaint);
        break;
      case 'diamond':
        final path = Path()
          ..moveTo(size.width / 2, m)
          ..lineTo(size.width - m, size.height / 2)
          ..lineTo(size.width / 2, size.height - m)
          ..lineTo(m, size.height / 2)
          ..close();
        if (widget.staticFilled) canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, strokePaint);
        break;
      default: // rectangle
        final rect = RRect.fromRectAndRadius(Rect.fromLTWH(m, m, size.width - m * 2, size.height - m * 2), const Radius.circular(4));
        if (widget.staticFilled) canvas.drawRRect(rect, fillPaint);
        canvas.drawRRect(rect, strokePaint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// ============ STATIC PIPE PAINTER ============
class StaticPipePainter extends CustomPainter {
  final ScadaWidget widget;
  StaticPipePainter(this.widget);

  @override
  void paint(Canvas canvas, Size size) {
    final color = colorFromHex(widget.staticPipeColor);
    final w = widget.staticPipeWidth;
    final highlight = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final pipePaint = Paint()..color = color..strokeWidth = w..strokeCap = StrokeCap.round;
    final pipeEdge = Paint()..color = color.withOpacity(0.5)..strokeWidth = w + 4..strokeCap = StrokeCap.round;

    final cx = size.width / 2, cy = size.height / 2;

    switch (widget.staticPipeDirection) {
      case 'vertical':
        canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), pipeEdge);
        canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), pipePaint);
        canvas.drawLine(Offset(cx - w / 3, 2), Offset(cx - w / 3, size.height - 2), highlight);
        break;
      case 'elbow_right':
        canvas.drawLine(Offset(0, cy), Offset(cx, cy), pipeEdge);
        canvas.drawLine(Offset(cx, cy), Offset(cx, size.height), pipeEdge);
        canvas.drawLine(Offset(0, cy), Offset(cx, cy), pipePaint);
        canvas.drawLine(Offset(cx, cy), Offset(cx, size.height), pipePaint);
        break;
      case 'elbow_left':
        canvas.drawLine(Offset(cx, 0), Offset(cx, cy), pipeEdge);
        canvas.drawLine(Offset(cx, cy), Offset(size.width, cy), pipeEdge);
        canvas.drawLine(Offset(cx, 0), Offset(cx, cy), pipePaint);
        canvas.drawLine(Offset(cx, cy), Offset(size.width, cy), pipePaint);
        break;
      case 'tee_right':
        canvas.drawLine(Offset(0, cy), Offset(size.width, cy), pipeEdge);
        canvas.drawLine(Offset(cx, cy), Offset(cx, size.height), pipeEdge);
        canvas.drawLine(Offset(0, cy), Offset(size.width, cy), pipePaint);
        canvas.drawLine(Offset(cx, cy), Offset(cx, size.height), pipePaint);
        break;
      case 'tee_down':
        canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), pipeEdge);
        canvas.drawLine(Offset(cx, cy), Offset(size.width, cy), pipeEdge);
        canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), pipePaint);
        canvas.drawLine(Offset(cx, cy), Offset(size.width, cy), pipePaint);
        break;
      case 'cross':
        canvas.drawLine(Offset(0, cy), Offset(size.width, cy), pipeEdge);
        canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), pipeEdge);
        canvas.drawLine(Offset(0, cy), Offset(size.width, cy), pipePaint);
        canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), pipePaint);
        break;
      default: // horizontal
        canvas.drawLine(Offset(0, cy), Offset(size.width, cy), pipeEdge);
        canvas.drawLine(Offset(0, cy), Offset(size.width, cy), pipePaint);
        canvas.drawLine(Offset(2, cy - w / 3), Offset(size.width - 2, cy - w / 3), highlight);
    }
    // Flanges at ends
    canvas.drawCircle(Offset(0, cy), w / 2 + 2, Paint()..color = color.withOpacity(0.6));
    canvas.drawCircle(Offset(size.width, cy), w / 2 + 2, Paint()..color = color.withOpacity(0.6));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// ============ STATIC PANEL PAINTER ============
class StaticPanelPainter extends CustomPainter {
  final ScadaWidget widget;
  StaticPanelPainter(this.widget);

  @override
  void paint(Canvas canvas, Size size) {
    final borderColor = colorFromHex(widget.staticBorderColor);
    final titleBg = colorFromHex(widget.staticShapeColor);

    // Panel border
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 12, size.width, size.height - 12), const Radius.circular(8)),
      Paint()..color = borderColor..style = PaintingStyle.stroke..strokeWidth = 2,
    );
    // Title background
    final titleW = widget.staticPanelTitle.length * 8.0 + 20;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(12, 2, titleW, 20), const Radius.circular(4)),
      Paint()..color = titleBg,
    );
    _drawText(canvas, 12 + titleW / 2, 12, widget.staticPanelTitle, 11,
        Colors.white, weight: FontWeight.bold);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// ============ STATIC ICON PAINTER ============
class StaticIconPainter extends CustomPainter {
  final ScadaWidget widget;
  StaticIconPainter(this.widget);

  static const Map<String, String> icons = {
    'star': '⭐', 'warning': '⚠️', 'check': '✅', 'cross': '❌',
    'fire': '🔥', 'water': '💧', 'bolt': '⚡', 'gear': '⚙️',
    'tank': '🛢️', 'pipe': '🔗', 'valve': '🔧', 'pump': '💨',
    'thermometer': '🌡️', 'pressure': '⏲️', 'alert': '🚨', 'power': '🔋',
    'signal': '📡', 'lock': '🔒', 'unlock': '🔓', 'eye': '👁️',
    'home': '🏠', 'factory': '🏭', 'tool': '🛠️', 'nuclear': '☢️',
  };

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size, widget);
    canvas.save();
    if (widget.staticRotation != 0) {
      canvas.translate(size.width / 2, size.height / 2);
      canvas.rotate(widget.staticRotation * math.pi / 180);
      canvas.translate(-size.width / 2, -size.height / 2);
    }
    final iconText = icons[widget.staticIconName] ?? '⭐';
    _drawText(canvas, size.width / 2, size.height / 2,
        iconText, math.min(size.width, size.height) * 0.6, Colors.white);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// ============ STATIC LINE PAINTER ============
class StaticLinePainter extends CustomPainter {
  final ScadaWidget widget;
  StaticLinePainter(this.widget);

  @override
  void paint(Canvas canvas, Size size) {
    final color = colorFromHex(widget.staticShapeColor);
    final w = widget.staticShapeBorder;
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2),
      Paint()..color = color..strokeWidth = w..strokeCap = StrokeCap.round);
    // Glow
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2),
      Paint()..color = color.withOpacity(0.3)..strokeWidth = w + 4..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// ============ STATIC ARROW PAINTER ============
class StaticArrowPainter extends CustomPainter {
  final ScadaWidget widget;
  StaticArrowPainter(this.widget);

  @override
  void paint(Canvas canvas, Size size) {
    final color = colorFromHex(widget.staticShapeColor);
    final cx = size.width / 2, cy = size.height / 2;
    final aw = size.width * 0.35;

    canvas.save();
    canvas.translate(cx, cy);
    switch (widget.staticArrowDir) {
      case 'left': canvas.rotate(math.pi); break;
      case 'up': canvas.rotate(-math.pi / 2); break;
      case 'down': canvas.rotate(math.pi / 2); break;
      default: break; // right
    }

    // Arrow body
    final bodyPath = Path()
      ..moveTo(-aw, -6)
      ..lineTo(aw - 12, -6)
      ..lineTo(aw - 12, -14)
      ..lineTo(aw, 0)
      ..lineTo(aw - 12, 14)
      ..lineTo(aw - 12, 6)
      ..lineTo(-aw, 6)
      ..close();

    // Glow
    canvas.drawPath(bodyPath, Paint()
      ..color = color.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    // Fill
    canvas.drawPath(bodyPath, Paint()..color = color);
    // Highlight
    canvas.drawPath(bodyPath, Paint()..color = Colors.white.withOpacity(0.1)..style = PaintingStyle.stroke..strokeWidth = 1);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// ============ CALCULATED WIDGET PAINTER ============
class CalculatedPainter extends CustomPainter {
  final ScadaWidget widget;
  final double blinkOpacity;
  CalculatedPainter(this.widget, {this.blinkOpacity = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size, widget);
    final v = widget.scaledValue;
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Calculated badge
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(4, 4, 18, 14), const Radius.circular(3)),
      Paint()..color = Colors.purple.withOpacity(0.3),
    );
    _drawText(canvas, 13, 11, 'fx', 8, Colors.purple, weight: FontWeight.bold);

    if (widget.calcIsDigital) {
      // ===== حالت دیجیتال =====
      final isOn = v != 0;
      final stateLabel = isOn ? widget.calcTrueLabel : widget.calcFalseLabel;
      final stateColor = colorFromHex(isOn ? widget.calcTrueColor : widget.calcFalseColor);
      final opacity = (isOn && widget.calcBlinkOnTrue) ? blinkOpacity : 1.0;

      final displayAs = widget.calcDisplayAs;

      if (displayAs == 'led') {
        // LED style
        final r = math.min(cx, cy - 10) * 0.4;
        // Glow
        if (isOn) {
          canvas.drawCircle(Offset(cx, cy - 4), r + 12,
            Paint()..color = stateColor.withOpacity(0.3 * opacity)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
        }
        // Bezel
        canvas.drawCircle(Offset(cx, cy - 4), r + 4,
          Paint()..shader = ui.Gradient.linear(Offset(cx - r, cy - r - 4), Offset(cx + r, cy + r - 4),
            [const Color(0xFF4A5060), const Color(0xFF2A3040)]));
        // LED body
        canvas.drawCircle(Offset(cx, cy - 4), r,
          Paint()..shader = ui.Gradient.radial(Offset(cx - r * 0.3, cy - r * 0.3 - 4), r * 1.5,
            isOn ? [Colors.white.withOpacity(0.7 * opacity), stateColor.withOpacity(opacity), stateColor.withOpacity(0.5 * opacity)]
                 : [stateColor.withOpacity(0.3), stateColor.withOpacity(0.1), stateColor.withOpacity(0.05)],
            [0.0, 0.4, 1.0]));
        if (isOn) canvas.drawCircle(Offset(cx - r * 0.25, cy - r * 0.25 - 4), r * 0.2, Paint()..color = Colors.white.withOpacity(0.5 * opacity));

      } else if (displayAs == 'switch') {
        // Switch style
        final trackW = math.min(size.width * 0.5, 48.0);
        final trackH = 24.0;
        final trackX = cx - trackW / 2;
        final trackY = cy - trackH / 2 - 4;
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(trackX, trackY, trackW, trackH), Radius.circular(trackH / 2)),
          Paint()..color = stateColor.withOpacity(0.8 * opacity));
        final thumbX = isOn ? trackX + trackW - trackH / 2 : trackX + trackH / 2;
        canvas.drawCircle(Offset(thumbX, trackY + trackH / 2), trackH / 2 - 3,
          Paint()..shader = ui.Gradient.radial(Offset(thumbX - 2, trackY + trackH / 2 - 2), trackH / 2,
            [Colors.white, const Color(0xFFE0E0E0), const Color(0xFFB0B0B0)]));

      } else {
        // Status / Default style - دایره بزرگ با لیبل
        final r = math.min(cx, cy - 10) * 0.35;
        canvas.drawCircle(Offset(cx, cy - 4), r + 6,
          Paint()..shader = ui.Gradient.radial(Offset(cx, cy - 4), r + 8,
            [const Color(0xFF4A5060), const Color(0xFF2A3040)]));
        if (isOn) {
          canvas.drawCircle(Offset(cx, cy - 4), r + 10,
            Paint()..color = stateColor.withOpacity(0.25 * opacity)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
        }
        canvas.drawCircle(Offset(cx, cy - 4), r,
          Paint()..shader = ui.Gradient.radial(Offset(cx - r * 0.3, cy - r * 0.3 - 4), r * 1.4,
            [Colors.white.withOpacity(0.4 * opacity), stateColor.withOpacity(opacity), stateColor.withOpacity(0.6 * opacity)],
            [0.0, 0.4, 1.0]));
      }

      // State label
      _drawText(canvas, cx, cy + (displayAs == 'led' ? math.min(cx, cy - 10) * 0.4 + 14 : 22), stateLabel,
        12, stateColor.withOpacity(opacity), weight: FontWeight.bold);

      // Timer
      if (widget.calcActiveSeconds > 0 && isOn) {
        final mins = (widget.calcActiveSeconds / 60).floor();
        final secs = (widget.calcActiveSeconds % 60).floor();
        _drawText(canvas, cx, size.height - 22, '⏱ ${mins}m ${secs}s',
          8, Colors.white.withOpacity(0.4));
      }
    } else {
      // ===== حالت آنالوگ =====
      final alarmColor = widget.isInAlarm ? colorFromHex(widget.alarm.alarmColor) : null;
      final color = alarmColor ?? colorFromHex(widget.primaryColor);

      // Value
      _drawTextWithGlow(canvas, cx, cy - 2, v.toStringAsFixed(2),
          math.min(size.height * 0.35, 28), color, weight: FontWeight.bold, font: 'monospace');

      // Unit
      if (widget.unit.isNotEmpty) {
        _drawText(canvas, cx, cy + 18, widget.unit, 11, colorFromHex(widget.textColor).withOpacity(0.6));
      }
    }

    // Formula preview
    if (widget.calcFormula.isNotEmpty) {
      final short = widget.calcFormula.length > 25 ? '${widget.calcFormula.substring(0, 22)}...' : widget.calcFormula;
      _drawText(canvas, cx, size.height - 22, short, 7, Colors.purple.withOpacity(0.4));
    }

    // Label
    _drawText(canvas, cx, size.height - 8, widget.label, 9, colorFromHex(widget.textColor).withOpacity(0.7));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// ============ TREND CHART PAINTER (mini تاریخچه) ============
class TrendChartPainter extends CustomPainter {
  final ScadaWidget widget;
  final List<double> history;
  TrendChartPainter(this.widget, this.history);

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size, widget);
    final color = colorFromHex(widget.primaryColor);
    final cx = size.width / 2;

    // Title
    _drawText(canvas, 10, 14, widget.label, 9, colorFromHex(widget.textColor).withOpacity(0.6), align: TextAlign.left);

    if (history.length < 2) {
      _drawText(canvas, cx, size.height / 2, 'Collecting...', 11, Colors.white38);
      return;
    }

    final pad = EdgeInsets.fromLTRB(35, 25, 10, 25);
    final cw = size.width - pad.left - pad.right;
    final ch = size.height - pad.top - pad.bottom;
    final mn = history.reduce(math.min);
    final mx = history.reduce(math.max);
    final range = math.max(mx - mn, 0.1);

    // Grid
    for (int i = 0; i <= 4; i++) {
      final y = pad.top + ch * i / 4;
      canvas.drawLine(Offset(pad.left, y), Offset(size.width - pad.right, y),
        Paint()..color = Colors.white.withOpacity(0.06));
      final v = mx - range * i / 4;
      _drawText(canvas, pad.left - 4, y + 3, v.toStringAsFixed(0), 7, Colors.white.withOpacity(0.3), align: TextAlign.right);
    }

    // Line + fill
    final path = Path();
    final fillPath = Path();
    for (int i = 0; i < history.length; i++) {
      final x = pad.left + cw * i / (history.length - 1);
      final y = pad.top + ch * (1 - (history[i] - mn) / range);
      if (i == 0) { path.moveTo(x, y); fillPath.moveTo(x, pad.top + ch); fillPath.lineTo(x, y); }
      else { path.lineTo(x, y); fillPath.lineTo(x, y); }
    }
    fillPath.lineTo(pad.left + cw, pad.top + ch);
    fillPath.close();

    canvas.drawPath(fillPath, Paint()
      ..shader = ui.Gradient.linear(Offset(0, pad.top), Offset(0, pad.top + ch),
        [color.withOpacity(0.2), color.withOpacity(0.0)]));
    canvas.drawPath(path, Paint()..color = color.withOpacity(0.3)..strokeWidth = 3..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawPath(path, Paint()..color = color..strokeWidth = 1.5..style = PaintingStyle.stroke);

    // Current value
    final last = history.last;
    _drawText(canvas, size.width - 10, 14, '${last.toStringAsFixed(1)}${widget.unit}', 11, color,
      align: TextAlign.right, weight: FontWeight.bold);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// ============ SPC CHART PAINTER (نمودار کنترل کیفیت آماری) ============
class SpcChartPainter extends CustomPainter {
  final ScadaWidget widget;
  final List<double> history;
  SpcChartPainter(this.widget, this.history);

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size, widget);
    final color = colorFromHex(widget.primaryColor);
    final cx = size.width / 2;

    // Title + SPC badge
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(4, 4, 26, 14), const Radius.circular(3)),
      Paint()..color = Colors.teal.withOpacity(0.3));
    _drawText(canvas, 17, 11, 'SPC', 7, Colors.teal, weight: FontWeight.bold);
    _drawText(canvas, 35, 14, widget.label, 9, colorFromHex(widget.textColor).withOpacity(0.6), align: TextAlign.left);

    if (history.length < 2) {
      _drawText(canvas, cx, size.height / 2, 'Collecting...', 11, Colors.white38);
      return;
    }

    final ucl = widget.spcUcl;
    final lcl = widget.spcLcl;
    final target = widget.spcTarget;
    final allVals = [...history, ucl, lcl, target];
    final mn = allVals.reduce(math.min) - 2;
    final mx = allVals.reduce(math.max) + 2;
    final range = math.max(mx - mn, 0.1);

    final pad = EdgeInsets.fromLTRB(40, 25, 10, 25);
    final cw = size.width - pad.left - pad.right;
    final ch = size.height - pad.top - pad.bottom;

    double toY(double v) => pad.top + ch * (1 - (v - mn) / range);

    // UCL line (red dashed)
    final uclY = toY(ucl);
    _drawDashedLine(canvas, pad.left, uclY, size.width - pad.right, uclY,
      Paint()..color = Colors.red.withOpacity(0.7)..strokeWidth = 1);
    _drawText(canvas, pad.left - 4, uclY + 3, 'UCL', 7, Colors.red.withOpacity(0.7), align: TextAlign.right);

    // LCL line (red dashed)
    final lclY = toY(lcl);
    _drawDashedLine(canvas, pad.left, lclY, size.width - pad.right, lclY,
      Paint()..color = Colors.red.withOpacity(0.7)..strokeWidth = 1);
    _drawText(canvas, pad.left - 4, lclY + 3, 'LCL', 7, Colors.red.withOpacity(0.7), align: TextAlign.right);

    // Target line (green)
    final tgtY = toY(target);
    canvas.drawLine(Offset(pad.left, tgtY), Offset(size.width - pad.right, tgtY),
      Paint()..color = Colors.green.withOpacity(0.5)..strokeWidth = 1);
    _drawText(canvas, pad.left - 4, tgtY + 3, 'CL', 7, Colors.green.withOpacity(0.6), align: TextAlign.right);

    // Zone fills (±1σ, ±2σ)
    final sigma = (ucl - lcl) / 6;
    // Zone C (green) ±1σ
    canvas.drawRect(Rect.fromLTRB(pad.left, toY(target + sigma), size.width - pad.right, toY(target - sigma)),
      Paint()..color = Colors.green.withOpacity(0.05));
    // Zone B (yellow) ±2σ
    canvas.drawRect(Rect.fromLTRB(pad.left, toY(target + 2 * sigma), size.width - pad.right, toY(target + sigma)),
      Paint()..color = Colors.yellow.withOpacity(0.03));
    canvas.drawRect(Rect.fromLTRB(pad.left, toY(target - sigma), size.width - pad.right, toY(target - 2 * sigma)),
      Paint()..color = Colors.yellow.withOpacity(0.03));

    // Data points + line
    final path = Path();
    for (int i = 0; i < history.length; i++) {
      final x = pad.left + cw * i / (history.length - 1);
      final y = toY(history[i]);
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);

      // Point color: red if out of control
      final outOfControl = history[i] > ucl || history[i] < lcl;
      canvas.drawCircle(Offset(x, y), outOfControl ? 4 : 2.5,
        Paint()..color = outOfControl ? Colors.red : color);
      if (outOfControl) {
        canvas.drawCircle(Offset(x, y), 8,
          Paint()..color = Colors.red.withOpacity(0.2)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      }
    }
    canvas.drawPath(path, Paint()..color = color..strokeWidth = 1.5..style = PaintingStyle.stroke);

    // Current value
    final last = history.last;
    final lastOoc = last > ucl || last < lcl;
    _drawText(canvas, size.width - 10, 14, '${last.toStringAsFixed(1)} ${widget.unit}', 11,
      lastOoc ? Colors.red : color, align: TextAlign.right, weight: FontWeight.bold);
  }

  void _drawDashedLine(Canvas canvas, double x1, double y1, double x2, double y2, Paint paint) {
    const dashWidth = 5.0;
    const dashSpace = 3.0;
    final dx = x2 - x1;
    final totalLength = dx.abs();
    double drawn = 0;
    while (drawn < totalLength) {
      final start = x1 + drawn * dx.sign;
      final end = x1 + math.min(drawn + dashWidth, totalLength) * dx.sign;
      canvas.drawLine(Offset(start, y1), Offset(end, y2), paint);
      drawn += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// ============ DATA TABLE PAINTER ============
class DataTablePainter extends CustomPainter {
  final ScadaWidget widget;
  DataTablePainter(this.widget);

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size, widget);

    final rows = widget.tableRows;
    final cols = widget.tableCols;
    final cells = widget.tableCells;
    final borderColor = colorFromHex(widget.tableBorderColor);
    final headerColor = colorFromHex(widget.tableHeaderColor);
    final showHeader = widget.tableShowHeader;
    final alarmColoring = widget.tableAlarmColoring;
    final showQualityIcon = widget.tableShowQualityIcon;

    final pad = 4.0;
    final tableW = size.width - pad * 2;
    final tableH = size.height - pad * 2;
    final cellW = tableW / cols;
    final cellH = tableH / rows;
    final tx = pad;
    final ty = pad;

    // Track merged areas that should be skipped
    final skip = <String>{};

    // Base header row background
    if (showHeader) {
      canvas.drawRect(Rect.fromLTWH(tx, ty, tableW, cellH), Paint()..color = headerColor);
    }

    // Draw merged cell backgrounds and content first
    for (final rawCell in cells) {
      final cell = Map<String, dynamic>.from(rawCell);
      final r = (cell['row'] ?? 0) as int;
      final c = (cell['col'] ?? 0) as int;
      final rowSpan = ((cell['rowSpan'] ?? 1) as num).toInt().clamp(1, rows);
      final colSpan = ((cell['colSpan'] ?? 1) as num).toInt().clamp(1, cols);
      final isHeader = r == 0 && showHeader;
      final cellRect = Rect.fromLTWH(tx + c * cellW, ty + r * cellH, cellW * colSpan, cellH * rowSpan);

      // Mark covered cells to skip later
      for (int rr = r; rr < r + rowSpan; rr++) {
        for (int cc = c; cc < c + colSpan; cc++) {
          if (!(rr == r && cc == c)) skip.add('$rr:$cc');
        }
      }

      // Alarm-based fill
      if (!isHeader && alarmColoring && cell['alarmColor'] != null) {
        canvas.drawRect(cellRect, Paint()..color = colorFromHex(cell['alarmColor']).withOpacity(0.12));
      }

      final cellCx = cellRect.left + cellRect.width / 2;
      final cellCy = cellRect.top + cellRect.height / 2;
      final tagName = cell['tagName']?.toString() ?? '';
      final tagDesc = cell['tagDesc']?.toString() ?? '';
      final value = cell['value'];
      final unit = cell['unit']?.toString() ?? '';
      final quality = cell['quality']?.toString() ?? 'unknown';

      if (isHeader) {
        _drawText(canvas, cellCx, cellCy, tagName.isEmpty ? 'Col ${c + 1}' : tagName, 10, Colors.white, weight: FontWeight.bold);
      } else {
        if (value != null) {
          final valStr = value is double ? value.toStringAsFixed(1) : value.toString();
          _drawText(canvas, cellCx, cellCy - 6, '$valStr $unit', 11, colorFromHex(widget.primaryColor), weight: FontWeight.bold);
          _drawText(canvas, cellCx, cellCy + 8, tagName, 7, Colors.white.withOpacity(0.4));
        } else {
          _drawText(canvas, cellCx, cellCy - 4, tagName, 9, Colors.white.withOpacity(0.7));
          if (tagDesc.isNotEmpty) {
            _drawText(canvas, cellCx, cellCy + 8, tagDesc, 7, Colors.white.withOpacity(0.3));
          }
        }

        // Quality icon
        if (showQualityIcon) {
          Color qColor;
          switch (quality) {
            case 'good': qColor = Colors.green; break;
            case 'bad': qColor = Colors.red; break;
            case 'uncertain': qColor = Colors.amber; break;
            default: qColor = Colors.grey;
          }
          canvas.drawCircle(Offset(cellRect.right - 8, cellRect.top + 8), 3, Paint()..color = qColor);
        }
      }
    }

    // Grid lines with merged-cell awareness
    final linePaint = Paint()..color = borderColor..strokeWidth = 1;
    for (int r = 0; r <= rows; r++) {
      final y = ty + r * cellH;
      canvas.drawLine(Offset(tx, y), Offset(tx + tableW, y), linePaint);
    }
    for (int c = 0; c <= cols; c++) {
      final x = tx + c * cellW;
      canvas.drawLine(Offset(x, ty), Offset(x, ty + tableH), linePaint);
    }

    // Redraw merged cells over grid to hide internal lines, then draw content again
    for (final rawCell in cells) {
      final cell = Map<String, dynamic>.from(rawCell);
      final r = (cell['row'] ?? 0) as int;
      final c = (cell['col'] ?? 0) as int;
      final rowSpan = ((cell['rowSpan'] ?? 1) as num).toInt().clamp(1, rows);
      final colSpan = ((cell['colSpan'] ?? 1) as num).toInt().clamp(1, cols);
      if (rowSpan <= 1 && colSpan <= 1) continue;
      final isHeader = r == 0 && showHeader;
      final cellRect = Rect.fromLTWH(tx + c * cellW, ty + r * cellH, cellW * colSpan, cellH * rowSpan);
      final cellCx = cellRect.left + cellRect.width / 2;
      final cellCy = cellRect.top + cellRect.height / 2;
      final tagName = cell['tagName']?.toString() ?? '';
      final tagDesc = cell['tagDesc']?.toString() ?? '';
      final value = cell['value'];
      final unit = cell['unit']?.toString() ?? '';
      final quality = cell['quality']?.toString() ?? 'unknown';

      Color fillColor;
      if (isHeader) fillColor = headerColor;
      else if (alarmColoring && cell['alarmColor'] != null) fillColor = colorFromHex(cell['alarmColor']).withOpacity(0.12);
      else fillColor = widget.bgTransparent ? const Color(0x00000000) : colorFromHex(widget.backgroundColor).withOpacity(widget.bgOpacity);

      canvas.drawRect(cellRect, Paint()..color = fillColor);
      canvas.drawRect(cellRect, Paint()..color = borderColor..style = PaintingStyle.stroke..strokeWidth = 1);

      if (isHeader) {
        _drawText(canvas, cellCx, cellCy, tagName.isEmpty ? 'Col ${c + 1}' : tagName, 10, Colors.white, weight: FontWeight.bold);
      } else {
        if (value != null) {
          final valStr = value is double ? value.toStringAsFixed(1) : value.toString();
          _drawText(canvas, cellCx, cellCy - 6, '$valStr $unit', 11, colorFromHex(widget.primaryColor), weight: FontWeight.bold);
          _drawText(canvas, cellCx, cellCy + 8, tagName, 7, Colors.white.withOpacity(0.4));
        } else {
          _drawText(canvas, cellCx, cellCy - 4, tagName, 9, Colors.white.withOpacity(0.7));
          if (tagDesc.isNotEmpty) _drawText(canvas, cellCx, cellCy + 8, tagDesc, 7, Colors.white.withOpacity(0.3));
        }
        if (showQualityIcon) {
          Color qColor;
          switch (quality) {
            case 'good': qColor = Colors.green; break;
            case 'bad': qColor = Colors.red; break;
            case 'uncertain': qColor = Colors.amber; break;
            default: qColor = Colors.grey;
          }
          canvas.drawCircle(Offset(cellRect.right - 8, cellRect.top + 8), 3, Paint()..color = qColor);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// ============ ANIMATED PATH PAINTER (جریان مایع/گاز) ============
class AnimatedPathPainter extends CustomPainter {
  final ScadaWidget widget;
  final double animPhase; // 0.0 - 1.0 برای انیمیشن

  AnimatedPathPainter(this.widget, this.animPhase);

  @override
  void paint(Canvas canvas, Size size) {
    final flowColor = colorFromHex(widget.pathFlowColor);
    final pw = widget.pathWidth;
    final flowing = widget.pathFlowing && (widget.boolValue || widget.value > 0);
    final dir = widget.pathDirection;
    final cx = size.width / 2;
    final cy = size.height / 2;

    final branches = _buildBranches(size, dir, cx, cy);

    final pipePaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, cy - pw / 2),
        Offset(0, cy + pw / 2),
        [const Color(0xFF5A6A7A), const Color(0xFF3A4A5A), const Color(0xFF2A3A4A)],
      )
      ..strokeWidth = pw + 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final innerPaint = Paint()
      ..color = const Color(0xFF1A2A3A)
      ..strokeWidth = pw
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final pts in branches) {
      final pipePath = Path();
      for (int i = 0; i < pts.length; i++) {
        if (i == 0) pipePath.moveTo(pts[i].dx, pts[i].dy);
        else pipePath.lineTo(pts[i].dx, pts[i].dy);
      }
      canvas.drawPath(pipePath, pipePaint);
      canvas.drawPath(pipePath, innerPaint);
      canvas.drawPath(pipePath, highlightPaint);

      if (flowing) {
        final totalLen = _pathLength(pts);
        final particleCount = math.max(1, (totalLen / 20).floor());
        final lanes = widget.pathLanes.clamp(1, 6);
        final particleSize = math.max(1.2, pw * 0.22);

        for (int lane = 0; lane < lanes; lane++) {
          final laneShift = lanes == 1 ? 0.0 : ((lane / (lanes - 1)) - 0.5) * (pw * 0.45);
          for (int i = 0; i < particleCount; i++) {
            final base = ((i / particleCount) + animPhase * widget.pathSpeed) % 1.0;
            final t = widget.pathReverse ? (1.0 - base) : base;
            final pos = _pointAlongPath(pts, t, totalLen);
            final opacity = 0.25 + 0.75 * math.sin(base * math.pi);
            final shifted = _shiftPointForDirection(pos, pts, laneShift);
            canvas.drawCircle(shifted, particleSize + 2,
              Paint()..color = flowColor.withOpacity(0.18 * opacity)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
            canvas.drawCircle(shifted, particleSize,
              Paint()..color = flowColor.withOpacity(opacity));
          }
        }

        canvas.drawPath(pipePath, Paint()
          ..color = flowColor.withOpacity(0.12)
          ..strokeWidth = pw - 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      }

      // Flanges for each branch ends
      for (final p in [pts.first, pts.last]) {
        canvas.drawCircle(p, pw / 2 + 3,
          Paint()..shader = ui.Gradient.radial(p, pw / 2 + 4,
            [const Color(0xFF6A7A8A), const Color(0xFF3A4A5A)]));
      }
    }

    // Display text on path
    final displayText = widget.pathDisplayText.isNotEmpty
        ? widget.pathDisplayText
        : (widget.unit.isNotEmpty ? '${widget.value.toStringAsFixed(1)} ${widget.unit}' : widget.label);
    if (displayText.isNotEmpty) {
      final textW = math.min(size.width * 0.5, 140.0);
      final textH = 20.0;
      final tx = (size.width - textW) / 2;
      final ty = math.max(2.0, cy - textH / 2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(tx, ty, textW, textH), const Radius.circular(8)),
        Paint()..color = Colors.black.withOpacity(0.35),
      );
      _drawText(canvas, tx + textW / 2, ty + textH / 2 + 1, displayText, 9, Colors.white, weight: FontWeight.w600);
    }
  }

  List<List<Offset>> _buildBranches(Size size, String dir, double cx, double cy) {
    switch (dir) {
      case 'vertical':
        return [[Offset(cx, 0), Offset(cx, size.height)]];
      case 'elbow_right':
        return [[Offset(0, cy), Offset(cx, cy), Offset(cx, size.height)]];
      case 'elbow_left':
        return [[Offset(cx, 0), Offset(cx, cy), Offset(size.width, cy)]];
      case 'elbow_down':
        return [[Offset(cx, 0), Offset(cx, cy), Offset(size.width, cy)]];
      case 'elbow_up':
        return [[Offset(0, cy), Offset(cx, cy), Offset(cx, 0)]];
      case 'tee_right':
        return [
          [Offset(0, cy), Offset(size.width, cy)],
          [Offset(cx, cy), Offset(cx, size.height)],
        ];
      case 'tee_down':
        return [
          [Offset(cx, 0), Offset(cx, size.height)],
          [Offset(cx, cy), Offset(size.width, cy)],
        ];
      case 'cross':
        return [
          [Offset(0, cy), Offset(size.width, cy)],
          [Offset(cx, 0), Offset(cx, size.height)],
        ];
      default:
        return [[Offset(0, cy), Offset(size.width, cy)]];
    }
  }

  double _pathLength(List<Offset> pts) {
    double len = 0;
    for (int i = 1; i < pts.length; i++) {
      len += (pts[i] - pts[i - 1]).distance;
    }
    return len;
  }

  Offset _pointAlongPath(List<Offset> pts, double t, double totalLen) {
    double target = t * totalLen;
    double accumulated = 0;
    for (int i = 1; i < pts.length; i++) {
      final segLen = (pts[i] - pts[i - 1]).distance;
      if (accumulated + segLen >= target) {
        final segT = (target - accumulated) / segLen;
        return Offset.lerp(pts[i - 1], pts[i], segT)!;
      }
      accumulated += segLen;
    }
    return pts.last;
  }

  Offset _shiftPointForDirection(Offset p, List<Offset> pts, double shift) {
    if (pts.length < 2 || shift == 0) return p;
    final a = pts.first;
    final b = pts.length > 1 ? pts[1] : pts.first;
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    if (dx.abs() >= dy.abs()) {
      return Offset(p.dx, p.dy + shift);
    }
    return Offset(p.dx + shift, p.dy);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// =================== HELPER FUNCTIONS ===================
double _clamp(double v) => v.clamp(0.0, 1.0);
double _degToRad(double deg) => deg * math.pi / 180;

/// رسم پس‌زمینه مشترک با پشتیبانی از شفافیت و بدون فریم
void _drawBackground(Canvas canvas, Size size, ScadaWidget widget) {
  final bgColor = colorFromHex(widget.backgroundColor);
  final radius = widget.frameless ? 0.0 : 12.0;

  if (widget.bgTransparent) return; // بدون پس‌زمینه

  final opacity = widget.bgOpacity.clamp(0.0, 1.0);
  if (opacity <= 0) return;

  final rect = RRect.fromRectAndRadius(
    Rect.fromLTWH(0, 0, size.width, size.height),
    Radius.circular(radius),
  );

  // سایه (فقط در حالت فریم‌دار)
  if (!widget.frameless && opacity > 0.3) {
    canvas.drawRRect(
      rect.shift(const Offset(0, 4)),
      Paint()
        ..color = Colors.black.withOpacity(0.3 * opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }

  // پس‌زمینه با گرادیانت
  final bgPaint = Paint()
    ..shader = ui.Gradient.linear(
      Offset(0, 0),
      Offset(0, size.height),
      [
        bgColor.withOpacity(opacity),
        bgColor.withOpacity(opacity * 0.7),
      ],
    );
  canvas.drawRRect(rect, bgPaint);

  // خط نازک داخلی (فقط در حالت فریم‌دار)
  if (!widget.frameless && opacity > 0.5) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(2, 2, size.width - 4, size.height - 4),
        Radius.circular(math.max(0, radius - 2)),
      ),
      Paint()
        ..color = Colors.white.withOpacity(0.05 * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }
}

void _drawText(Canvas canvas, double x, double y, String text, double fontSize, Color color,
    {TextAlign align = TextAlign.center, FontWeight weight = FontWeight.normal, String font = 'sans'}) {
  final textPainter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: weight,
        color: color,
        fontFamily: font == 'monospace' ? 'monospace' : null,
      ),
    ),
    textDirection: TextDirection.ltr,
    textAlign: align,
  );
  textPainter.layout();

  double dx = x;
  if (align == TextAlign.center) {
    dx = x - textPainter.width / 2;
  } else if (align == TextAlign.right) {
    dx = x - textPainter.width;
  }
  textPainter.paint(canvas, Offset(dx, y - textPainter.height / 2));
}

void _drawTextWithShadow(Canvas canvas, double x, double y, String text, double fontSize, Color color,
    {FontWeight weight = FontWeight.normal, bool alignLeft = false}) {
  // Shadow
  final shadowPainter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: weight,
        color: Colors.black.withOpacity(0.5),
      ),
    ),
    textDirection: TextDirection.ltr,
  );
  shadowPainter.layout();
  final dx = alignLeft ? x : x - shadowPainter.width / 2;
  shadowPainter.paint(canvas, Offset(dx + 1, y - shadowPainter.height / 2 + 1));

  // Main text
  final textPainter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: weight,
        color: color,
      ),
    ),
    textDirection: TextDirection.ltr,
  );
  textPainter.layout();
  textPainter.paint(canvas, Offset(dx, y - textPainter.height / 2));
}

void _drawTextWithGlow(Canvas canvas, double x, double y, String text, double fontSize, Color color,
    {FontWeight weight = FontWeight.normal, String font = 'sans'}) {
  // Glow
  final glowPainter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: weight,
        fontFamily: font == 'monospace' ? 'monospace' : null,
        foreground: Paint()
          ..color = color.withOpacity(0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      ),
    ),
    textDirection: TextDirection.ltr,
  );
  glowPainter.layout();
  glowPainter.paint(canvas, Offset(x - glowPainter.width / 2, y - glowPainter.height / 2));

  // Main text
  final textPainter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: weight,
        color: color,
        fontFamily: font == 'monospace' ? 'monospace' : null,
      ),
    ),
    textDirection: TextDirection.ltr,
  );
  textPainter.layout();
  textPainter.paint(canvas, Offset(x - textPainter.width / 2, y - textPainter.height / 2));
}
