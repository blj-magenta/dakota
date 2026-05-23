kind: manual

sources:
- kind: local
  path: files/firstboot

build-depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - install -Dm644 ublue-boot-timeout.service "%{install-root}/usr/lib/systemd/system/ublue-boot-timeout.service"
  - ln -sf ../ublue-boot-timeout.service "%{install-root}/usr/lib/systemd/system/multi-user.target.wants/ublue-boot-timeout.service"
  - "%{install-extra}"
