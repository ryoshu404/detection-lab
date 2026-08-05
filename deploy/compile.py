"""Compile Sigma rules to ES|QL queries or importable Detection Engine rules.

output_format:
    "default"          -> ES|QL query string
    "siem_rule_ndjson" -> Detection Engine rule (what push.py imports)

Equivalent to `sigma convert -t esql -p pipelines/lab-ecs.yml`, in code so CI
and deploy share one implementation.
"""

from __future__ import annotations

from pathlib import Path

from sigma.collection import SigmaCollection
from sigma.processing.pipeline import ProcessingPipeline
from sigma.backends.elasticsearch.elasticsearch_esql import ESQLBackend


def load_pipeline(pipeline_path: Path) -> ProcessingPipeline:
    return ProcessingPipeline.from_yaml(pipeline_path.read_text())


def load_rules(path: Path) -> SigmaCollection:
    if path.is_dir():
        return SigmaCollection.load_ruleset([path])
    return SigmaCollection.from_yaml(path.read_text())


def compile_rules(rules_path: Path, pipeline_path: Path, output_format: str = "default") -> list:
    backend = ESQLBackend(processing_pipeline=load_pipeline(pipeline_path))
    return backend.convert(load_rules(rules_path), output_format=output_format)


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Compile Sigma rules via the lab pipeline.")
    parser.add_argument("rules", type=Path, help="Rule file or directory")
    parser.add_argument("-p", "--pipeline", type=Path, required=True)
    parser.add_argument(
        "-f", "--format", default="default",
        choices=["default", "siem_rule", "siem_rule_ndjson", "kibana_ndjson"],
    )
    args = parser.parse_args()

    for output in compile_rules(args.rules, args.pipeline, args.format):
        print(output)
