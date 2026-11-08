# Proposal: <short title>

**Date:** <YYYY-MM-DD>
**Status:** awaiting approval / approved <date> / revised / declined

## Goal

<One or two sentences restating the request in your own words. Be specific enough
that a misunderstanding would be visible here.>

## Approach

<Short paragraph. Name the pattern. Name the existing system this mirrors, with a
file reference.>

## Files

| Path | Change | Intent |
|---|---|---|
| `Assets/...` | new | |
| `Assets/...` | modified | |

## Architecture notes

<Why this shape. The alternative you rejected and why, in one line.>

**Structural changes:** <new assembly reference / changed dependency direction /
new pattern introduced — or "none">

## Risks

- **Serialization:** <affected members by name; count of prefabs/scenes/assets
  referencing them, from an actual search; whether authored data survives — or
  "no serialized members change">
- **Scene/prefab impact:** <which assets, how many>
- **Behaviour:** <what existing behaviour could change>
- **Performance:** <if relevant>

## Editor work implied

<Preview of the handoff checklist so the user can judge the cost before approving.
Rough step count and the nature of the work.>

## Out of scope

<What you noticed and are deliberately not doing. Also recorded in
CURRENT_STATUS.md → Open observations.>
