## 0.1.0

* Initial release: Renogy (DC Home) LiFePO4 read-only driver for bms_core -
  Modbus-RTU over BLE (unit 0xFF) with split services (write FFD0/FFD1, notify
  FFF0/FFF1). Decodes cells, temperatures, pack V/A, remaining/full capacity
  and SOC. (The BLE battery path exposes no SOH / cycle count.)
