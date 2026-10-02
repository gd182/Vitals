# Release Checklist

Source publication and distributing a ready-to-install application are separate steps.
Do not treat the unsigned CI build as a signed public release.

## Repository

- Commit the app changes, tests, and publication files as focused groups.
- Build and test the committed revision from a clean checkout; ensure newly
  added Swift files and screenshots are included.
- Check the working tree and all reachable history for secrets. A filename or
  regex check is only a preliminary check, not a complete security audit.
- Confirm rights and attribution for code, icons and other included assets.
- Keep MIT in LICENSE and both README files; verify screenshot paths and links.
- Let the first GitHub Actions run pass. CI selects Xcode 26.2 on macos-15;
  update the pin deliberately when runner images change.
- Configure repository description/topics and, when available, private
  vulnerability reporting and branch protection. These are GitHub settings,
  not files that this checklist can enable.

## Manual Verification

- Fresh first launch; finish setup, restart and reopen setup from settings.
- CPU/RAM/GPU modules, the last-module guard, opening/closing/reopening panels.
- Compact/spacious layouts, both widths, section visibility/order/reset,
  long process names, charts, custom palette and palette reset.
- Light/dark/system themes and all three localizations.
- Background/foreground intervals, sleep/wake and closing all windows.
- Actual Intel and Apple Silicon Macs where possible; document the tested
  model/macOS combinations and known missing metrics without extrapolating.
- macOS 14.6 runtime compatibility on a real supported system where available.

## Application Distribution

- Set MARKETING_VERSION and increment CURRENT_PROJECT_VERSION for the release.
- Archive with the intended Developer ID identity and appropriate hardened
  runtime settings; verify native hardware collection with the signed build.
- Sign and notarize the distribution using Apple's documented workflow,
  attach the notarization ticket where applicable, and test Gatekeeper behavior
  on a different Mac with the downloaded artifact.
- Do not ask users to globally disable Gatekeeper.
- Confirm the executable contains arm64 and x86_64 with `lipo -verify_arch`.
- Include the MIT license in the distribution and publish a ZIP or DMG with
  a SHA-256 checksum, installation instructions and known limitations.
- Tag the tested commit and write release notes describing changes and tested
  hardware. Never upload signing certificates or credentials to the repository.

References:
- [Apple: packaging Mac software](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution)
- [Apple: notarization](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [GitHub macOS runner toolchains](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-Readme.md)
