import 'dart:math' as math;
import 'dart:typed_data';

import '_format.dart';

/// Resolves the number surface's formatter without depending on widget state.
String beuiFormatTickerNumber({
  required num value,
  required int decimals,
  required bool locale,
  required String Function(int value)? legacyFormat,
  required String Function(num roundedValue)? formatNumber,
}) {
  if (formatNumber == null && legacyFormat != null) {
    if (!value.isFinite) {
      throw ArgumentError.value(value, 'value', 'must be finite for format');
    }
    return legacyFormat(value.round());
  }

  final places = math.max(0, decimals);
  final factor = math.pow(10.0, places).toDouble();
  final rounded = _sourceRound(value.toDouble() * factor) / factor;
  if (formatNumber != null) return formatNumber(rounded);

  if (places > 100) {
    throw RangeError.range(places, 0, 100, 'decimals');
  }
  if (locale) return _localeString(rounded, places);
  return _sourceFixed(rounded, places);
}

// Math.round differs from Dart round at negative halves and preserves -0.
double _sourceRound(double value) {
  if (!value.isFinite || value == 0) return value;
  final lower = value.floorToDouble();
  final fraction = value - lower;
  final rounded = fraction < 0.5 ? lower : lower + 1;
  return rounded == 0 && value < 0 ? -0.0 : rounded;
}

String _localeString(double value, int places) {
  if (value.isNaN) return 'NaN';
  if (!value.isFinite) return value.isNegative ? '-∞' : '∞';
  // Intl formats the shortest decimal representation, unlike toFixed's exact
  // binary fraction. Keep the existing locale-free en-US grouping convention.
  final components = value.abs().toString().toLowerCase().split('e');
  final mantissa = components.first.split('.');
  final exponent = components.length == 2 ? int.parse(components[1]) : 0;
  final fractionPlaces = mantissa.length == 2 ? mantissa[1].length : 0;
  var scaled = BigInt.parse(mantissa.join());
  final shift = exponent - fractionPlaces + places;
  final power = BigInt.from(10).pow(shift.abs());
  if (shift >= 0) {
    scaled *= power;
  } else {
    final quotient = scaled ~/ power;
    final remainder = scaled % power;
    scaled =
        quotient + (remainder * BigInt.two >= power ? BigInt.one : BigInt.zero);
  }
  final parts = _insertDecimal(scaled, places).split('.');
  final grouped = beuiGroupThousands(parts.first);
  return '${value.isNegative ? '-' : ''}$grouped'
      '${parts.length == 2 ? '.${parts[1]}' : ''}';
}

// Dart's toStringAsFixed stops at 20 digits. Build the exact decimal result
// from the IEEE-754 significand so source precision through 100 is preserved.
String _sourceFixed(double value, int places) {
  if (value.isNaN) return 'NaN';
  if (value == double.infinity) return 'Infinity';
  if (value == double.negativeInfinity) return '-Infinity';
  if (value.abs() >= 1e21) return value.toString();

  final negative = value < 0;
  final bytes = ByteData(8)..setFloat64(0, value.abs(), Endian.big);
  final high = bytes.getUint32(0, Endian.big);
  final low = bytes.getUint32(4, Endian.big);
  final exponentBits = (high >> 20) & 0x7ff;
  final fraction = (BigInt.from(high & 0x000fffff) << 32) | BigInt.from(low);
  final significand = exponentBits == 0
      ? fraction
      : fraction | (BigInt.one << 52);
  final binaryExponent = exponentBits == 0
      ? -1074
      : exponentBits.toInt() - 1075;

  var numerator = significand * BigInt.from(5).pow(places);
  final denominatorPower = -places - binaryExponent;
  if (denominatorPower <= 0) {
    numerator <<= -denominatorPower;
  } else {
    final denominator = BigInt.one << denominatorPower;
    final quotient = numerator ~/ denominator;
    final remainder = numerator % denominator;
    numerator =
        quotient +
        (remainder * BigInt.from(2) >= denominator ? BigInt.one : BigInt.zero);
  }

  final digits = _insertDecimal(numerator, places);
  return negative && value != 0 ? '-$digits' : digits;
}

String _insertDecimal(BigInt value, int places) {
  var digits = value.toString();
  if (places > 0) {
    if (digits.length <= places) {
      digits = '${'0' * (places + 1 - digits.length)}$digits';
    }
    final point = digits.length - places;
    digits = '${digits.substring(0, point)}.${digits.substring(point)}';
  }
  return digits;
}
