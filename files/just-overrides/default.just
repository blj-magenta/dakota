# vim: set ft=make :
# These are convenience shortcuts, they should not be specific to a desktop, aimed to be rather generic things for both Aurora and Bluefin

uid := `id -u`
shell := `grep :$(id -u): /etc/passwd | cut -d: -f7`

# Boot into this device's BIOS/UEFI screen
bios:
    #!/usr/bin/bash
    if [ ! -d /sys/firmware/efi ]; then
      echo "Rebooting to legacy BIOS from OS is not supported."
      exit 1
    fi

    if gum confirm "Reboot into BIOS?" ; then
      systemctl reboot --firmware-setup
    fi

# Show BIOS info
bios-info:
    #!/usr/bin/bash
    sudo bash <<'EOF'
    echo "Manufacturer: $(dmidecode -s baseboard-manufacturer)"
    echo "Product Name: $(dmidecode -s baseboard-product-name)"
    echo "Version: $(dmidecode -s bios-version)"
    echo "Release Date: $(dmidecode -s bios-release-date)"
    EOF

clean-system:
    #!/usr/bin/bash
    if gum confirm "Prune all Podman images and volumes?"; then
        podman image prune -af
        podman volume prune -f
    fi

    if command -v docker >/dev/null 2>&1; then
      if gum confirm "Prune all Docker images and volumes?"; then
        docker image prune -af
        docker volume prune -f
      fi
    fi

    flatpak uninstall --unused
    if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
        brew autoremove
        brew cleanup
    fi

# Show all messages from this boot
logs-this-boot:
    sudo journalctl --no-hostname -b 0

# Show all messages from last boot
logs-last-boot:
    sudo journalctl --no-hostname -b -1

# Enroll Nvidia driver & KMOD signing key for secure boot - Enter password "universalblue" if prompted
enroll-secure-boot-key:
    #!/usr/bin/bash
    ENROLLMENT_PASSWORD="universalblue"
    sudo bash <<EOF
    mokutil --timeout -1
    echo -e "$ENROLLMENT_PASSWORD\n$ENROLLMENT_PASSWORD" | mokutil --import "/etc/pki/akmods/certs/akmods-ublue.der"
    EOF
    echo 'At next reboot, the mokutil UEFI menu UI will be displayed (*QWERTY* keyboard input and navigation).\nThen, select "Enroll MOK", and input "universalblue" as the password'

# Toggle display of the user-motd in terminal
toggle-user-motd:
    #!/usr/bin/bash
    if [ -e "${HOME}/.config/no-show-user-motd" ] ; then
      if gum confirm "Would you like to enable the MOTD?" ; then
        rm -f "${HOME}/.config/no-show-user-motd"
        echo "MOTD will now be shown on login."
        exit 0
      fi
    fi
    if gum confirm "Would you like to disable the MOTD?" ; then
      mkdir -p "${HOME}/.config"
      touch "${HOME}/.config/no-show-user-motd"
      echo "MOTD will not be shown anynow"
      exit 0
    fi

# Check for local overrides
check-local-overrides:
    #!/usr/bin/bash
    RESET="\x1b[0m"
    if [ "${NO_COLOR}" == 1 ]; then
        BLUE_COLOR=""
        GREEN_COLOR=""
        YELLOW_COLOR=""
    else
        BLUE_COLOR="${BLUE_COLOR:-\x1b[38;5;117m}"
        GREEN_COLOR="${GREEN_COLOR:-\x1b[38;5;85m}"
        YELLOW_COLOR="${YELLOW_COLOR:-\x1b[93m}"
    fi

    diff -qr \
      --suppress-common-lines \
      --color="always" \
      --exclude "passwd*" \
      --exclude "group*" \
      --exclude="subgid*" \
      --exclude="subuid*" \
      --exclude="machine-id" \
      --exclude="adjtime" \
      --exclude="fstab" \
      --exclude="system-connections" \
      --exclude="shadow*" \
      --exclude="gshadow*" \
      --exclude="ssh_host*" \
      --exclude="cmdline" \
      --exclude="crypttab" \
      --exclude="hostname" \
      --exclude="localtime" \
      --exclude="locale*" \
      --exclude="*lock" \
      --exclude=".updated" \
      --exclude="*LOCK" \
      --exclude="vconsole*" \
      --exclude="00-keyboard.conf" \
      --exclude="grub" \
      --exclude="system.control*" \
      --exclude="cdi" \
      --exclude="default.target" \
      /usr/etc /etc 2>/dev/null | sed \
          -e '/Binary\ files\ /d ; /Common subdirectories/d' \
          -e "/Files/ s/^/${BLUE_COLOR}&/g" \
          -e "/Files/ s/\$/&${RESET}/g" \
          -e "/Only in/ s/^/${GREEN_COLOR}&/g" \
          -e "/Only in/ s/\$/&${RESET}/g" \
          -e "s/\:.*/${RESET}${YELLOW_COLOR}&${RESET}/g"

# Collect a privacy-respecting diagnostic report and upload to your GitHub gist.
# The gist is yours — you can view, share, or delete it any time.
# ujust report
report:
    #!/usr/bin/bash
    set -euo pipefail

    REPORT_DIR="$(mktemp -d /tmp/ujust-report-XXXXXX)"
    OTEL_CONFIG=""
    cleanup() {
        rm -rf "$REPORT_DIR"
        [[ -n "$OTEL_CONFIG" ]] && rm -f "$OTEL_CONFIG"
    }
    trap cleanup EXIT

    # ── Pre-OTel: collect command-based data ─────────────────────────────────

    echo "Collecting system information..."

    BOOTC_JSON=$(sudo bootc status --json 2>/dev/null || echo '{}')
    BOOTED_IMAGE=$(echo "$BOOTC_JSON" | jq -r '.status.booted.image.image.image // "unknown"')
    BOOTED_DIGEST=$(echo "$BOOTC_JSON" | jq -r '.status.booted.imageDigest // "unknown"')
    STAGED_IMAGE=$(echo "$BOOTC_JSON" | jq -r '.status.staged.image.image.image // "none"')

    GNOME_VERSION=$(gnome-shell --version 2>/dev/null || echo "unknown")
    GNOME_EXTENSIONS=$(gnome-extensions list --enabled 2>/dev/null || echo "")

    FLATPAK_LIST=$(flatpak list --columns=application,version 2>/dev/null || echo "unavailable")

    LOAD_AVG=$(awk '{print $1", "$2", "$3}' /proc/loadavg)
    MEM_INFO=$(free -h --si | awk '/^Mem:/{print $3" used / "$2" total"}')
    FAILED_UNITS=$(systemctl list-units --state=failed --no-legend --plain 2>/dev/null \
                   | awk '{print $1}' | head -20 || echo "")
    KERNEL_VER=$(uname -r)

    # Scrub /home/<user>/ paths from collected strings
    FLATPAK_LIST=$(echo "$FLATPAK_LIST" | sed -E 's|/home/[^/[:space:]]+/|/home/<redacted>/|g')
    GNOME_EXTENSIONS=$(echo "$GNOME_EXTENSIONS" | sed -E 's|/home/[^/[:space:]]+/|/home/<redacted>/|g')

    # ── OTel phase: collect deep system telemetry ────────────────────────────

    echo "Collecting system telemetry (35 seconds)..."

    OTEL_CONFIG="$(mktemp /tmp/ujust-report-otel-XXXXXX.yaml)"
    sed "s|/output/|${REPORT_DIR}/|g" \
        /usr/share/ublue-os/just/otel/ujust-report-config.yaml > "$OTEL_CONFIG"

    OTELCOL_BINARY=""
    for candidate in \
        "$HOME/.local/bin/otelcol-contrib" \
        "/usr/local/bin/otelcol-contrib" \
        "$(command -v otelcol-contrib 2>/dev/null || true)"; do
        if [[ -n "$candidate" && -x "$candidate" ]]; then
            OTELCOL_BINARY="$candidate"
            break
        fi
    done

    if [[ -n "$OTELCOL_BINARY" ]]; then
        timeout 35 "$OTELCOL_BINARY" --config "$OTEL_CONFIG" 2>/dev/null || true
    elif command -v podman &>/dev/null; then
        timeout 45 podman run --rm --privileged \
            --network=host \
            -v /var/log/journal:/var/log/journal:ro \
            -v /run/log/journal:/run/log/journal:ro \
            -v "${OTEL_CONFIG}:/etc/otelcol/config.yaml:ro" \
            -v "${REPORT_DIR}:/output" \
            docker.io/otel/opentelemetry-collector-contrib@sha256:a2a52e43c1a80aa94120ad78c2db68780eb90e6d11c8db5b3ce2f6a0cc6b5029 \
            2>/dev/null || true
    else
        echo "Warning: otelcol-contrib not found and podman unavailable."
        echo "         Deep telemetry omitted from report."
    fi

    # ── Build summary.md ─────────────────────────────────────────────────────

    TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    HOST_ID=$(head -c 8 /etc/machine-id 2>/dev/null || echo "unknown")
    ARCH=$(uname -m)

    {
    cat <<SUMMARY
## Bluefin/Dakota Diagnostic Report
Generated: ${TIMESTAMP}
Anonymous device ID: ${HOST_ID} (truncated)

### System
* Kernel: ${KERNEL_VER}
* Architecture: ${ARCH}
* Load average (1/5/15 min): ${LOAD_AVG}
* Memory: ${MEM_INFO}

### Booted Image
* Image: ${BOOTED_IMAGE}
* Digest: ${BOOTED_DIGEST}
* Staged: ${STAGED_IMAGE}

### GNOME
* Version: ${GNOME_VERSION}
* Active extensions:
SUMMARY
    if [[ -n "$GNOME_EXTENSIONS" ]]; then
        echo "$GNOME_EXTENSIONS" | sed 's/^/  - /'
    else
        echo "  (none)"
    fi
    cat <<SUMMARY

### Failed Systemd Units
SUMMARY
    if [[ -n "$FAILED_UNITS" ]]; then
        echo "$FAILED_UNITS" | sed 's/^/  - /'
    else
        echo "  None"
    fi
    cat <<SUMMARY

### Installed Flatpaks
\`\`\`
${FLATPAK_LIST}
\`\`\`

### Full Telemetry
See \`report.otlp.json\` in this gist for structured OTel metrics and journal logs.
SUMMARY
    } > "$REPORT_DIR/summary.md"

    # ── Upload ────────────────────────────────────────────────────────────────

    echo ""
    echo "Report ready:"
    echo "  $REPORT_DIR/summary.md"
    [[ -f "$REPORT_DIR/report.otlp.json" ]] && echo "  $REPORT_DIR/report.otlp.json"
    echo ""

    if ! gum confirm "Upload diagnostic report to your GitHub gist?"; then
        echo "Upload cancelled. Files saved to: $REPORT_DIR"
        trap - EXIT
        exit 0
    fi

    if ! gh auth status --active &>/dev/null; then
        echo ""
        echo "gh is not authenticated. Files saved locally:"
        echo "  $REPORT_DIR/"
        echo ""
        echo "To upload manually:"
        echo "  gh gist create --public --desc 'Bluefin diagnostic report' \\"
        echo "    $REPORT_DIR/summary.md $REPORT_DIR/report.otlp.json"
        trap - EXIT
        exit 0
    fi

    GIST_FILES=("$REPORT_DIR/summary.md")
    [[ -f "$REPORT_DIR/report.otlp.json" ]] && GIST_FILES+=("$REPORT_DIR/report.otlp.json")

    GIST_URL=$(gh gist create --public \
        --desc "Bluefin diagnostic report $(date -I)" \
        "${GIST_FILES[@]}")

    echo ""
    echo "✅ Report uploaded: $GIST_URL"
    echo ""
    echo "To file an issue:"
    echo "  1. Open: https://github.com/projectbluefin/dakota/issues/new"
    echo "  2. Describe the problem in your own words at the top"
    echo "  3. Paste this gist URL: $GIST_URL"
    echo "  4. Add label: agent-ready"

# Deprecated alias for ujust report.
device-info:
    #!/usr/bin/bash
    echo ""
    echo "⚠️  'ujust device-info' has been renamed to 'ujust report'."
    echo "    Running 'ujust report' now..."
    echo ""
    just report

# Measure Idle Power Draw
check-idle-power-draw:
    #!/usr/bin/bash
    if ! command -v powerstat ; then
        echo "Powerstat is not available"
        exit 1
    fi
    sudo powerstat -a -r

# Run a one minute system benchmark
[group('System')]
benchmark:
    #!/usr/bin/env bash
    if ! command -v "stress-ng" ; then
        if gum confirm "Stress does not seem to be on your path, do you wish to install it?" ; then
            set -eu
            brew install stress-ng
            brew link stress-ng
            set +eu
        else
            exit 0
        fi
    fi

    echo "Running a 1 minute benchmark ..."
    trap popd EXIT
    pushd "$(mktemp -d)"
    stress-ng --matrix 0 -t 1m --times
