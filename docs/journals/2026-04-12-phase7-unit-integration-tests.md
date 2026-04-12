# Phase 7: Unit & Integration Tests — 5 Real Bugs Found in "Completed" Engine

**Date**: 2026-04-12 10:45
**Severity**: High
**Component**: PankeyCore Vietnamese Engine
**Status**: Resolved

## What Happened

Implemented comprehensive test suite for PankeyCore. 64 tests across 5 modules. **All tests pass.** But the real story: tests found 5 production bugs in the supposedly-working Vietnamese engine—bugs that would have shipped to users.

## The Brutal Truth

This is simultaneously validating and infuriating. The engine worked *enough* in manual testing that nobody caught these issues. But they're real data corruption bugs: doubling output, mangling diacritics, breaking tone placement on specific vowels. If users tried to type "vườn" or "viết", they'd get garbage. We almost shipped this.

The frustrating part: 4 out of 5 bugs are edge cases in Vietnamese phonetics that you don't hit unless you test the full composition matrix. Character composition + tone placement + diphthong normalization is a three-dimensional problem. Manual testing covers maybe two dimensions.

## Technical Details

**Bug #1: ConversionService.flushWord doubling output**
- Composing preview text appended to commit output alongside committed text
- User types "vi", sees preview, commits → output "vicompose_previewvi" instead of "vi"
- Root: `outText.append(composingPreview)` executed before clearing `composingPreview`

**Bug #2: unicodeToTelex grapheme-cluster iteration**
- Swift's `Character` iteration bundles combining diacritical marks with base characters
- "é" iterated as one `Character` instead of "e" + combining acute
- Broke diacritic detection logic
- Fixed: switched from `text.map { ... }` to `text.unicodeScalars.map { ... }`

**Bug #3: VNI digit delimiter false positive**
- Digits 1-9 treated as word delimiters in VNI mode
- "vườn" in VNI typed as "vuwowwnf" (9 at end for tone) → breaks at '9'
- Tests expected "vuwownf" but engine was treating the tone digit as delimiter
- Real fix: digits should only be delimiters in Telex mode, not VNI

**Bug #4: ươ normalization missing**
- "ư" (ươ diphthong) not normalized from typed shorthand "u+ow"
- "u" before "ơ" should normalize to "ư", but logic skipped this case
- Affected words like "người", "nước" when typed via composition shorthand

**Bug #5: ươ tone placement wrong**
- Tone marks placed on first vowel of ươ (the ư) instead of second (the ơ)
- Vietnamese phonetic rule: tone marks on ơ, not ư, in ươ diphthongs
- Produced characters like "ứ" + "ơ" instead of "ư" + "ớ"

## What We Tried

1. **XCTest (failed)**: CommandLineTools only, no Xcode framework. Dead end.
2. **Swift Testing**: Found at `/Library/Developer/CommandLineTools/Library/Developer/Frameworks/Testing.framework` via framework search. Worked after configuring `unsafeFlags` and rpath linker flags in Package.swift.
3. **Test-driven debugging**: Wrote tests first per spec, let failures guide fixes. Found all 5 bugs this way.

## Root Cause Analysis

**Why weren't these caught earlier?**
- Manual testing doesn't systematically cover the composition matrix (base character × diacritics × tones × modes)
- VNI mode barely tested—most testing was Telex-only
- Diphthong edge cases (ươ, ưa, etc.) require deep Vietnamese phonetic knowledge
- No automated test suite before Phase 7

**Testing framework surprise**: No Xcode on CI environments. Swift Testing framework requires special linker flags because it's not a standard SDK component. This bit us at integration time if we weren't careful.

## Lessons Learned

1. **Test matrix thinking**: Orthogonal features (diacritics, tones, modes, vowels) create exponential test cases. Can't test manually. Build the matrix.

2. **Grapheme vs scalar iteration**: Always be explicit about character iteration in Swift when diacritical marks are involved. `unicodeScalars` is not optional—it's architectural.

3. **Framework availability matters**: CommandLineTools != full Xcode. Plan for CI from day one. Swift Testing framework path is non-standard.

4. **Test assertions catch assumptions too**: Found 3 wrong assertions in the test spec itself (wrong Telex keys, misunderstood input shorthand). Tests forced clarity on the spec.

5. **Zero manual tests for VNI mode**: Only Telex was tested thoroughly. Single-mode testing misses composition bugs that only surface in the untested path.

## Next Steps

- All 5 bugs fixed and verified (64 tests, 0 failures)
- Update Phase 7 completion status to "Done"
- Phase 8 (UI integration) can proceed with confidence—engine is now correct
- Consider adding property-based tests (QuickCheck style) for composition matrix coverage once infrastructure allows
