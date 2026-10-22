/// Renogy (DC Home) LiFePO4 driver for bms_core: Modbus-RTU over BLE (unit
/// 0xFF), writes on FFD0/FFD1 and notifications on FFF0/FFF1. Read-only live
/// monitoring of cells, temperatures, pack V/A, capacity and SOC.
library;

export 'src/battery.dart';
export 'src/gatt.dart';
export 'src/registers.dart';
