status=passed
command=LC_ALL=C LANG=C NOCTTY_ZIG_SINGLE_JOB=1 xvfb-run -a ./scripts/verify.sh
reason=Current-source full verification passed Debug/ReleaseSafe terminal compatibility, PTY lifecycle, ncurses/system-TUI, production Cairo renderer and PTY/VT pipeline, NoctEd core/worker/project-index, package/release contracts, documentation truth, native layout, and cleanup. Focused build checks passed 19/19 steps and 313/313 tests, including a clean-source copy; native settings/compact UX and public-alpha X11/available-local-Wayland lanes also passed. This remains local Xvfb/session evidence, not broad compositor, HID, signed-publication, or long-duration proof.
source=local Xvfb and available Wayland maintainer run 2026-07-29
