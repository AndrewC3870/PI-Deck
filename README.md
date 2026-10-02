# PiDeck - A Custom Handheld Linux Deck

<img src="images/PiDeck.jpg" />
<img src="images/PiDeckInLife.JPG" />


PiDeck is a fully custom, battery-powered handheld computer built around an
**Orange Pi Zero 3 (H618)**, with a small SPI display for portable "CLI mode,"
HDMI output for a full desktop, a custom mechanical keyboard, retro game
emulation, and a secondary **ESP32-C3 + LLCC68 LoRa** co-processor for a
private, encrypted mesh chat system.

---

## Why this project exists

Most handheld Linux builds assume a Raspberry Pi. This one
is built around the Orange Pi Zero 3 instead, cheaper, smaller. Almost nothing about this build worked out
of the box. Getting a plain SPI display to show the correct colors required
patching and rebuilding a kernel module from source (probably because of a cheap display).

---

## Hardware

| Component | Spec |
|---|---|
| SBC | Orange Pi Zero 3 (H618), 1GB RAM |
| Display | 2.8" SPI TFT, ST7789V driver, 320x240, 14-pin (no touch, because its cheaper) |
| Keyboard | Custom RP2040 keyboard (link to repo: [GitHub](https://github.com/AndrewC3870/RP2040_Keyboard)), QMK firmware|
| Battery | 4x 18650 3500mAh cells, **1S4P** configuration (~14,000mAh / ~51Wh) |
| Power | UPS module (15W, 5V) for pass-through charging |
| Audio | USB sound card -> amplifier -> speaker (reused Samsung A53 speaker module) |
| LoRa co-processor | ESP32-C3 Super Mini + 868MHz LLCC68 LoRa module |
| Storage | microSD |

### Display wiring (ST7789V → Orange Pi Zero 3)

| Display pin | Orange Pi pin |
|---|---|
| VCC | 3.3V |
| GND | GND |
| LED (backlight) | PC7 |
| SCK | PH6 |
| SDI (MOSI) | PH7 |
| SDO (MISO) | PH8 |
| DC | PC5 |
| RESET | PC8 |
| CS | PH9 |

### LoRa wiring (LLCC68 to ESP32-C3 Super Mini)

| LLCC68 pin | ESP32-C3 GPIO |
|---|---|
| SCK | 4 |
| MISO | 5 |
| MOSI | 6 |
| NSS | 7 |
| DIO1 | 1 |
| NRST | 0 |
| BUSY | 3 |

### ESP32-C3 to Orange Pi link

Direct 3-wire UART (TX/RX crossed, shared GND), wired to the Orange Pi's
**debug/console UART** header (`/dev/ttyS0`) to offer the dedicated UART for external GPIO pins if needed. The onboard serial console was
disabled to free this port for the LoRa link.

---

## Features

- **Portable CLI mode** - console rendered directly on the 2.8" SPI display, no desktop overhead
- **Full desktop mode** - lightweight Openbox + tint2 session over HDMI, or mirrored onto the SPI panel via a dedicated X server instance
- **Swappable control modules** - custom control module with custom arangement for buttons and etc.
- **LoRa mesh chat** - encrypted group chat over 868MHz LoRa, independent of the ESP32's firmware.
- **Pass-through UPS charging** - charge and run simultaneously off the 1S4P battery pack via a dedicated power module
- **Retro game emulation** - Small bonus :))
- **Aditional antena** - dedicated antena slot for future RTL-SDR module. 
---

## Software setup

The [`setup_orange_pi_display.sh`](./scripts/setup_orange_pi_display.sh) and ['setup_desktop_mode.sh'](./scripts/setup_desktop_mode.sh) script in this repo automates
the full OS-side setup starting from a fresh flash of the
**official Orange Pi vendor image**:

```
Orangepizero3_1.0.4_debian_bookworm_server_linux6.1.31.img
```

(Available from Orange Pi's official product page)

**Why this exact image matters:** the kernel module fix in this script is
tied to kernel `6.1.31-sun50iw9` specifically.


### Running the setup script

After first boot, SSH in, create your own user account, then run:

```bash
chmod +x setup_orange_pi_display.sh setup_desktop_mode.sh
./setup-piDeck.sh
```
If everything smooth then run:

```bash
./setup_desktop_mode.sh
```

