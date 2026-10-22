// Renogy register decode. Registers are big-endian 16-bit words (Modbus). Field
// semantics + scaling were recovered from the app's battery parsers. Renogy
// scales most values x0.1; capacities are 32-bit x0.001 Ah.

int _i16(int v) => v >= 0x8000 ? v - 0x10000 : v;

/// Realtime block: read of 6 registers from 0x13B2.
class RenogyRealtime {
  final List<int> regs;
  RenogyRealtime(this.regs);

  int _u(int i) => i < regs.length ? regs[i] : 0;

  double get current => _i16(_u(0)) / 10.0; // x0.1 A, signed (some SKUs x0.01)
  double get voltage => _u(1) / 10.0; // x0.1 V
  double get remainingAh => ((_u(2) << 16) | _u(3)) / 1000.0; // 32-bit x0.001 Ah
  double get fullAh => ((_u(4) << 16) | _u(5)) / 1000.0;
  int get socPercent => fullAh > 0 ? (remainingAh / fullAh * 100).round().clamp(0, 100) : 0;
}

/// Cell + temperature block: read of 0x22 registers from 0x1388.
/// reg0 = cell count N, reg1..N = cell voltages (x0.1 V), reg17 = temp count M,
/// reg18.. = temperatures (x0.1 °C, signed).
class RenogyCells {
  final List<int> regs;
  RenogyCells(this.regs);

  int _u(int i) => i < regs.length ? regs[i] : 0;

  int get cellCount => _u(0).clamp(0, 16);
  int get tempCount => _u(17).clamp(0, 8);

  List<double> get cellVoltages => [for (var i = 0; i < cellCount; i++) _u(1 + i) / 10.0];
  List<double> get temperaturesC => [for (var i = 0; i < tempCount; i++) _i16(_u(18 + i)) / 10.0];
}
