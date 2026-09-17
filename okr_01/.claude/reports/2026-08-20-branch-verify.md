# Branch — Báo cáo verify

## Nguồn (Source)

- Model: `Branch`
- Baseline report: `.claude/reports/2026-08-19-branch-impact.md`
- Verified at: 2026-08-20

## Tóm tắt (Summary)

- Resolved: `0` / `6`
- Still pending: `6`
- Not found: `0`

## Resolved

_Không có finding nào được resolve trong lần re-scan này._

## Still pending

- `ha-speaking-api/src/app/db/db_models.py` `[layer: entity]`
  - old ref found: `CompanyUser.branches` (dòng ~620) khai `back_populates="company_users"`, nhưng class `Branch` (dòng ~627–641) vẫn chỉ có `company`, `departments` — chưa có thuộc tính `company_users`
  - suggested action: thêm `company_users = relationship("CompanyUser", secondary="company_user_branches", back_populates="branches")` vào class `Branch`. Đây là bug nghiêm trọng nhất trong baseline — sẽ làm SQLAlchemy lỗi `InvalidRequestError` khi configure mapper, ảnh hưởng toàn app.

- `ha-speaking-admin-web/src/app/templates/admin/company_user/edit.html` `[layer: template]`
  - old ref found: form vẫn chỉ có `department_ids_wrapper`; không có `branch_ids_wrapper`, không fetch `branch_managers_by_company`, không hidden input `branch_ids`
  - suggested action: thêm UI chọn nhiều branch giống `register.html` — wrapper hiện khi `role == 3` (`BRANCH_MANAGER`), chip + hidden `branch_ids`, prefill từ `company_user.branches`

- `ha-speaking-admin-web/src/app/services/company_user/company_user.py` (`update_company_user`, dòng ~313–378) `[layer: service]`
  - old ref found: route chỉ đọc `department_ids = request.form.getlist("department_ids")`; không đọc `branch_ids`; gọi `company_user_repo.update_company_user(...)` không truyền `branch_ids`
  - suggested action: đọc `branch_ids = request.form.getlist("branch_ids")` khi `role == CompanyUserRoleEnum.BRANCH_MANAGER.value`, truyền vào `update_company_user(...)` giống flow `create_company_user` (đã làm đúng, dòng ~293–295)

- `ha-speaking-admin-web/src/app/db/repositories/company_user/company_user_repository.py` (`update_company_user`, dòng ~215–246) `[layer: repo]`
  - old ref found: signature vẫn chỉ nhận `department_ids=None`, không có tham số `branch_ids`; thân hàm không gọi `self.set_branches_for_company_user(...)`
  - suggested action: thêm tham số `branch_ids: list | None = None`, gọi `self.set_branches_for_company_user(company_user_id, branch_ids)` khi không None (song song với `department_ids`)

- `ha-speaking-admin-web/src/app/db/repositories/branch/branch_repository.py` (`insert_department`, cuối file) `[layer: repo]`
  - old ref found: hàm vẫn tên `insert_department` nhưng thân hàm tạo `Branch(...)` — chưa đổi tên/xoá
  - suggested action: đổi tên thành `insert_branch` hoặc xoá nếu là code thừa (vẫn không thấy nơi gọi hàm này — khả năng cao là dead code)

- `ha-speaking-admin-web/src/app/services/company/company.py` (`create_company`, dòng ~181–235) `[layer: service]`
  - old ref found: tạo `company` mới xong `db.commit()` ngay, không tạo `branch` mặc định nào — vẫn khác với backfill `"本社"` áp cho company cũ trong migration
  - suggested action: cần PM xác nhận có nên tự tạo 1 branch mặc định khi tạo company mới; nếu có, gọi `BranchRepository.create_branch_pending(...)` sau `insert_company` trong cùng transaction

## Not found

_Không có file nào bị xoá hoặc đổi path._

## Ghi chú (Notes)

- Toàn bộ 6 finding Must/Should từ baseline (`2026-08-19-branch-impact.md`) đều **chưa được fix** — chưa thấy commit áp checklist.
- Ưu tiên xử lý trước: bug relationship ở `ha-speaking-api/db_models.py` — ảnh hưởng toàn app ngay khi start, nên fix trước khi deploy bất kỳ thay đổi nào khác liên quan `Branch`.
- 3 finding Must ở `ha-speaking-admin-web` (edit.html, service, repo) đi cùng nhau — cùng 1 luồng "update branch cho company_user đã tồn tại", nên fix đồng thời để tránh commit dở dang (form gửi `branch_ids` nhưng service/repo chưa đọc, hoặc ngược lại).
- 2 Should verify (`insert_department` naming, `create_company` không tạo branch mặc định) không chặn migration nhưng vẫn còn nguyên như baseline.
- Re-scan dùng lại đúng search term từ baseline: `back_populates="company_users"`, `branch_ids`, `set_branches_for_company_user`, `branch_ids_wrapper`, `insert_department`.
