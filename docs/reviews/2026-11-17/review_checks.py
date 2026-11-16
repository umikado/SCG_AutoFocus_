"""Synthetic specification review examples; not Swift or device acceptance tests."""

import hashlib
import json
import math
from pathlib import Path


def spec_cache_key(audio, segment, engine_id, model_version):
    payload = [audio, segment, engine_id, model_version]
    return hashlib.sha256(json.dumps(payload).encode()).hexdigest()


def main():
    results = []

    # Identity chunk processing: a constant signal should reconstruct to one.
    size = 1024
    hop = size * 3 // 4
    window = [0.5 - 0.5 * math.cos(2 * math.pi * n / size) for n in range(size)]
    weight_sums = [
        sum(window[t - k * hop] for k in range(-4, 5) if 0 <= t - k * hop < size)
        for t in range(hop)
    ]
    lo, hi = min(weight_sums), max(weight_sums)
    assert math.isclose(lo, 1 - math.sqrt(0.5), abs_tol=1e-12)
    assert hi == 1.0
    results.append({"check": "hann_25_percent_overlap_without_normalization",
                    "min_window_sum": lo, "max_window_sum": hi,
                    "ripple_db": 20 * math.log10(hi / lo)})

    reconstructed = [value / weight for value, weight in zip(weight_sums, weight_sums)]
    assert all(math.isclose(x, 1.0, abs_tol=1e-12) for x in reconstructed)
    results.append({"check": "normalized_identity_interior", "max_error": max(abs(x - 1) for x in reconstructed),
                    "limitation": "Interior only; finite-stream edge policy still requires implementation tests."})

    lyrics = ["chorus", "verse", "chorus"]
    candidates = [i for i, text in enumerate(lyrics) if text == "chorus"]
    literal_relative_comparison = abs(0 - 0) < 0.05 * 0
    assert candidates == [0, 2] and not literal_relative_comparison
    results.append({"check": "zero_cost_repeated_chorus", "exact_candidates": candidates,
                    "literal_five_percent_of_best_detects_tie": literal_relative_comparison})

    # Options cannot affect a key whose specified inputs do not contain them.
    requests = [{"language": "en", "prompt": "synthetic alpha"},
                {"language": "ja", "prompt": "synthetic beta"}]
    keys = [spec_cache_key("synthetic-audio", [30, 60], "whisper", "1") for _ in requests]
    assert keys[0] == keys[1] and requests[0] != requests[1]
    results.append({"check": "spec_asr_cache_omits_language_and_prompt", "same_key": True})

    segment = (30.0, 60.0)
    cases = [((29.8, 31.0), (0.0, 1.0)), ((59.8, 60.5), (29.8, 30.0))]
    for cue, expected in cases:
        clipped = (max(cue[0], segment[0]) - segment[0], min(cue[1], segment[1]) - segment[0])
        assert all(math.isclose(a, b, abs_tol=1e-12) for a, b in zip(clipped, expected))
    results.append({"check": "clip_intersection_before_offset", "cases": len(cases)})

    segment_start, padding, dtw_ticks = 30.0, 1.0, 150
    decoded_start = max(0, segment_start - padding)
    absolute = decoded_start + dtw_ticks * 0.01
    assert absolute == 30.5
    assert segment_start + dtw_ticks * 0.01 == 31.5
    results.append({"check": "dtw_10ms_units_and_decoded_origin", "absolute_seconds": absolute,
                    "wrong_segment_origin_seconds": 31.5})

    output = {"status": "passed", "checks": len(results),
              "scope": "Synthetic arithmetic and contract counterexamples only; no application or device tests.",
              "results": results}
    destination = Path(__file__).with_name("review-check-results.json")
    destination.write_text(json.dumps(output, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(output, indent=2))


if __name__ == "__main__":
    main()
