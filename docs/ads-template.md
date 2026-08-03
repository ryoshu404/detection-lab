This ADS template is derived from [Lussier's](https://github.com/the2dl/detection-framework) ADS template which was based on Palantir's ADS Template.

# <detection name>

- Rule: `rule.yml` (or `rule.eql`)
- Status: <Testing since YYYY-MM-DD | Live since YYYY-MM-DD | Retired YYYY-MM-DD>
- Author: <handle>
- Date: <YYYY-MM-DD>

## Goal

Purpose of the alert

## MITRE categorization

MITRE ATT&CK TTP that the rule intends to detect

## Source format

SIGMA by default unless native EQL is used for one of two reasons:
- Fidelity: pySigma Elasticsearch backend compiles correlations to clock-aligned DATE_TRUNC buckets rather than a true sliding window, producing false negatives on boundary-straddling events. EQL's `with maxspan` is a real sliding window from the first event.
- Capability: EQL has primitives Sigma correlation lacks which are missing-event detection (`!`) and sequence termination (`until`).

## Detection functionality

High level overview on how the detection works. What it looks for, which telemetry source and events it uses, any enrichment, and the false-positive-minimisation steps built into the logic.

## Blind spots and assumptions

What this detection may miss and why

## False positives

Benign/approved/known activity that this detection may fire on and attempts to minimize them (tuning).

## Validation

Testing of the rule. Detonation stated in `emulation/detonation/` and fixtures at `tests/fixtures/`

## Initial query (ES|QL)

An exploratory query (which in our lab environment will be ES|QL) used to help decide the development of the rule. The query should be broad enough to surface the actual activity but also specific enough to limit the results to the desired activity as best as possible.
