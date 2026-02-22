# GripFit Calibration Guide

**Version:** 2.0
**Last Updated:** February 2026
**Status:** Phase 1 (software tare) active — Phase 2 (force calibration) pending physical test rig

---

## Overview

The GripFit device measures grip strength using an HX711 load cell amplifier on a Seeed XIAO nRF52840 microcontroller. The sensor produces raw 24-bit ADC values that must be converted to real force units (lb or kg) through calibration.

**The conversion formula:**

```
calibrated_force = slope × (raw_reading − zero_offset)
```

- `zero_offset` — average raw reading at zero applied force
- `slope` — scaling factor derived from a known reference force

---

## Current State: Software Tare (Phase 1)

The production firmware (v1.0) includes a software tare via BLE command. This handles zero-offset correction without any physical calibration setup.

**How it works:**
1. Device streams raw HX711 readings as `R:<value>\n` over BLE
2. iOS app sends `CMD:TARE\n` to the device
3. Firmware captures the current raw reading as `tareOffset`
4. All subsequent readings are reported as `raw - tareOffset`
5. The tare offset is held in RAM — it resets on power cycle, which is acceptable for now

**What this gives us:**
- Relative force measurements (zero = no grip, positive = squeezing)
- Consistent baseline per session
- Enough for MVP: users can see real-time force curves, compare within a session, and track relative progress

**What this does NOT give us:**
- Absolute force in lb or kg
- Cross-device comparability
- Clinical-grade measurement

---

## Future State: Full Calibration (Phase 2)

Phase 2 requires a physical test rig to apply known reference forces to the device. This section documents the plan for when that hardware is ready.

### Calibration Approach

**Single-point calibration (minimum viable):**
1. Record raw value at zero force → `zero_offset`
2. Apply a known force (e.g., 50.0 lb via calibrated weights or reference gauge) → record raw value
3. Calculate: `slope = known_force / (raw_at_known_force - zero_offset)`
4. Store `zero_offset` and `slope` persistently

**Multi-point calibration (higher accuracy, future upgrade):**
1. Record raw values at 3–5 known force levels (e.g., 0, 10, 25, 50, 100 lb)
2. Perform least-squares linear regression to compute best-fit slope and offset
3. Achieves ±1–2% accuracy across the full range

### Where Calibration Constants Live

There are two options under consideration:

| Storage Location | Pros | Cons |
|---|---|---|
| **Device EEPROM** (nRF52840 flash emulation) | Constants travel with device; no app dependency; works offline | Requires a dedicated calibration firmware sketch; slightly more complex |
| **iOS app / Firebase** (per-device lookup by serial or MAC) | No firmware changes; calibration can be updated remotely; supports fleet management | Requires device identification; depends on app/cloud availability |

**Recommended approach:** Store in EEPROM for device independence, mirror to Firebase for backup and fleet analytics. The iOS app reads from Firebase on first pair, falls back to requesting from device via a future `CMD:CAL?\n` command.

### Physical Test Rig Requirements

- The device must be rigidly mounted so force is applied in the same direction and location as a real hand grip
- **Option A (recommended):** Use a secondary digital force gauge (0–200 lb range) pressed against the grip handles as a reference
- **Option B (DIY):** Secure device in a fixture, use a strap/pulley system with calibrated weight plates (5, 10, 25, 50 lb)
- Force must be held perfectly steady during the averaging window (5 seconds / 100 samples at 50ms)
- Calibrate at room temperature; recalibrate if environment changes significantly or after extended use

### Calibration Firmware Sketch

When the test rig is ready, a dedicated calibration sketch will be uploaded to the device via USB. This sketch:

1. Prompts via Serial Monitor (no BLE needed for calibration)
2. Guides the operator through zero-force and known-force steps
3. Averages 100 readings over 5 seconds at each step to reduce noise
4. Computes `zero_offset` and `slope`
5. Writes both values to EEPROM / flash
6. The production firmware is then re-uploaded — it reads the stored constants at boot

The calibration sketch code will be developed when the physical test rig is built. The existing calibration document (v1.0) contains reference code using `EEPROM.h` that will be adapted for the XIAO nRF52840's flash storage API.

---

## Integration with iOS App

### Phase 1 (current)
- App receives raw tare-adjusted readings from firmware
- Readings are displayed as raw units (no lb/kg conversion)
- App UI should label values as "raw" or use a relative scale

### Phase 2 (after calibration)
- App retrieves `slope` and `zero_offset` from Firebase (or from device via BLE command)
- Calibration transform is applied in the app's data pipeline, between the BLE parser output and the ViewModel:
  ```
  BLE reading (raw) → Calibration layer (raw × slope) → ViewModel (force in lb/kg)
  ```
- The BLE integration instructions document already specifies this architecture — a calibration layer can be inserted without restructuring
- Unit preference (lb vs kg) is a simple multiplier applied after calibration (1 lb = 0.4536 kg)

---

## Verification Protocol (Phase 2)

After calibrating a device:
1. Apply the same known force used during calibration — reading should match within ±2–3%
2. Apply a different known force (e.g., if calibrated at 50 lb, test at 25 lb) — should still be accurate if the sensor is linear
3. Remove all force — should read 0 ±1% of full scale
4. If readings drift over time, recalibrate

---

## Summary

| Phase | Status | What It Provides |
|---|---|---|
| **Phase 1: Software Tare** | Active | Zero-offset correction, relative measurements, real-time force curves |
| **Phase 2: Single-Point Calibration** | Pending test rig | Absolute force in lb/kg, cross-device consistency |
| **Phase 3: Multi-Point Calibration** | Future | Higher accuracy across full range, clinical-grade measurement |