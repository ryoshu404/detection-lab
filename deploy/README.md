# deploy

The detection-as-code pipeline: the tooling that takes a Sigma rule from the repo to a running detection in the SIEM, and the CI/CD that runs it.

## Stages

Rules move through five stages, each a module here:

- **validate** — pySigma's own checks (id present, ids unique, valid UUIDv4) plus lab rules: every real detection must carry an ATT&CK technique tag and declare an explicit `alerting` state.
- **compile** — Sigma to ES|QL, or to an importable Detection Engine rule, through the custom `pipelines/lab-ecs.yml` mapping.
- **tag** — reads the rule's `alerting` state and stamps a matching tag onto the compiled rule, plus a `managed-by:detection-lab` ownership tag on everything the pipeline deploys. The Detection Engine has no native non-paging mode, so the alerting tag is what the SOAR layer branches on: a firing during burn-in is logged and closed, a promoted rule's firing creates a case. `enabled` is always true — the rule runs and generates detections throughout.
- **push** — imports to the Detection Engine with `overwrite=true`, so redeploying an existing rule (matched by `rule_id`) updates it in place. This is what makes promotion — flipping the alerting tag and redeploying — work without creating a duplicate.
- **retire** — after push, reconciles the SIEM against the repo: deletes any rule tagged `managed-by:detection-lab` whose source file is gone. The ownership tag makes this safe — rules the pipeline never deployed (prebuilt, hand-made) don't carry it and are never candidates for deletion.

Each stage is a script runnable on its own, and importable by the next. Nothing here needs the SIEM until push; validate and compile are pure and run anywhere.

The ownership tag is injected here rather than declared in the Sigma rule because it's a fact about how the rule was deployed, not a property of the rule — and because pySigma normalizes Sigma tags in ways that would mangle a `key:value` string.

## Credentials

`push.py` and `retire.py` read the SIEM endpoint and key from the environment, never from code:

- `KIBANA_URL`
- `KIBANA_API_KEY` — a scoped Kibana key (Security / detection-rule management only), not a superuser credential

Locally these are shell exports; in CI they are GitHub Actions secrets.

## CI/CD

Two workflows, split on trust:

- **`ci.yml`** runs on pull requests on GitHub-hosted runners, with no lab access and no secrets. It validates and compiles every rule — the gate that must pass before a PR can merge. Safe on untrusted PRs because it never touches the lab.
- **`deploy.yml`** runs on merge to main, on the self-hosted runner inside the lab network. It deploys validated rules to the SIEM and reconciles retirements. It triggers only on push to main — never on pull request — so an untrusted PR can never execute on the runner.

The test tier that loads a captured detonation fixture and asserts the compiled query returns exactly the labelled events is not yet wired into `ci.yml`; the seam is marked in that file.

## Running a stage by hand

```
python deploy/validate.py detections/ --repo-root .
python deploy/compile.py  detections/ -p pipelines/lab-ecs.yml -f default
python deploy/push.py     detections/ -p pipelines/lab-ecs.yml
python deploy/retire.py   detections/ --dry-run
```

`retire.py --dry-run` previews what reconciliation would delete without deleting anything — always the safe first step before a real retirement.
