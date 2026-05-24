kind: manual

sources:
- kind: tar
  base-dir: ""
  (?):
  - arch == "x86_64":
      url: github_files:junegunn/fzf/releases/download/v0.73.0/fzf-0.73.0-linux_amd64.tar.gz
      ref: f0e7068285b63163af5276d134b9bc7c37fbbf3a49441fca64ae2df424c2ff8d
  - arch == "aarch64":
      url: github_files:junegunn/fzf/releases/download/v0.73.0/fzf-0.73.0-linux_arm64.tar.gz
      ref: ffec94e3b8cad3b8fc803056c87c90dd4ee8c94d5dfd6b59fb0054d5ad945314

build-depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - |
    install -Dm755 -t "%{install-root}%{bindir}" fzf
  - |
    %{install-extra}
