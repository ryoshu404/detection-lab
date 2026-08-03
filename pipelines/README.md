# Pipelines

Custom pySigma processing pipelines for the lab.

`lab-ecs.yml` maps the Sigma `logsource` taxonomy onto the lab's actual data stream names — `logs-aws.cloudtrail-*`, the Sysmon stream, auditd, Defend, Zeek. One pipeline cannot route all sources generically; this is the environment-specific mapping that off-the-shelf tooling does not provide. deploy.py and CI both compile through it, so the same pipeline governs test and deploy.
