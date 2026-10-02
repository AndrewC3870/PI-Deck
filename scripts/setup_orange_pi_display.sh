#!/bin/bash
# =============================================================================
# PiDeck setup script
# Orange Pi Zero 3 (H618) + ST7789V SPI display + RP2040 keyboard base OS setup
#
# Target image: Orangepizero3_1.0.4_debian_bookworm_server_linux6.1.31
# (also works on the Bullseye build of the same kernel version)

# This script is split into stages. Stage 1 ends with a reboot checkpoint —
# do not skip reading its final output.
# =============================================================================

set -e

# -----------------------------------------------------------------------
# apt helper: falls back to archive.debian.org if the live mirror 404s
# on a package that's been pruned (mainly affects older/EOL suites)
# -----------------------------------------------------------------------
apt_install() {
    if ! sudo apt install --no-install-recommends -y "$@"; then
        echo "Primary mirror failed for: $@ — retrying via archive.debian.org"
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


echo "############################################"
echo "# Stage 1:"
echo "############################################"

sudo apt update

echo "Disabling services not needed on a handheld deck..."

for svc in containerd.service docker.socket \
           lircd.service lircd.socket rpcbind.service rpcbind.socket \
           nfs-client.target remote-fs.target smartmontools.service \
           sysstat.service vnstat.service openvpn.service \
           unattended-upgrades.service; do
    sudo systemctl disable --now "$svc" 2>/dev/null || true
done

echo "Capping journal size..."
sudo sed -i 's/#SystemMaxUse=.*/SystemMaxUse=50M/' /etc/systemd/journald.conf
sudo systemctl restart systemd-journald

echo "Confirming vendor zram is active..."
systemctl status orangepi-zram-config.service --no-pager || true
sudo /sbin/swapon --show

echo "Adding user to video, audio, dialout groups..."
sudo usermod -aG video,audio,dialout "$USER"

echo "############################################"
echo "# Stage 2: SPI display overlay"
echo "############################################"

apt_install fbset device-tree-compiler build-essential bc bison flex \
            libssl-dev libncurses-dev dos2unix

mkdir -p ~/overlay
cat > ~/overlay/st7789v-spi1.dts <<'EOF'
/dts-v1/;
/plugin/;

/ {
    fragment@0 {
        target-path = "/";
        __overlay__ {
            backlight: backlight {
                compatible = "gpio-backlight";
                gpios = <&pio 2 7 0>; /* PC7 */
                default-on;
            };
        };
    };

    fragment@1 {
        target = <&spi1>;
        __overlay__ {
            status = "okay";
            #address-cells = <1>;
            #size-cells = <0>;

            display@1 {
                compatible = "sitronix,st7789v";
                reg = <1>;                     /* CS1 on this board, not CS0 */
                spi-max-frequency = <40000000>;
                buswidth = <8>;
                rotate = <90>;
                fps = <60>;
                txbuflen = <32768>;
                reset-gpios = <&pio 2 8 1>;     /* PC8 */
                dc-gpios = <&pio 2 5 0>;        /* PC5 */
                backlight = <&backlight>;
            };
        };
    };
};
EOF

dtc -@ -I dts -O dtb -o ~/overlay/st7789v-spi1.dtbo ~/overlay/st7789v-spi1.dts
sudo cp ~/overlay/st7789v-spi1.dtbo \
    /boot/dtb-$(uname -r)/allwinner/overlay/sun50i-h616-st7789v-spi1.dtbo

if grep -q "^overlays=" /boot/orangepiEnv.txt; then
    sudo sed -i 's/^overlays=.*/overlays=st7789v-spi1/' /boot/orangepiEnv.txt
else
    echo "overlays=st7789v-spi1" | sudo tee -a /boot/orangepiEnv.txt
fi

echo "Setup for screen finished, NOW REBOOT"


