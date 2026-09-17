# check-model-impact — Tiến độ 2026-08-13

## Tổng quan

Command `/check-model-impact` (audit) + `/verify-model-impact` (verify) hoàn chỉnh.
Report audit **tiếng Việt**; config `impact-map.md` **tiếng Anh**.

## Spec coverage (4/4)

| # | Yêu cầu | Trạng thái |
|---|---------|-----------|
| 1 | Cross-repo impact analysis | ✅ |
| 2 | Checklist chi tiết per repo/file | ✅ |
| 3 | Tóm tắt migration + rủi ro (không rollout/rollback/deploy order) | ✅ |
| 4 | Post-update verification (`/verify-model-impact`) | ✅ |

## Đã xong

- **Commands**
  - `.claude/commands/check-model-impact.md` — audit, report tiếng Việt
  - `.claude/commands/verify-model-impact.md` — verify, chỉ cần baseline report
- **Skills**
  - `.claude/skills/model-impact-audit/SKILL.md` — 9 bước audit
  - `.claude/skills/model-impact-verify/SKILL.md` — 6 bước verify
- **Config**
  - `repos.md` — repo map, scan_order, deploy_tier (metadata scan)
  - `repo-scan-profiles.md` — domain map, layer tags, action matrix
  - `impact-map.md` — change types, typical risks, confidence (English)
- **Templates**
  - `impact-report.md` — Source change, Migration summary, Risks, findings, Checklist
  - `impact-verify-report.md` — Resolved / Still pending / Not found
- **Docs** `.claude/CLAUDE.md`

## Audit report sections (hiện tại)

1. Source change
2. Migration summary
3. Risks
4. Per-repo findings (Must / Should / Maybe + layer)
5. Checklist
6. Notes

**Không còn:** backward compat plan, rollout, rollback, deployment order.

## Files

| File | Vai trò |
|------|---------|
| `.claude/commands/check-model-impact.md` | Audit entrypoint |
| `.claude/commands/verify-model-impact.md` | Verify entrypoint |
| `.claude/skills/model-impact-audit/SKILL.md` | Audit workflow |
| `.claude/skills/model-impact-verify/SKILL.md` | Verify workflow |
| `.claude/config/repos.md` | Repo map |
| `.claude/config/repo-scan-profiles.md` | Scan profiles |
| `.claude/config/impact-map.md` | Impact rules |
| `.claude/templates/impact-report.md` | Audit layout |
| `.claude/templates/impact-verify-report.md` | Verify layout |

## Lưu ý

- Report cũ (`2026-08-12-*`, `2026-08-13-*`) có thể còn section deploy/strategy — format cũ, không cần sửa retroactively.
- Lần chạy `/check-model-impact` hoặc `/verify-model-impact` mới sẽ theo template hiện tại.
