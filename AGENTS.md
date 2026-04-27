# AGENTS.md — Generic Agent Entry Point

This repository is the EMB3531 RK3399 Headless Server SDK.

**Start here**: Read `CLAUDE.md` for hard rules and documentation routing.

## Summary of Hard Rules

- Target: RK3399 ARM64. Always `ARCH=arm64` for kernel.
- Cross-compiler: `CROSS_COMPILE=aarch64-linux-gnu-`.
- `workspace/` is local, non-persistent, git-ignored.
- Persistent changes go in `patches/`.
- Read `sdk.sh` before inventing commands.
- Do not guess — stop and report if local source is missing. See `docs/agent/stop-rules.md`.
- Do not commit `.agent/`.
