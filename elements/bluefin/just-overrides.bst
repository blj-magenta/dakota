kind: manual

sources:
- kind: local
  path: files/just-overrides

build-depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

public:
  bst:
    overlap-whitelist:
    - /usr/share/ublue-os/just/default.just
    - /usr/share/ublue-os/just/changelog.just
    - /usr/share/ublue-os/just/system.just

config:
  install-commands:
  - install -Dm644 default.just "%{install-root}/usr/share/ublue-os/just/default.just"
  - install -Dm644 changelog.just "%{install-root}/usr/share/ublue-os/just/changelog.just"
  - install -Dm644 system.just "%{install-root}/usr/share/ublue-os/just/system.just"
  - "%{install-extra}"
