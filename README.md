# renogy_bms

Renogy (DC Home) LiFePO4 BMS driver for [bms_core](https://github.com/ril3y/bms_core).

The Renogy battery BLE path is **Modbus-RTU over BLE** (slave `0xFF`,
CRC-16/Modbus) with a **split transport**: commands are written to FFD0/FFD1 and
responses arrive on FFF0/FFF1. Modules are identified by their `RBT…` advertised
name. Reads decode per-cell voltages, temperatures, pack voltage/current,
remaining + full capacity and SOC. (The BLE path does not expose SOH, cycle
count or balancing.)

Read-only in this release. Protocol recovered by static analysis for
interoperability; not affiliated with Renogy.

## License

MIT.
