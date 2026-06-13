kind: manual

# Upstream Nix multi-user release tarball.
#
# Mirrors the brew-tarball.bst pattern: we never extract the archive
# inside the BST sandbox. The archive is staged verbatim under
# /usr/share/dakota-nix/nix.tar.xz, and a oneshot systemd service
# materializes /var/nix/store from it on first boot. /nix is a symlink
# to var/nix (created in oci/layers/bluefin-stack.bst), so the
# hardcoded /nix/store/<hash>-nix-<version>/... paths baked into the
# upstream binaries resolve correctly once the store is copied into
# /var/nix.

sources:
- kind: remote
  (?):
  - arch == "x86_64":
      url: nix_releases:nix-2.34.7/nix-2.34.7-x86_64-linux.tar.xz
      ref: eafe5042404e818505e28c5ca3d0885f3ec45c31f955489a25bb38258f87560e
  - arch == "aarch64":
      url: nix_releases:nix-2.34.7/nix-2.34.7-aarch64-linux.tar.xz
      ref: f1cee64ae7a02330c6421924c28f597c41813f2214ff108622087d8056378b08

build-depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""
  nix-version: "2.34.7"

config:
  install-commands:
  # 1. Stash the upstream tarball verbatim. The firstboot service expands
  #    it into /var/nix.
  - |
    install -d "%{install-root}%{datadir}/dakota-nix"
    mv "nix-%{nix-version}-%{arch}-linux.tar.xz" \
       "%{install-root}%{datadir}/dakota-nix/nix.tar.xz"

  # 2. nixbld build group + 32 build users. Created at boot by
  #    systemd-sysusers, before the firstboot oneshot runs.
  - |
    install -d "%{install-root}%{indep-libdir}/sysusers.d"
    {
      echo '# Dakota Nix multi-user build accounts. Mirrors the upstream'
      echo '# install-multi-user.sh layout (gid 30000, uids 30001..30032).'
      echo 'g nixbld 30000'
      for i in $(seq 1 32); do
        printf 'u nixbld%d %d:nixbld "Nix build user %d" /var/empty /sbin/nologin\n' "$i" "$((30000 + i))" "$i"
      done
    } > "%{install-root}%{indep-libdir}/sysusers.d/dakota-nix.conf"
    chmod 0644 "%{install-root}%{indep-libdir}/sysusers.d/dakota-nix.conf"

  # 3. System-wide nix.conf — multi-user daemon mode + flakes on by default.
  - |
    install -Dm644 /dev/stdin "%{install-root}%{sysconfdir}/nix/nix.conf" <<'EOF'
    build-users-group = nixbld
    experimental-features = nix-command flakes
    EOF

  # 4. /etc/profile.d shim — sources the daemon profile script provided
  #    by the Nix store once it exists.
  - |
    install -Dm644 /dev/stdin "%{install-root}%{sysconfdir}/profile.d/nix.sh" <<'EOF'
    # Dakota: wire user shells into the multi-user Nix daemon profile.
    if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
        . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    fi
    EOF

  # 5. nix-daemon socket — listens on the well-known path under /nix.
  #    Requires the firstboot oneshot so the path is readable/writable.
  - |
    install -Dm644 /dev/stdin "%{install-root}%{indep-libdir}/systemd/system/nix-daemon.socket" <<'EOF'
    [Unit]
    Description=Nix Daemon Socket
    Documentation=man:nix-daemon https://nixos.org/manual
    RequiresMountsFor=/nix/store
    ConditionPathIsReadWrite=/nix/var/nix/daemon-socket
    Requires=dakota-nix-firstboot.service
    After=dakota-nix-firstboot.service

    [Socket]
    ListenStream=/nix/var/nix/daemon-socket/socket

    [Install]
    WantedBy=sockets.target
    EOF

  # 6. nix-daemon service — points at the default profile, which the
  #    firstboot oneshot establishes by symlinking the staged nix store.
  - |
    install -Dm644 /dev/stdin "%{install-root}%{indep-libdir}/systemd/system/nix-daemon.service" <<'EOF'
    [Unit]
    Description=Nix Daemon
    Documentation=man:nix-daemon https://nixos.org/manual
    RequiresMountsFor=/nix/store
    RequiresMountsFor=/nix/var
    RequiresMountsFor=/nix/var/nix/daemon-socket
    ConditionPathIsReadWrite=/nix/var/nix/daemon-socket
    Requires=dakota-nix-firstboot.service
    After=dakota-nix-firstboot.service

    [Service]
    ExecStart=@/nix/var/nix/profiles/default/bin/nix-daemon nix-daemon --daemon
    KillMode=process
    LimitNOFILE=1048576
    TasksMax=1048576
    EOF

  # 7. Firstboot oneshot. Extracts the staged tarball into /var/nix on
  #    first boot, loads the store DB, and points the default profile at
  #    the staged nix package.
  - |
    install -Dm644 /dev/stdin "%{install-root}%{indep-libdir}/systemd/system/dakota-nix-firstboot.service" <<'EOF'
    [Unit]
    Description=Dakota - materialize Nix store on first boot
    Documentation=https://github.com/projectbluefin/dakota
    DefaultDependencies=no
    After=systemd-tmpfiles-setup.service systemd-sysusers.service local-fs.target
    Before=multi-user.target nix-daemon.socket nix-daemon.service
    ConditionPathExists=/usr/share/dakota-nix/nix.tar.xz
    ConditionPathExists=!/var/nix/.dakota-nix-initialized
    RequiresMountsFor=/var

    [Service]
    Type=oneshot
    RemainAfterExit=yes
    ExecStart=/usr/libexec/dakota-nix-firstboot

    [Install]
    WantedBy=multi-user.target
    EOF

  - |
    install -Dm755 /dev/stdin "%{install-root}/usr/libexec/dakota-nix-firstboot" <<'EOF'
    #!/bin/sh
    # Dakota: expand the staged upstream Nix tarball into /var/nix, load
    # the store database, and seed the default profile. Idempotent via a
    # sentinel file under /var/nix.
    set -eu

    SRC=/usr/share/dakota-nix/nix.tar.xz
    DEST=/var/nix
    SENTINEL="${DEST}/.dakota-nix-initialized"

    if [ -e "${SENTINEL}" ]; then
        exit 0
    fi

    install -d -m 0755 "${DEST}"
    install -d -m 1775 -o root -g nixbld "${DEST}/store"
    install -d -m 0755 "${DEST}/var" "${DEST}/var/nix" \
                       "${DEST}/var/nix/db" \
                       "${DEST}/var/nix/profiles" \
                       "${DEST}/var/nix/gcroots" \
                       "${DEST}/var/nix/temproots" \
                       "${DEST}/var/nix/daemon-socket" \
                       "${DEST}/var/log" "${DEST}/var/log/nix" \
                       "${DEST}/var/log/nix/drvs"

    tmp="$(mktemp -d)"
    trap 'rm -rf "${tmp}"' EXIT
    tar -xJf "${SRC}" -C "${tmp}"

    # The tarball's top-level directory is nix-<ver>-<arch>-linux.
    extract="$(echo "${tmp}"/nix-*-linux)"

    # cp -a preserves perms/timestamps required by the store DB.
    # -n keeps any pre-existing entries (re-run safety).
    cp -an "${extract}/store/." "${DEST}/store/"
    cp -a  "${extract}/.reginfo" "${DEST}/.reginfo"

    # Find the nix package dir, e.g. abc123-nix-2.34.7.
    nix_dir="$(find "${DEST}/store" -maxdepth 1 -mindepth 1 -type d \
                    -regextype posix-extended \
                    -regex '.*/[a-z0-9]+-nix-[0-9][^/]*' \
                | sort | head -n1)"
    if [ -z "${nix_dir}" ]; then
        echo "dakota-nix-firstboot: nix package not found in store" >&2
        exit 1
    fi
    nix_hash="$(basename "${nix_dir}")"

    # /nix is a symlink to /var/nix (see oci/layers/bluefin-stack.bst), so
    # the /nix/store/... paths hardcoded into the binaries resolve here.
    NIX_PREFIX="/nix/store/${nix_hash}"

    "${NIX_PREFIX}/bin/nix-store" --load-db < "${DEST}/.reginfo"
    "${NIX_PREFIX}/bin/nix-env" -p "${DEST}/var/nix/profiles/default" \
                                -i "${NIX_PREFIX}"

    touch "${SENTINEL}"
    EOF

  # 8. Enable the daemon socket and firstboot oneshot by preset.
  - |
    install -Dm644 /dev/stdin "%{install-root}%{indep-libdir}/systemd/system-preset/80-dakota-nix.preset" <<'PRESET'
    enable nix-daemon.socket
    enable dakota-nix-firstboot.service
    PRESET

  - |
    %{install-extra}
