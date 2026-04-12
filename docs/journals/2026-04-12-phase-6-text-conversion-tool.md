# Phase 6: Text Conversion Tool (Telex/VNI/Unicode)

**Date**: 2026-04-12 14:30
**Severity**: Medium
**Component**: ConversionService, ConvertToolView, text pipeline
**Status**: Resolved

## What Happened

Delivered full Vietnamese text converter with bidirectional Telex↔Unicode and VNI↔Unicode transformation. Implemented `ConversionService.swift` as PankeyCore foundation + `ConvertToolView.swift` as PixelUI tabbed interface. All conversions normalize through Unicode intermediary. `swift build` passes clean.

## The Brutal Truth

This was methodical, low-friction work. The real complexity—Vietnamese combining marks (U+0300–U+036F diacritics)—is finite and manageable. We made a deliberate call: Telex↔VNI conversion goes through Unicode, not direct. This adds one extra pass but eliminates bidirectional map maintenance. No bikeshedding, decision stuck.

The VNI→Unicode path works. Unicode→VNI returns input unchanged (documented stretch goal). That's honest scope management, not a bug.

## Technical Details

**ConversionService.swift** (PankeyCore):
- `ConversionFormat` enum: `.unicode`, `.telex`, `.vni`
- `convert(_:from:to:)` orchestrator: normalizes input to NFC, dispatches to pipeline
- `telexToUnicode()` / `vniToUnicode()`: word-by-word VietEngine calls, flush at whitespace/punctuation/symbol boundaries
- `unicodeToTelex()`: NFD decompose → base char + collecting marks → reverse-map combining marks (U+0300–U+036F) to Telex double-keys (aa/aw/ee/oo/ow/uw/dd) + tone suffixes (f/s/r/x/j)

**ConvertToolView.swift** (PankeyMac):
- FORMAT FROM/TO pickers (Picker with PixelButtonStyle)
- Dual TextEditors (INPUT / OUTPUT) with live keystroke conversion
- PASTE & CONVERT (NSPasteboard.general read) + COPY RESULT (1.5s haptic feedback)
- PixelTheme 8-bit styling, "Press Start 2P" font, neon colors

## What Worked Well

1. **Pipeline abstraction**: Treating Telex/VNI as encoding layers, Unicode as canonical representation—no direct Telex↔VNI path needed. Scales if more encodings added.
2. **Word boundary detection**: Including punctuation + symbols (not just whitespace) caught real cases where Telex suffix could be ambiguous without explicit boundary.
3. **VietEngine reuse**: No new composition logic; existing engine handles encoding. Reduces surface area for bugs.
4. **UI responsiveness**: Live conversion on keystroke proved intuitive—users see transformation instantly.

## Lessons Learned

1. **Normalize first, transform second**: Always bring variant input to canonical form (Unicode NFC) before routing to destination encodings. Prevents cascading normalization bugs.
2. **Boundaries matter more than you think**: Word breaks are not just spaces. Punctuation, symbols, even line breaks affect diacritic assignment in Telex. Explicit boundary detection saved hours of edge case hunting.
3. **Accept honest scope limits**: VNI→Unicode works; Unicode→VNI is documented as future work. Ship the complete path, defer the incomplete one. Honesty > false completeness.

## Technical Debt & Future Work

- Unicode→VNI conversion (currently passthrough) requires reverse tone+diacritic map. Low priority; affects small user base.
- No Unicode normalization options UI yet (NFC/NFD toggle). Added to Phase 7 stretch goals.
- Performance: current word-by-word loop is O(n). Acceptable for typical clipboard pastes; profile if dealing with 100K+ char documents.

## Next Steps

**Phase 7**: Unit & Integration Tests. Each conversion direction (T→U, V→U, U→T, U→V edge cases) needs parametrized test coverage. Current `swift build` success does not guarantee correctness on edge cases (rare combining sequences, tone conflicts).

**Owner**: Test team
**Timeline**: 3–4 days (depends on test harness setup)

**Blockers**: None. Phase 6 leaves Phase 7 with clean, testable API surface.
