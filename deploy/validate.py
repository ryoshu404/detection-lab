"""Validate rules before compile or deploy.

Three layers: pySigma's own validators (id present, ids unique), lab rules
pySigma can't know (every real rule carries an ATT&CK technique tag), and
schema checks the Detection Engine enforces but pySigma doesn't (id is a valid
UUIDv4, alerting state is declared explicitly). Fixture-to-rule binding is
enforced later, in the set-equality test stage.
"""

from __future__ import annotations

import uuid
from dataclasses import dataclass, field
from pathlib import Path

import yaml

from sigma.collection import SigmaCollection
from sigma.rule import SigmaRule
from sigma.validation import SigmaValidator
from sigma.validators.core.metadata import (
    IdentifierExistenceValidator,
    IdentifierUniquenessValidator,
)

# Throwaway pipeline-bring-up rules opt out of the lab requirements.
# Never used on a real detection.
SMOKE_EXEMPT_TAG = "lab.smoke_test"


@dataclass
class ValidationResult:
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)

    @property
    def ok(self) -> bool:
        return not self.errors

    def merge(self, other: "ValidationResult") -> None:
        self.errors.extend(other.errors)
        self.warnings.extend(other.warnings)


def _pysigma_validation(collection: SigmaCollection) -> ValidationResult:
    result = ValidationResult()
    validator = SigmaValidator(
        validators=[IdentifierExistenceValidator, IdentifierUniquenessValidator]
    )
    for issue in validator.validate_rules(collection.rules):
        title = issue.rule.title if getattr(issue, "rule", None) else "?"
        result.errors.append(f"{title}: {issue}")
    return result


def _is_smoke_exempt(rule: SigmaRule) -> bool:
    return any(str(t) == SMOKE_EXEMPT_TAG for t in rule.tags)


def _has_attack_tags(rule: SigmaRule) -> bool:
    return any(str(t).startswith("attack.t") for t in rule.tags)


def _sigma_lab_validation(collection: SigmaCollection) -> ValidationResult:
    """Checks expressible against the parsed SigmaRule objects."""
    result = ValidationResult()
    for rule in collection.rules:
        if _is_smoke_exempt(rule):
            continue
        if not _has_attack_tags(rule):
            result.errors.append(
                f"{rule.title}: no ATT&CK technique tag (attack.tXXXX)"
            )
    return result


def _raw_schema_validation(rules_path: Path) -> ValidationResult:
    """
    Checks that need the raw YAML — the id string and the `alerting` custom
    field, which pySigma either normalizes or drops. These catch, locally, two
    things the Detection Engine would otherwise reject or silently mishandle at
    push time: a non-v4 UUID (400 on import) and an undeclared alerting state.
    """
    result = ValidationResult()
    files = rules_path.rglob("*.yml") if rules_path.is_dir() else [rules_path]

    for f in files:
        for doc in yaml.safe_load_all(f.read_text()):
            if not isinstance(doc, dict):
                continue
            title = doc.get("title", f.name)
            tags = [str(t) for t in doc.get("tags", []) or []]
            if SMOKE_EXEMPT_TAG in tags:
                continue

            rid = doc.get("id")
            if rid is not None:
                try:
                    if uuid.UUID(str(rid)).version != 4:
                        result.errors.append(f"{title}: id is not a UUIDv4 ({rid})")
                except ValueError:
                    result.errors.append(f"{title}: id is not a valid UUID ({rid})")

            if "alerting" not in doc:
                result.errors.append(
                    f"{title}: no explicit `alerting` field "
                    f"(set false for burn-in, true for promoted)"
                )

    return result


def validate_ruleset(rules_path: Path) -> ValidationResult:
    if rules_path.is_dir():
        collection = SigmaCollection.load_ruleset([rules_path])
    else:
        collection = SigmaCollection.from_yaml(rules_path.read_text())

    result = ValidationResult()
    result.merge(_pysigma_validation(collection))
    result.merge(_sigma_lab_validation(collection))
    result.merge(_raw_schema_validation(rules_path))
    return result


if __name__ == "__main__":
    import argparse
    import sys

    parser = argparse.ArgumentParser(description="Validate Sigma rules before compile/deploy.")
    parser.add_argument("rules", type=Path)
    parser.add_argument("--repo-root", type=Path, default=Path("."))
    args = parser.parse_args()

    res = validate_ruleset(args.rules)
    for w in res.warnings:
        print(f"WARN: {w}")
    for e in res.errors:
        print(f"ERROR: {e}")
    if res.ok:
        print("OK: validation passed")
        sys.exit(0)
    sys.exit(1)
