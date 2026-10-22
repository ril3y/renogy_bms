import 'package:bms_core/bms_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:renogy_bms/renogy_bms.dart';
import 'package:universal_ble/universal_ble.dart';

String _hex(List<int> b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

void main() {
  test('realtime read frame (unit 0xFF, reg 0x13B2, 6 regs)', () {
    final frame = const ModbusRtu(unitId: kUnitId).readHolding(regRealtime, regRealtimeCount);
    expect(_hex(frame).startsWith('ff0313b20006'), isTrue);
    expect(frame.length, 8); // 6-byte body + 2-byte CRC
  });

  test('realtime decode (x0.1 values, 32-bit x0.001 Ah)', () {
    final rt = RenogyRealtime([100, 128, 1, 26564, 1, 34464]);
    expect(rt.current, closeTo(10.0, 1e-9));
    expect(rt.voltage, closeTo(12.8, 1e-9));
    expect(rt.remainingAh, closeTo(92.1, 1e-9));
    expect(rt.fullAh, closeTo(100.0, 1e-9));
    expect(rt.socPercent, 92);
  });

  test('cell + temperature decode', () {
    final regs = List<int>.filled(0x22, 0);
    regs[0] = 4; // 4 cells
    regs[1] = 33;
    regs[2] = 33;
    regs[3] = 33;
    regs[4] = 33; // 3.3 V each
    regs[17] = 2; // 2 temp sensors
    regs[18] = 250; // 25.0 C
    regs[19] = 260; // 26.0 C
    final c = RenogyCells(regs);
    expect(c.cellCount, 4);
    expect(c.cellVoltages, [3.3, 3.3, 3.3, 3.3]);
    expect(c.temperaturesC, [25.0, 26.0]);
  });

  test('driver matches a Renogy battery by RBT name, not the shared FFD0 service', () {
    final d = RenogyBatteryDriver();
    expect(d.id, 'renogy');
    expect(d.signature.services, isEmpty); // FFD0 is shared with controllers/inverters
    final rbt = BleDevice(deviceId: 'x', name: 'RBT12100LFP-BT', rssi: -50, services: [kWriteService]);
    // A BT-2 module fronting a charge controller shares FFD0 but isn't a battery.
    final controller = BleDevice(deviceId: 'y', name: 'BT-TH-66F8EE0D', rssi: -50, services: [kWriteService]);
    expect(d.score(rbt) > 0, isTrue);
    expect(d.score(controller), 0); // not a battery -> not claimed
  });
}
