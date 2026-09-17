# Claude Reports

Generated markdown outputs from shared Claude workflows.

## Conventions

| Mode | Command | Output path |
|------|---------|-------------|
| audit | `/check-model-impact` | `.claude/reports/YYYY-MM-DD-<model>-impact.md` |
| verify | `/verify-model-impact` | `.claude/reports/YYYY-MM-DD-<model>-verify.md` |

Reports are written in **Vietnamese** (prose). Code identifiers (paths, field names, severity labels) stay as-is.

These files are for humans to read and review after the command completes.
