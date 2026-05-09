# 8051 Triangular Wave Generator

Variable-frequency triangular wave generator on the AT89S52 microcontroller featuring 16-bit software division, Timer0 ISR waveform output, and UART-based runtime frequency control.

## Overview

Generates a ±2.5V triangular waveform at frequencies between 100Hz and 500Hz using an 8-bit DAC0808. Frequency is set at runtime by sending a 16-bit value over UART at 19200 baud. All waveform output is handled inside a Timer0 ISR, keeping the main loop free.

## Hardware

| Component | Role                                   |
| --------- | -------------------------------------- |
| AT89S52   | Main microcontroller                   |
| DAC0808   | 8-bit DAC, output on Port 1            |
| USB-UART  | Serial interface for frequency control |

## How It Works

**Waveform generation**

The DAC value is stepped by 5 on every Timer0 overflow, from 0 to 255, then back down. This gives 51 points per half-cycle (255/5 = 51). The `cycle` bit in internal RAM tracks direction.

**Variable frequency**

Timer0's auto-reload value controls the overflow rate and therefore the output frequency. The relationship is:

```
Time Period = (256 - count) × 0.5µs × 102 = 1/f
           ⟹ (256 - count) = 19608 / f
```

When a new frequency is received over UART, the firmware computes `19608 / f` using a software division routine, takes the two's complement of the result, and loads it into `TH0`/`TL0`.

**Software division**

The 8051 has no hardware divider beyond 8-bit. A 16-bit restoring long-division routine is implemented in assembly to compute `19608 / f`. It processes 16 bits via repeated shift-and-subtract.

Known limitation: the routine discards the remainder, so frequencies that produce a large remainder will have a small timing error. For example, 469Hz produces a noticeable deviation.

**UART protocol**

Send two bytes (high byte first, then low byte) representing the desired frequency in Hz. Example for 200Hz:

```
0x00 0xC8
```

The serial ISR handles reception and immediately updates the timer reload value.

## Frequency Range

| Frequency | (256 - count) | Notes                   |
| --------- | ------------- | ----------------------- |
| 100 Hz    | 196           | Lower bound             |
| 200 Hz    | 98            |                         |
| 469 Hz    | ~41           | Highest remainder error |
| 500 Hz    | ~39           | Upper bound             |

## Project Structure

```
main.asm - full source, single file
f100.jpeg - waveform at f=100Hz
f255.jpeg - waveform at f=255Hz
f450.jpeg - waveform at f=450Hz
triangular_wave_lab_report.pdf - documentation (this was done as part of a lab project)
```

## Build

Assemble with Keil µVision targeting AT89S52 at 11.0592MHz.

Crystal frequency matters — the baud rate reload value `(256-7)` and the 0.5µs cycle time both assume 11.0592MHz. A different crystal will require recalculating both.
