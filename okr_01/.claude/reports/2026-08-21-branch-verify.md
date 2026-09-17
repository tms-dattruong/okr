# Branch — Báo cáo verify

## Nguồn (Source)

- Model: `Branch`, `CompanyUserBranch`, `Department` (thêm `branch_id`)
- Migration: `ha-speaking-api/src/app/migrations/versions/5b3548f846a2_create_branches_table.py`
- Baseline report: `.claude/reports/2026-08-21-branch-impact.md`
- Verified at: `2026-08-21`

## Tóm tắt (Summary)

- Resolved: `0` / `2`
- Still pending: `2`
- Not found: `0`
- New findings: `0`

## Resolved

*(không có)*

## Still pending

- `ha-speaking-admin-web/src/tests/`
  - old ref found: không có thư mục `src/tests/branch/` hoặc `src/tests/department/` — vẫn giữ nguyên như baseline
  - suggested action: bổ sung test cho `branch_check.py`, `branch_repository.py`, và luồng department yêu cầu `branch_id` bắt buộc (department register/edit)

- `ha-speaking-company-web/src/tests/`
  - old ref found: `src/tests/` vẫn chỉ có `home/`, `talk_history/` — chưa có test cho logic `BRANCH_MANAGER`
  - suggested action: bổ sung test cho `UserRepositoryImpl.get_department_ids` (nhánh `BRANCH_MANAGER`) và context processor resolve department theo branch trong `src/app/__init__.py`

## Not found

*(không có)*

## New findings

không có

## Ghi chú (Notes)

- Baseline không có finding `Must update` — migration chỉ bắt kịp code (`Branch`, `CompanyUserBranch`, `Department.branch_id`, role `BRANCH_MANAGER`) đã được implement sẵn ở `ha-speaking-admin-web` và `ha-speaking-company-web` từ trước.
- 2 mục `Should verify` trong baseline đều là thiếu test tự động — chưa thấy thay đổi nào (thư mục test vẫn như cũ), đề nghị dev bổ sung trước khi coi checklist hoàn tất.
- Mục `Optional checks` (company-web tự quản lý `Branch`) không nằm trong phạm vi verify này — vẫn chờ xác nhận PM như baseline đã ghi.
- Save: `.claude/reports/2026-08-21-branch-verify.md`
