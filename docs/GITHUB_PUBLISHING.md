# GitHub source publication runbook

This runbook publishes the source repository. It does not authorize a binary
release, package redistribution, daily-driver claim, or public-alpha
announcement. Those stronger decisions remain governed by
[Public alpha go/no-go](PUBLIC_ALPHA_GO_NO_GO.md) and
[Release operations](RELEASE_OPERATIONS.md).

## Repository metadata

Recommended GitHub values:

- Owner/repository: `lichforge/noctty`
- Description: `Native Zig terminal workspace and companion editor for Linux, Wayland, and X11.`
- Website: leave empty until a maintained project page exists
- Topics: `zig`, `terminal-emulator`, `gtk3`, `wayland`, `x11`, `kde-plasma`, `terminal`, `linux`
- Default branch: `main`
- License detection: MIT (`LICENSE`)
- Issues: enabled
- Discussions: optional; enable only if maintainers will moderate them
- Wiki: disabled while repository documentation is authoritative

## Pre-push source checks

From a clean checkout:

```sh
./scripts/check_public_source_hygiene.sh
gitleaks git --redact
./scripts/public_alpha_verify.sh
git status --short
```

`gitleaks` is a maintainer tool, not a project build dependency. Review every
finding; never suppress a real credential. The bounded alpha gate intentionally
does not replace `./scripts/verify.sh` or display-backed release qualification.
A Pi session may run the full matrix only after the one-shot
`/precommit-matrix` permit.

## Create and push

Create an empty GitHub repository without generated README, license, or
`.gitignore`, then connect this existing history:

```sh
git remote add origin git@github.com:lichforge/noctty.git
git push -u origin main
```

Do not create or push a `v*` tag during source publication: tags activate the
release workflow and imply a separate artifact decision. Do not force-push
public history after contributors begin working unless credential removal
requires it.

## GitHub security settings

Before announcing the repository:

1. Enable **Private vulnerability reporting**. Confirm that
   `https://github.com/lichforge/noctty/security/advisories/new` opens for a
   logged-in reporter.
2. Enable secret scanning and push protection when the organization plan makes
   them available.
3. Enable Dependabot alerts for GitHub Actions and vendored dependency review;
   do not enable unattended dependency merging.
4. Keep workflow permissions read-only by default and disallow Actions from
   approving pull requests.
5. Review deploy keys, webhooks, environments, and installed GitHub Apps; none
   is required for source publication.

## Branch protection

Protect `main` with:

- pull requests required for non-maintainer changes;
- one approving review;
- conversation resolution;
- required `linux-source` and `windows-cross-compile` CI checks;
- force pushes and branch deletion disabled;
- administrator bypass limited to recovery;
- signed commits optional until a documented signing policy exists.

The release workflow has read-only repository permission and uploads workflow
artifacts only. Publishing a GitHub Release, signing artifacts, and approving
redistribution remain explicit maintainer operations.

## Public landing-page review

Before an announcement, verify:

- README status says pre-public/source alpha and does not imply package support;
- screenshots match the current installed build;
- `SECURITY.md`, `SUPPORT.md`, `CONTRIBUTING.md`, and issue links resolve;
- issue labels referenced by templates (`bug`, `enhancement`) exist;
- the current go/no-go blockers are copied into release notes without being
  softened into marketing claims.

Current source publication can be appropriate while the public-alpha
announcement remains no-go. Keep that distinction visible in every post.
