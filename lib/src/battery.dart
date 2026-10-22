// Renogy (DC Home) LiFePO4 driver for bms_core. Modbus-RTU over BLE (unit 0xFF),
// with writes on FFD0/FFD1 and notifications on FFF0/FFF1. Read-only live
// monitoring. The BLE battery path exposes no SOH / cycle count / balancing, so
// the driver declares only what it actually reads.

import 'dart:async';
import 'dart:typed_data';

import 'package:bms_core/bms_core.dart';
import 'package:universal_ble/universal_ble.dart';

import 'gatt.dart';
import 'registers.dart';

class RenogyBatteryDriver extends BatteryDriver {
  @override
  String get id => 'renogy';

  @override
  String get name => 'Renogy';

  /// Match Renogy **smart batteries** by their `RBT…` name only. The FFD0
  /// service is shared by every Renogy BT device (charge controllers, inverters,
  /// shunts — e.g. a `BT-TH-…` BT-2 module fronting an MPPT controller), so
  /// matching the service would mislabel those non-batteries as a battery and
  /// then fail on the battery registers. CellScope reads batteries, so only the
  /// battery name qualifies. (If a Renogy battery advertises a different name,
  /// use "Battery not listed? Help add it" so we can add it.)
  @override
  final BleSignature signature = BleSignature(
    namePattern: RegExp(r'^(RBT|RNG)', caseSensitive: false),
  );

  @override
  BatteryCapabilities get capabilities => const BatteryCapabilities(
        cells: true,
        temperatures: true,
      );

  @override
  BatteryIdentity describe(BleDevice device) => BatteryIdentity(serial: device.name);

  @override
  Battery create(BleDevice device) => RenogyBattery(device, this);
}

class RenogyBattery extends Battery {
  final BleDevice device;
  @override
  final RenogyBatteryDriver driver;

  final BleLink _link;
  final ModbusRtu _rtu = const ModbusRtu(unitId: kUnitId);
  final ModbusAssembler _asm = ModbusAssembler(unitId: kUnitId);
  final _replies = StreamController<ModbusReply>.broadcast();
  final _snapshots = StreamController<BatterySnapshot>.broadcast();
  final _cells = StreamController<List<double>>.broadcast();
  StreamSubscription<Uint8List>? _rx;
  Timer? _poll;
  RenogyRealtime? last;

  RenogyBattery(this.device, this.driver)
      : _link = BleLink(device,
            service: kNotifyService,
            notify: kNotifyUuid,
            writeService: kWriteService,
            write: kWriteUuid,
            writeWithResponse: false);

  @override
  String get id => 'renogy-${device.deviceId}';

  @override
  String get displayName => device.name?.isNotEmpty == true ? device.name! : 'Renogy battery';

  @override
  Stream<BatterySnapshot> get snapshots => _snapshots.stream;
  @override
  Stream<List<double>> get cellVoltages => _cells.stream;
  @override
  Stream<bool> get connection => _link.connection;

  @override
  Future<void> connect() async {
    _rx = _link.incoming.listen((chunk) => _asm.add(chunk).forEach(_replies.add));
    await _link.connect();
  }

  Future<ModbusReply> _exchange(Uint8List frame, int function, {Duration timeout = const Duration(seconds: 3)}) =>
      _link.exclusive(() async {
        final reply = _replies.stream
            .firstWhere((r) => r.function == function || r.function == (function | 0x80))
            .timeout(timeout);
        await _link.write(frame);
        final r = await reply;
        if (r.isException) throw StateError('BMS refused request: Modbus exception ${r.exceptionCode}');
        return r;
      });

  Future<List<int>> readRegisters(int address, int count) async =>
      (await _exchange(_rtu.readHolding(address, count), fnReadHolding)).registers;

  @override
  void startLive() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 1), (_) async {
      try {
        final rt = RenogyRealtime(await readRegisters(regRealtime, regRealtimeCount));
        final cells = RenogyCells(await readRegisters(regCells, regCellsCount));
        last = rt;
        _snapshots.add(_toSnapshot(rt, cells));
        _cells.add(cells.cellVoltages);
      } catch (_) {
        // Retried on the next tick.
      }
    });
  }

  @override
  void stopLive() => _poll?.cancel();

  BatterySnapshot _toSnapshot(RenogyRealtime rt, RenogyCells c) => BatterySnapshot(
        time: DateTime.now(),
        voltage: rt.voltage,
        current: rt.current,
        soc: rt.socPercent,
        remainingAh: rt.remainingAh,
        fullAh: rt.fullAh > 0 ? rt.fullAh : rt.remainingAh,
        cycles: 0,
        temperaturesC: c.temperaturesC,
        activeProtections: const [],
        protectionMask: 0,
        chargeEnabled: true,
        dischargeEnabled: true,
      );

  @override
  Future<BatteryIdentity> identify() async {
    final c = RenogyCells(await readRegisters(regCells, regCellsCount));
    final rt = last ?? RenogyRealtime(await readRegisters(regRealtime, regRealtimeCount));
    return BatteryIdentity(
      serial: device.name,
      cellCount: c.cellCount,
      nominalAh: rt.fullAh > 0 ? rt.fullAh : null,
      nominalVoltage: c.cellCount * 3.2,
      soc: rt.socPercent,
    );
  }

  @override
  Future<HealthReport?> readHealth() async {
    final rt = last ?? RenogyRealtime(await readRegisters(regRealtime, regRealtimeCount));
    return HealthReport(cycles: 0, fullChargeAh: rt.fullAh > 0 ? rt.fullAh : null);
  }

  @override
  Future<List<BatteryNotice>> notices() async => const [];

  @override
  Future<void> disconnect() async {
    stopLive();
    await _rx?.cancel();
    await _link.disconnect();
  }
}
