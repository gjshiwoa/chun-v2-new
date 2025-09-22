本项目请始终用中文跟用户交流。

# Repository Guidelines

## Project Structure & Module Organization
- Root contains an OptiFine/Iris shaderpack. Key folders:
  - lib/ reusable GLSL modules (e.g., camera/, lighting/, water/, tmosphere/). Include via #include "lib/camera/toneMapping.glsl".
  - program/ pass entry points (composite*.glsl, deferred*.glsl, gbuffers_*.glsl, shadow.glsl) and per-dimension overrides under program/world_1 and program/world__1.
  - world-1/, world0/, world1/ classic per-dimension overrides (Nether, Overworld, End) for compatibility.
  - *.properties, lang/ pack configuration and localization.

## Development, Build & Test
- No build step; files are loaded directly by the game.
- Use Iris or OptiFine. Reload by toggling the shaderpack or using the in-game reload control.
- For quick iteration, focus on a single pass (e.g., edit program/deferred.glsl) and verify in a test world.
- Check the game log for compile errors: .minecraft/logs/latest.log.

## Coding Style & Naming
- Indentation: 4 spaces, no tabs; keep lines under ~120 chars.
- Functions/variables: camelCase (waterReflectionRefraction, exposureCurve). Constants/macros: UPPER_SNAKE_CASE.
- Prefer small, pure helpers in lib/**; keep pass files focused on orchestration.
- Guard features with #ifdef options; default-safe values in lib/settings.glsl and shaders.properties.

## Testing Guidelines
- Verify across dimensions and conditions: Overworld/Nether/End, day/night, rain/fog, underwater.
- Compare visuals and performance (FPS) before/after. Watch for halos, NaNs, banding, flicker, or temporal ghosts.
- Run with common post options on/off (TAA, SSAO, Bloom) to ensure graceful degradation.

## Commit & Pull Request Guidelines
- Commits: imperative, scoped. Example: lib/water: clamp caustics intensity or program/deferred: fix normal decode.
- PRs: describe intent, affected passes, toggles introduced/renamed, and risks. Include before/after screenshots and FPS deltas. Reference related issues.

## Configuration Tips
- Avoid breaking existing option names/semantics. Deprecate with compatibility shims when possible.
- Keep heavy paths behind toggles; add comments where cost is non-obvious.
- Clamp, saturate, and validate inputs to avoid artifacts and driver-specific issues.
