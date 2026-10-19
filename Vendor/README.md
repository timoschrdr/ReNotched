# Vendored third-party code

`mediaremote-adapter.pl` and `MediaRemoteAdapter.framework` come from
[ungive/mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) (BSD-3-Clause, see
`MediaRemoteAdapter.LICENSE`), pinned to commit `797729d9b16316dc313844476c153d7a107ca0df` (v0.7.7 plus six commits).

- `mediaremote-adapter.pl` is byte-for-byte the upstream script at that commit
  (SHA-256 `d97802e46db9535e2549e178c105ebf417a0254b3929fc32f08ecfd14d49a85f`).
- The framework is built from the same commit by `build-adapter.sh` (arm64, ad-hoc signed). Run the script
  yourself to rebuild it from source instead of trusting the binary in this repository.

ReNotched. runs the script with the system's `/usr/bin/perl`, which is why it can read the now-playing state
on current macOS versions.
