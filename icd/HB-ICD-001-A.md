# HB-ICD-001: Harbour Buoy to Shore Station Interface Control Document

Revision A. Distribution unrestricted.

This document is invented for the hello-galaxy-first-bite demonstration. The
buoy, the shore station and every value in it are synthetic.

## 1. Scope

This document defines the messages a harbour buoy sends to its shore station.
The shore station sends nothing to the buoy on this interface.

## 2. Transport

Each message is one UDP datagram sent by the buoy to port 47200 of the shore
station. The interface is named BUOY.

## 3. Conventions

### 3.1 Words and bits

A message is a whole number of 16-bit words. Words are numbered from 1 and are
sent most significant byte first. The bits of a word are numbered 15 to 0, and
bit 15 is the most significant.

### 3.2 Numbers

Fields are unsigned integers unless a table says "two's complement". A field
with an LSB weight carries the physical value divided by that weight. Spare
bits are sent as zero.

## 4. Common header

Every message starts with the two words of Table 4-1.

Table 4-1: Common header

| Word | Bits | Field | Unit | Description |
|---|---|---|---|---|
| 1 | 15-8 | Message ID | | Identifies the message. See Table 5-1. |
| 1 | 7-0 | Message Length | words | Length of the message in 16-bit words. |
| 2 | 15-12 | Buoy Number | | Buoy that sent the message, 1 to 15. |
| 2 | 11-0 | Sequence Number | | Incremented by the buoy for each message; wraps from 4095 to 0. |

## 5. Messages

Table 5-1: Messages of the BUOY interface

| Message ID | Message | Length (words) | Sent |
|---|---|---|---|
| 1 | Status | 4 | every ten seconds |
| 2 | Sea State | 6 | every minute |
| 3 | Position | 8 | every minute, and at once when the mooring alarm is raised |

### 5.2 Status

Sent every ten seconds while the buoy is powered.

Table 5-2: Status

| Word | Bits | Field | LSB | Unit | Description |
|---|---|---|---|---|---|
| 1-2 | | Common header | | | Table 4-1. |
| 3 | 15-14 | Operating Mode | | | What the buoy is doing. See Table 5-2a. |
| 3 | 13 | Lamp On | | | 1 when the navigation lamp is lit. |
| 3 | 12 | Mooring Alarm | | | 1 when the buoy is outside its watch circle. |
| 3 | 11 | Position Fix | | | 1 when the receiver has a position fix. |
| 3 | 10-0 | Battery Voltage | 0.01 | V | Voltage of the main battery. |
| 4 | 15-0 | Uptime | | min | Minutes since the buoy was powered. |

Table 5-2a: Operating Mode

| Value | Meaning |
|---|---|
| 0 | Standby |
| 1 | Reporting |
| 2 | Low Power |
| 3 | reserved |

### 5.3 Sea State

Sent every minute with the buoy's measurements of the water and the air.

Table 5-3: Sea State

| Word | Bits | Field | LSB | Unit | Description |
|---|---|---|---|---|---|
| 1-2 | | Common header | | | Table 4-1. |
| 3 | 15-0 | Water Temperature | 0.01 | °C | Two's complement. Temperature of the water one metre below the surface. |
| 4 | 15-6 | Significant Wave Height | 0.01 | m | Mean height of the highest third of the waves. |
| 4 | 5-0 | Wave Period | 0.5 | s | Mean period of the waves. |
| 5 | 15-7 | Wind Direction | | deg | Direction the wind blows from, clockwise from true north. |
| 5 | 6-0 | Wind Speed | 0.5 | m/s | Mean wind speed three metres above the water. |
| 6 | 15-0 | Air Pressure | 0.1 | hPa | Pressure of the air at the buoy. |

### 5.4 Position

Sent every minute, and at once when the mooring alarm is raised.

Table 5-4: Position

| Word | Bits | Field | LSB | Unit | Description |
|---|---|---|---|---|---|
| 1-2 | | Common header | | | Table 4-1. |
| 3-4 | 15-0 | Latitude | 0.0000001 | deg | Two's complement. WGS 84, positive north. |
| 5-6 | 15-0 | Longitude | 0.0000001 | deg | Two's complement. WGS 84, positive east. |
| 7 | 15-7 | Drift Course | | deg | Direction the buoy is moving, clockwise from true north. |
| 7 | 6-0 | Drift Speed | 0.05 | m/s | Speed of the buoy over the ground. |
| 8 | 15-12 | Satellites In View | | | Satellites the receiver is tracking. |
| 8 | 11-0 | Antenna Height | 0.1 | m | Two's complement. Height of the antenna above the WGS 84 ellipsoid. |

## Appendix A. Example messages

Each example gives the values and the bytes of one message, most significant
byte of word 1 first.

### A.1 Status

Buoy 7, sequence number 100. Operating mode Reporting, lamp on, no mooring
alarm, position fix held, battery 12.60 V, uptime 1440 minutes.

```text
0104 7064 6cec 05a0
```

### A.2 Sea State

Buoy 7, sequence number 101. Water temperature -1.25 °C, significant wave
height 2.35 m, wave period 8.5 s, wind from 285 degrees at 12.5 m/s, air
pressure 1003.2 hPa.

```text
0206 7065 ff83 3ad1 8e99 2730
```

### A.3 Position

Buoy 7, sequence number 102. Latitude 44.5012345 degrees, longitude
-30.2543210 degrees, drifting on course 135 degrees at 0.35 m/s, 9 satellites
in view, antenna height -1.5 m.

```text
0308 7066 1a86 5979 edf7 8e96 4387 9ff1
```
