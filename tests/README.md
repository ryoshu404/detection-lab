# Tests

CI-tier detection tests only. Deterministic, reproducible by anyone, runnable on GitHub-hosted runners with Elasticsearch as a service container.

## Fixtures

`fixtures/<detonation-id>/` is keyed by detonation, not by rule, so sibling rules targeting the same technique test against one shared capture:

```
tests/fixtures/T1003.001-1_2026-08-xx/
    events.ndjson     # captured ECS documents from the detonation window
    mappings.json     # index mapping / component templates, so CI indexes as production does
    labels.yml        # event ids that are true positives (set-equality ground truth)
```

`mappings.json` travels with the events because the test validates query semantics (keyword vs text, case, wildcards), which are properties of the mapping, not the documents. Loading events into a bare index with dynamic mapping would test against field types production doesn't have.

Live validation against the lab SIEM is operational and leaves nothing here.
