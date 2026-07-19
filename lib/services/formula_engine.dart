import 'dart:math' as math;

/// موتور محاسبه فرمول برای ویجت‌های محاسباتی
/// فرمول نمونه: "({TT-101} + {TT-102}) / 2"
/// 
/// عملگرها: + - * / % ^
/// توابع: MIN() MAX() AVG() SUM() ABS() SQRT() POW() LOG()
///         ROUND() FLOOR() CEIL() IF() AND() OR() NOT()
class FormulaEngine {
  /// محاسبه فرمول با مقادیر ورودی
  /// [formula] فرمول متنی
  /// [values] مپ از نام تگ به مقدار عددی
  static double evaluate(String formula, Map<String, double> values) {
    if (formula.trim().isEmpty) return 0;
    
    // جایگزینی تگ‌ها با مقادیر
    String expr = formula;
    values.forEach((tag, value) {
      expr = expr.replaceAll('{$tag}', value.toString());
    });

    // حذف فاصله‌های اضافی
    expr = expr.trim();

    try {
      return _parse(expr);
    } catch (e) {
      return double.nan;
    }
  }

  /// اعتبارسنجی فرمول
  static FormulaValidation validate(String formula, List<String> availableTags) {
    if (formula.trim().isEmpty) {
      return FormulaValidation(valid: false, error: 'Formula is empty');
    }

    // استخراج تگ‌های استفاده شده
    final tagPattern = RegExp(r'\{([^}]+)\}');
    final usedTags = tagPattern.allMatches(formula).map((m) => m.group(1)!).toList();

    // بررسی تگ‌های موجود
    final missingTags = usedTags.where((t) => !availableTags.contains(t)).toList();
    if (missingTags.isNotEmpty) {
      return FormulaValidation(valid: false, error: 'Unknown tags: ${missingTags.join(", ")}', usedTags: usedTags);
    }

    // تست محاسبه با مقادیر صفر
    final testValues = {for (var t in usedTags) t: 50.0};
    try {
      final result = evaluate(formula, testValues);
      if (result.isNaN || result.isInfinite) {
        return FormulaValidation(valid: false, error: 'Formula produces invalid result', usedTags: usedTags);
      }
      return FormulaValidation(valid: true, usedTags: usedTags, testResult: result);
    } catch (e) {
      return FormulaValidation(valid: false, error: 'Syntax error: $e', usedTags: usedTags);
    }
  }

  /// استخراج تگ‌های استفاده شده در فرمول
  static List<String> extractTags(String formula) {
    final tagPattern = RegExp(r'\{([^}]+)\}');
    return tagPattern.allMatches(formula).map((m) => m.group(1)!).toSet().toList();
  }

  // =================== PARSER ===================
  static double _parse(String expr) {
    expr = expr.trim();

    // Handle functions first
    expr = _replaceFunctions(expr);

    // Tokenize and evaluate
    return _evalExpression(expr, 0).value;
  }

  static String _replaceFunctions(String expr) {
    // IF(condition, trueVal, falseVal)
    final ifPattern = RegExp(r'IF\(([^,]+),([^,]+),([^)]+)\)', caseSensitive: false);
    while (ifPattern.hasMatch(expr)) {
      expr = expr.replaceAllMapped(ifPattern, (m) {
        final cond = _parse(m.group(1)!);
        return cond != 0 ? m.group(2)!.trim() : m.group(3)!.trim();
      });
    }

    // MIN(a, b, ...)
    expr = _replaceAggFunc(expr, 'MIN', (vals) => vals.reduce(math.min));
    expr = _replaceAggFunc(expr, 'MAX', (vals) => vals.reduce(math.max));
    expr = _replaceAggFunc(expr, 'AVG', (vals) => vals.reduce((a, b) => a + b) / vals.length);
    expr = _replaceAggFunc(expr, 'SUM', (vals) => vals.reduce((a, b) => a + b));

    // Single arg functions
    expr = _replaceSingleFunc(expr, 'ABS', (v) => v.abs());
    expr = _replaceSingleFunc(expr, 'SQRT', (v) => math.sqrt(v));
    expr = _replaceSingleFunc(expr, 'LOG', (v) => math.log(v));
    expr = _replaceSingleFunc(expr, 'ROUND', (v) => v.roundToDouble());
    expr = _replaceSingleFunc(expr, 'FLOOR', (v) => v.floorToDouble());
    expr = _replaceSingleFunc(expr, 'CEIL', (v) => v.ceilToDouble());
    expr = _replaceSingleFunc(expr, 'NOT', (v) => v == 0 ? 1.0 : 0.0);

    // POW(base, exp)
    final powPattern = RegExp(r'POW\(([^,]+),([^)]+)\)', caseSensitive: false);
    while (powPattern.hasMatch(expr)) {
      expr = expr.replaceAllMapped(powPattern, (m) {
        final base = _parse(m.group(1)!);
        final exp = _parse(m.group(2)!);
        return math.pow(base, exp).toString();
      });
    }

    // XOR
    final xorPattern = RegExp(r'XOR\(([^,]+),([^)]+)\)', caseSensitive: false);
    while (xorPattern.hasMatch(expr)) {
      expr = expr.replaceAllMapped(xorPattern, (m) {
        final a = _parse(m.group(1)!);
        final b = _parse(m.group(2)!);
        return ((a != 0) != (b != 0)) ? '1' : '0';
      });
    }

    // RISING_EDGE / FALLING_EDGE (simplified: just returns 1 if true)
    expr = _replaceSingleFunc(expr, 'BOOL', (v) => v != 0 ? 1.0 : 0.0);

    // MAJORITY(a, b, c) - 2 of 3
    final majPattern = RegExp(r'MAJORITY\(([^,]+),([^,]+),([^)]+)\)', caseSensitive: false);
    while (majPattern.hasMatch(expr)) {
      expr = expr.replaceAllMapped(majPattern, (m) {
        final a = _parse(m.group(1)!) != 0 ? 1 : 0;
        final b = _parse(m.group(2)!) != 0 ? 1 : 0;
        final c = _parse(m.group(3)!) != 0 ? 1 : 0;
        return (a + b + c >= 2) ? '1' : '0';
      });
    }

    // COUNT_TRUE(a, b, c, ...) - تعداد ورودی‌های فعال
    final ctPattern = RegExp(r'COUNT_TRUE\(([^)]+)\)', caseSensitive: false);
    while (ctPattern.hasMatch(expr)) {
      expr = expr.replaceAllMapped(ctPattern, (m) {
        final args = m.group(1)!.split(',').map((s) => _parse(s.trim())).toList();
        return args.where((v) => v != 0).length.toString();
      });
    }

    // LATCH(set, reset) - simplified SR latch
    final latchPattern = RegExp(r'LATCH\(([^,]+),([^)]+)\)', caseSensitive: false);
    while (latchPattern.hasMatch(expr)) {
      expr = expr.replaceAllMapped(latchPattern, (m) {
        final set = _parse(m.group(1)!);
        final reset = _parse(m.group(2)!);
        if (reset != 0) return '0';
        if (set != 0) return '1';
        return '0';
      });
    }

    // AND / OR
    final andPattern = RegExp(r'AND\(([^,]+),([^)]+)\)', caseSensitive: false);
    while (andPattern.hasMatch(expr)) {
      expr = expr.replaceAllMapped(andPattern, (m) {
        final a = _parse(m.group(1)!);
        final b = _parse(m.group(2)!);
        return (a != 0 && b != 0) ? '1' : '0';
      });
    }
    final orPattern = RegExp(r'OR\(([^,]+),([^)]+)\)', caseSensitive: false);
    while (orPattern.hasMatch(expr)) {
      expr = expr.replaceAllMapped(orPattern, (m) {
        final a = _parse(m.group(1)!);
        final b = _parse(m.group(2)!);
        return (a != 0 || b != 0) ? '1' : '0';
      });
    }

    return expr;
  }

  static String _replaceAggFunc(String expr, String name, double Function(List<double>) fn) {
    final pattern = RegExp('$name\\(([^)]+)\\)', caseSensitive: false);
    while (pattern.hasMatch(expr)) {
      expr = expr.replaceAllMapped(pattern, (m) {
        final args = m.group(1)!.split(',').map((s) => _parse(s.trim())).toList();
        return fn(args).toString();
      });
    }
    return expr;
  }

  static String _replaceSingleFunc(String expr, String name, double Function(double) fn) {
    final pattern = RegExp('$name\\(([^)]+)\\)', caseSensitive: false);
    while (pattern.hasMatch(expr)) {
      expr = expr.replaceAllMapped(pattern, (m) {
        final val = _parse(m.group(1)!);
        return fn(val).toString();
      });
    }
    return expr;
  }

  // Simple recursive descent parser for arithmetic
  static _Result _evalExpression(String expr, int pos) {
    var result = _evalTerm(expr, pos);
    
    while (result.pos < expr.length) {
      final ch = expr[result.pos];
      if (ch == '+' || ch == '-') {
        final op = ch;
        final right = _evalTerm(expr, result.pos + 1);
        result = _Result(
          op == '+' ? result.value + right.value : result.value - right.value,
          right.pos,
        );
      } else if (ch == '>' || ch == '<' || ch == '=') {
        String op = ch;
        int nextPos = result.pos + 1;
        if (nextPos < expr.length && expr[nextPos] == '=') {
          op += '=';
          nextPos++;
        }
        final right = _evalTerm(expr, nextPos);
        double cmp;
        switch (op) {
          case '>': cmp = result.value > right.value ? 1.0 : 0.0; break;
          case '<': cmp = result.value < right.value ? 1.0 : 0.0; break;
          case '>=': cmp = result.value >= right.value ? 1.0 : 0.0; break;
          case '<=': cmp = result.value <= right.value ? 1.0 : 0.0; break;
          case '==': cmp = result.value == right.value ? 1.0 : 0.0; break;
          default: cmp = 0;
        }
        result = _Result(cmp, right.pos);
      } else {
        break;
      }
    }
    return result;
  }

  static _Result _evalTerm(String expr, int pos) {
    var result = _evalFactor(expr, pos);

    while (result.pos < expr.length) {
      final ch = expr[result.pos];
      if (ch == '*' || ch == '/' || ch == '%' || ch == '^') {
        final right = _evalFactor(expr, result.pos + 1);
        switch (ch) {
          case '*': result = _Result(result.value * right.value, right.pos); break;
          case '/': result = _Result(right.value != 0 ? result.value / right.value : double.nan, right.pos); break;
          case '%': result = _Result(right.value != 0 ? result.value % right.value : double.nan, right.pos); break;
          case '^': result = _Result(math.pow(result.value, right.value).toDouble(), right.pos); break;
        }
      } else {
        break;
      }
    }
    return result;
  }

  static _Result _evalFactor(String expr, int pos) {
    // Skip whitespace
    while (pos < expr.length && expr[pos] == ' ') {
      pos++;
    }

    if (pos >= expr.length) return _Result(0, pos);

    // Negative
    if (expr[pos] == '-') {
      final r = _evalFactor(expr, pos + 1);
      return _Result(-r.value, r.pos);
    }

    // Parentheses
    if (expr[pos] == '(') {
      final r = _evalExpression(expr, pos + 1);
      int end = r.pos;
      while (end < expr.length && expr[end] == ' ') {
        end++;
      }
      if (end < expr.length && expr[end] == ')') end++;
      return _Result(r.value, end);
    }

    // Number
    int start = pos;
    while (pos < expr.length && (expr[pos].contains(RegExp(r'[0-9.]')))) {
      pos++;
    }
    if (pos > start) {
      return _Result(double.tryParse(expr.substring(start, pos)) ?? 0, pos);
    }

    return _Result(0, pos);
  }
}

class _Result {
  final double value;
  final int pos;
  _Result(this.value, this.pos);
}

class FormulaValidation {
  final bool valid;
  final String? error;
  final List<String> usedTags;
  final double? testResult;

  FormulaValidation({required this.valid, this.error, this.usedTags = const [], this.testResult});
}
