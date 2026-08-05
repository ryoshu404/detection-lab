# deploy

The detection-as-code pipeline: the tooling that takes a Sigma rule from the
repo to a running detection in the SIEM, and the CI/CD that runs it.

## Stages

Rules move through four stages, each a module here:

- **validate** — pySigma's own checks (id present, ids unique) plus a lab rule: every real detection must carry an ATT&CK technique tag.
- **compile** — Sigma to ES|QL, or to an importable Detection Engine rule, through the custom `pipelines/lab-ecs.yml` mapping.
- **burn-in tag** — reads the rule's `alerting` state and stamps a matching tag onto the compiled rule. The Detection Engine has no native non-paging mode, so the tag is what the SOAR layer branches on: a firing during burn-in is logged and closed, a promoted rule's firing creates a case. `enabled` is always true — the rule runs and generates detections throughout.
- **push** — imports to the Detection Engine with `overwrite=true`, so redeploying an existing rule (matched by `rule_id`) updates it in place. This is what makes promotion — flipping the alerting tag and redeploying — work without creating a duplicate.

Each stage is a script runnable on its own, and importable by the next. Nothing here needs the SIEM until push; validate and compile are pure and run anywhere.

## Credentials

`push.py` reads the SIEM endpoint and key from the environment, never from code:

- `KIBANA_URL`
- `KIBANA_API_KEY` — a scoped Kibana key, not a superuser credential

Locally these are shell exports; in CI they are GitHub Actions secrets.

## CI/CD

Two workflows, split on trust:

- **`ci.yml`** runs on pull requests on GitHub-hosted runners, with no lab access and no secrets. It validates and compiles every rule — the gate that must pass before a PR can merge. Safe on untrusted PRs because it never touches the lab.
- **`deploy.yml`** runs on merge to main, on the self-hosted runner inside the lab network. It deploys validated rules to the SIEM. It triggers only on push to main — never on pull request — so an untrusted PR can never execute on the runner.

The test tier that loads a captured detonation fixture and asserts the compiled query returns exactly the labelled events is not yet wired into `ci.yml`; the seam is marked in that file.

## Running a stage by hand

```
python deploy/validate.py detections/ --repo-root .
python deploy/compile.py detections/ -p pipelines/lab-ecs.yml -f default
python deploy/push.py    detections/ -p pipelines/lab-ecs.yml
```
