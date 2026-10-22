// Renogy (DC Home) LiFePO4 BLE + Modbus constants, recovered by static analysis
// of com.renogy.dchome. The battery path is Modbus-RTU over BLE, unit 0xFF, with
// a split transport: writes go to FFD0/FFD1, notifications arrive on FFF0/FFF1.

const String kNotifyService = '0000fff0-0000-1000-8000-00805f9b34fb';
const String kNotifyUuid = '0000fff1-0000-1000-8000-00805f9b34fb'; // device -> app
const String kWriteService = '0000ffd0-0000-1000-8000-00805f9b34fb';
const String kWriteUuid = '0000ffd1-0000-1000-8000-00805f9b34fb'; // app -> device

/// Modbus slave id for Renogy LFP packs.
const int kUnitId = 0xFF;

// Holding-register reads.
const int regRealtime = 0x13B2; // 6 regs: current, pack V, remaining + full Ah
const int regRealtimeCount = 6;
const int regCells = 0x1388; // 0x22 regs: cell count + voltages + temps
const int regCellsCount = 0x22;
