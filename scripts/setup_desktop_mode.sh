#!/bin/bash
# =============================================================================
# PiDeck setup script — Stage 2
# Run this ONLY after rebooting from setup_orange_pi_display.sh
#
# Installs: desktop environment, RetroArch + cores, audio config,
# SPI-display desktop launcher scripts.
# =============================================================================

set -e
apt_install() {
    if ! sudo apt install --no-install-recommends -y "$@"; then
        local SUITE
        SUITE=$(lsb_release -sc 2>/dev/null || echo bookworm)
        sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
        sudo bash -c "cat > /etc/apt/sources.list" <<EOF
deb http://archive.debian.org/debian ${SUITE} main contrib non-free
deb http://archive.debian.org/debian-security ${SUITE}-security main contrib non-free
deb http://archive.debian.org/debian ${SUITE}-updates main contrib non-free
EOF
        sudo apt-get -o Acquire::Check-Valid-Until=false update
        sudo apt install --no-install-recommends -y "$@"
        sudo cp /etc/apt/sources.list.bak /etc/apt/sources.list
        sudo apt update
    fi
}

echo "=== Small console font for the 2.8-inch panel ==="
sudo sed -i 's/^FONTSIZE=.*/FONTSIZE="6x12"/' /etc/default/console-setup 2>/dev/null || true
sudo setupcon 2>/dev/null || true

echo "=== X11 + Openbox + tint2 + wallpaper tool + browser ==="
apt_install xserver-xorg xinit openbox tint2 feh xterm python3-xdg xfonts-base
apt_install falkon

mkdir -p ~/.config/openbox
cp /etc/xdg/openbox/menu.xml ~/.config/openbox/menu.xml 2>/dev/null || true
cp /etc/xdg/openbox/rc.xml ~/.config/openbox/rc.xml 2>/dev/null || true
sudo mkdir -p /var/lib/openbox
sudo cp /etc/xdg/openbox/menu.xml /var/lib/openbox/debian-menu.xml 2>/dev/null || true

cat > ~/.xinitrc <<'EOF'
exec openbox-session
EOF

cat > ~/.config/openbox/autostart <<'EOF'
tint2 &
xterm &
EOF

echo "=== SPI-display desktop launcher ==="
cat > ~/spi-desktop.sh <<'EOF'
#!/bin/bash
sudo X :1 -config /etc/X11/xorg-spi.conf vt2 &
XPID=$!
sleep 3
DISPLAY=:1 xset s off
DISPLAY=:1 xset -dpms
DISPLAY=:1 xset s noblank
DISPLAY=:1 openbox-session &
sleep 1
DISPLAY=:1 tint2 &
DISPLAY=:1 xterm &
wait $XPID
EOF
chmod +x ~/spi-desktop.sh

cat > ~/spi-desktop-stop.sh <<'EOF'
#!/bin/bash
echo "Stopping desktop session..."
pkill retroarch 2>/dev/null
pkill mpv 2>/dev/null
pkill falkon 2>/dev/null
pkill xterm 2>/dev/null
pkill tint2 2>/dev/null
pkill openbox 2>/dev/null
sleep 1
sudo pkill -f "X :1" 2>/dev/null
echo "Desktop session stopped. Back to console mode."
EOF
chmod +x ~/spi-desktop-stop.sh

sudo bash -c 'cat > /etc/X11/xorg-spi.conf' <<'EOF'
Section "Device"
    Identifier "SPI-Display"
    Driver "fbdev"
    Option "fbdev" "/dev/fb0"
EndSection

Section "Screen"
    Identifier "SPI-Screen"
    Device "SPI-Display"
EndSection
EOF

echo "=== Backlight-on service (keeps panel lit reliably across boots) ==="
sudo bash -c 'cat > /etc/systemd/system/spi-backlight-on.service' <<'EOF'
[Unit]
Description=Force SPI display backlight on
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo 1 > /sys/class/backlight/backlight/brightness; echo 0 > /sys/class/backlight/backlight/bl_power'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now spi-backlight-on.service

echo "=== RetroArch + cores, tuned for a slow SPI panel ==="
apt_install retroarch libretro-nestopia libretro-bsnes-mercury-performance \
            libretro-gambatte libretro-mgba libretro-beetle-pce-fast \
            libretro-beetle-psx libretro-core-info
mkdir -p ~/roms/{nes,snes,gb,gba,pce,psx,bios}

retroarch --menu &
sleep 3
kill %1 2>/dev/null || true

CFG=~/.config/retroarch/retroarch.cfg
set_cfg() {
    if grep -q "^$1 " "$CFG" 2>/dev/null; then
        sed -i "s|^$1 .*|$1 = \"$2\"|" "$CFG"
    else
        echo "$1 = \"$2\"" >> "$CFG"
    fi
}
set_cfg video_vsync false
set_cfg video_hard_sync false
set_cfg video_threaded false
set_cfg video_frame_delay 0
set_cfg video_smooth false
set_cfg video_max_swapchain_images 2
set_cfg audio_latency 32
set_cfg menu_driver rgui
set_cfg audio_driver alsa
set_cfg audio_device default

echo ""
echo "############################################"
echo "# Setup completed."
echo "#"
echo "# IMPORTANT: run 'aplay -l' and identify your"
echo "# USB sound card number, then edit /etc/asound.conf"
echo "# to match (card number may differ per install):"
echo "############################################"