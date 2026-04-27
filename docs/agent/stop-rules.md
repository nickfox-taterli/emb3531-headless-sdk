# docs/agent/stop-rules.md — When to Stop Instead of Guessing

## Stop Conditions

An agent **must stop and report** instead of proceeding when any of these conditions apply:

1. **Missing documentation**: The task touches a subsystem not covered by any `docs/agent/*.md` file, and the agent cannot find relevant local source to self-educate.
2. **Unsupported subsystem**: The task involves a subsystem explicitly disabled or absent in this SDK (e.g., GPU/DRM, VPU, audio, PCIe, display). See `rk3399-platform.md` for what is disabled.
3. **Missing local API/symbol/binding/example**: The agent needs to reference a kernel API, device-tree property, compatible string, or driver pattern, and it does not exist in the local tree. Do not assume upstream documentation applies without verification.
4. **Unclear patch workflow**: The agent is unsure whether a change should be a `.patch` file, a file copy to `patches/`, or both. Stop and clarify.
5. **Destructive board operation**: The agent is about to execute a command on the target board that modifies partitions, erases storage, or overwrites firmware. Explicit user confirmation is required.
6. **Unrelated subsystem changes**: The agent's proposed change would affect a subsystem not related to the task. Stop and scope the change.
7. **Root cause claim without evidence**: The agent believes it has identified a root cause but has not confirmed it with local source inspection, log output, or test results.
8. **Conflict with hard rules**: The proposed action violates any rule in `CLAUDE.md` (wrong ARCH, editing workspace without patching, committing .agent/, etc.).

## Required Stop Response Format

When stopping, the agent must report:

```
STOP: <one-line summary of what is missing or wrong>

What is missing:    <specific symbol, path, binding, API, or doc>
What was inspected: <list of files, commands, or searches performed>
Assumption needed:  <what the agent would have to assume to proceed>
Proposed next step: <concrete search, test, or question>
Question for user:  <yes/no or short answer question>
```

## Examples

### Example 1: Missing Binding
```
STOP: No YAML binding for rockchip,rk3399-dwc3 in local tree

What is missing:    Documentation/devicetree/bindings/usb/rockchip,rk3399-dwc3.yaml
What was inspected: find Documentation/devicetree/bindings/usb/ -name '*rockchip*'
Assumption needed:  That dwc3 properties follow snps,dwc3.yaml without Rockchip extensions
Proposed next step: Check snps,dwc3.yaml and rk3399.dtsi dwc3 node for required properties
Question for user:  Should I proceed based on snps,dwc3.yaml and the existing DTS node?
```

### Example 2: Destructive Operation
```
STOP: About to erase eMMC on target board

What is missing:    Explicit user confirmation
What was inspected: Target /dev/mmcblk2 partition table
Assumption needed:  That data loss is acceptable
Proposed next step: Ask user to confirm destructive operation
Question for user:  Confirm erasing /dev/mmcblk2 and writing new image via maskrom?
```
