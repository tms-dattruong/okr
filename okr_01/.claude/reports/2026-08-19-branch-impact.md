# Branch — Báo cáo impact

## Thay đổi nguồn (Source change)

- Model: `Branch` (bảng `branches`), `CompanyUserBranch` (bảng `company_user_branches`), liên quan `Department.branch_id`
- Migration: `ha-speaking-api/src/app/migrations/versions/5b3548f846a2_create_branches_table.py`
- Tóm tắt:
  - Tạo bảng mới `branches`: `id`, `company_id` (FK → `companies.id`, NOT NULL), `name`, `status` (`VisibilityStatusEnum`), `created_at`, `updated_at`
  - Tạo bảng mới `company_user_branches`: N–N giữa `company_users` và `branches` (`company_user_id`, `branch_id` NOT NULL; có `created_at`/`updated_at`)
  - Thêm cột `departments.branch_id` (FK → `branches.id`): add nullable → backfill dữ liệu → `ALTER COLUMN` `NOT NULL`
  - **Không** drop `departments.company_id` — cây dữ liệu thành Company → Branch → Department, vẫn giữ FK cũ Company → Department

## Tóm tắt migration

- `upgrade`: `CREATE TABLE branches` + index `ix_branches_company_id`, `ix_branches_status`; `CREATE TABLE company_user_branches` + index `company_user_id`, `branch_id`; `ADD COLUMN departments.branch_id` (nullable) + index + FK `fk_departments_branch_id`
- Backfill: với mỗi `companies.id` hiện có → insert 1 `branches` mặc định `name="本社"`, `status=PUBLIC`; `UPDATE departments SET branch_id=...` theo `company_id` tương ứng
- Sau backfill: `ALTER COLUMN departments.branch_id SET NOT NULL`
- `downgrade`: gỡ FK/index/cột `departments.branch_id` (nếu còn), `DROP TABLE company_user_branches`, drop index/FK rồi `DROP TABLE branches`

## Rủi ro

- **Mapper SQLAlchemy sẽ lỗi ngay khi khởi động `ha-speaking-api`**: `CompanyUser.branches` khai `back_populates="company_users"` nhưng class `Branch` không có thuộc tính `company_users` → `InvalidRequestError` khi SQLAlchemy configure mapper (ảnh hưởng toàn app, không chỉ tính năng Branch).
- Sửa/gán chi nhánh cho `company_user` đã tồn tại (đổi role sang hoặc đang là `BRANCH_MANAGER`) không thể thực hiện qua UI admin-web — không có đường ghi `company_user_branches` khi update.
- Vòng lặp backfill trong migration insert từng `branches`/`UPDATE departments` theo từng `company` bằng nhiều statement riêng trong 1 transaction — nếu fail giữa chừng (ví dụ DB timeout với DB lớn), phần data backfill có thể để `departments.branch_id` dở dang trước khi set `NOT NULL` — cần kiểm tra thời gian chạy trên số lượng `companies` thực tế.
- Toàn bộ company hiện có nhận cùng tên chi nhánh mặc định `"本社"` — nếu 2 company trùng tên hiển thị, không phải bug nhưng cần biết trước khi demo/support.

## `ha-speaking-api`

### Must update

- `src/app/db/db_models.py` `[layer: entity]`
  - reason: `CompanyUser.branches` (dòng ~620) dùng `back_populates="company_users"` nhưng class `Branch` (dòng ~627) chỉ có `company`, `departments` — thiếu `company_users = relationship("CompanyUser", secondary="company_user_branches", back_populates="branches")`. Thiếu vế đối xứng của `back_populates` khiến SQLAlchemy configure mapper lỗi ngay từ request/import đầu tiên chạm tới các model này.
  - action: thêm `company_users = relationship("CompanyUser", secondary="company_user_branches", back_populates="branches")` vào class `Branch`, giống cách `admin-web/src/app/db/db_models.py` đã làm

Không có repository/service/Pydantic/view/seed nào trong api tham chiếu `Branch`/`Department` — CRUD nằm ở admin-web. `docs/db-erd.md` đã cập nhật `branches`, `company_user_branches`, quan hệ với `departments`/`company_users`.

## `ha-speaking-admin-web`

Phần lớn checklist (entity, repository insert/update department theo `branch_id`, template `department/register.html` + `list.html` + `detail.html`, `department_bulk_register.py`, CSV download theo `branch_id`, validate `BRANCH_MANAGER` cần ≥1 branch, endpoint `branch_managers_by_company`, toggle picker theo role trong `company_user/register.html`) đã được implement đầy đủ và khớp migration.

### Must update

- `src/app/templates/admin/company_user/edit.html` `[layer: template]`
  - reason: không có field/picker branch nào — chỉ có `department_ids_wrapper`, không có `branch_ids_wrapper`, không fetch `branch_managers_by_company`, không hidden input `branch_ids`. Không xem/sửa được chi nhánh của `company_user` đã tồn tại, đặc biệt khi role là `BRANCH_MANAGER`.
  - action: thêm UI chọn nhiều branch (giống `register.html`): wrapper hiện khi `role == 3`, fetch `branch_managers_by_company`, chip + hidden `branch_ids`, prefill từ `company_user.branches`
- `src/app/services/company_user/company_user.py` (`update_company_user`) `[layer: service]`
  - reason: chỉ đọc `department_ids` từ form, không đọc `branch_ids`; không gọi `company_user_repo.set_branches_for_company_user` khi update (khác `create_company_user` đã gọi khi tạo mới)
  - action: đọc `branch_ids = request.form.getlist("branch_ids")` khi `role == BRANCH_MANAGER`, gọi `company_user_repo.set_branches_for_company_user(id, branch_ids)` + `db.commit()` giống flow tạo mới
- `src/app/db/repositories/company_user/company_user_repository.py` (`update_company_user`) `[layer: repo]`
  - reason: signature chỉ nhận `department_ids`, không có tham số `branch_ids` để đồng bộ `company_user_branches` khi update
  - action: thêm tham số `branch_ids: list | None = None`, gọi `self.set_branches_for_company_user(company_user_id, branch_ids)` khi không None (song song với `department_ids`)

### Should verify

- `src/app/db/repositories/branch/branch_repository.py` (`insert_department`) `[layer: repo]`
  - reason: hàm tên `insert_department` nhưng thân hàm tạo `Branch(...)` — trùng tên khái niệm với `DepartmentRepository.insert_department` thật, dễ gọi nhầm/đọc nhầm khi bảo trì. Hiện không thấy nơi gọi hàm này (dead code khả năng cao) nên chưa gây lỗi runtime.
  - action: đổi tên thành `insert_branch` hoặc xoá nếu là code thừa còn lại từ lúc copy `DepartmentRepository`
- `src/app/services/company/company.py` (`create_company`) `[layer: service]`
  - reason: tạo `company` mới không tự tạo 1 `branch` mặc định (khác với backfill `"本社"` áp cho company cũ trong migration) — company mới sẽ chưa có branch nào, chặn luôn việc tạo department vì `department_register` bắt buộc `branch_id` hợp lệ
  - action: xác nhận PM — có nên tự tạo 1 branch mặc định khi tạo company mới, để đồng nhất với dữ liệu backfill - không cần tạo

### Maybe impacted

- `src/app/db/repositories/company_user/company_user_repository.py` (subquery dùng `Department.company_id`) `[layer: repo]`
  - reason: `departments.company_id` vẫn còn (migration không drop) nên query lọc theo `company_id` vẫn đúng dữ liệu; không phải lỗi, chỉ là đường dữ liệu cũ song song với `branch_id` mới
  - action: không cần sửa cho migration này; chỉ xử lý nếu sau này có kế hoạch drop `departments.company_id`

## `ha-speaking-company-web`

Không có Must — entity `branch.py`, `company_user_branch.py`, `Department.branch_id`, quan hệ 2 chiều `CompanyUser.branches` ↔ `Branch.company_users` đã có đầy đủ (khác api, company-web khai đúng cả 2 chiều). Logic `BRANCH_MANAGER` (resolve `user.branches` → `branch.departments`) đã dùng thực tế ở `message_service.py`, `homework_service.py`, `student_route.py`, `talk_history.py`, `user_repository_impl.py`, `__init__.py`.

### Maybe impacted

- `src/app/infrastructure/persistence/department_scope.py` `[layer: repo]`
  - reason: helper `department_scope_clause` chỉ nhận `department_ids`; logic mở rộng "branch → tất cả department con" cho `BRANCH_MANAGER` đang lặp lại thủ công ở nhiều file (`__init__.py`, `message_service.py`, `homework_service.py`, `student_route.py`, `talk_history.py`, `user_repository_impl.py`) thay vì tập trung 1 chỗ
  - action: không bắt buộc cho migration này; cân nhắc gom logic resolve `branch → department_ids` vào `department_scope.py` để tránh lệch khi sửa sau

## `ha-speaking-haij-student-api`

Không có finding. Repo không có entity `Department`/`Branch`; `HaijStudent`/`CompanyUser` chỉ giữ `company_id`. Đúng domain map: student-api thường không impact với thay đổi ở tầng company/branch/department.

## Checklist

### `ha-speaking-api`

#### entity

- [ ] `src/app/db/db_models.py` — thêm `Branch.company_users = relationship("CompanyUser", secondary="company_user_branches", back_populates="branches")` để tránh lỗi configure mapper

#### Tests

- [ ] chạy lại test suite liên quan trong `ha-speaking-api` (đặc biệt test nào import/khởi tạo `db_models`)

### `ha-speaking-admin-web`

#### template

- [ ] `src/app/templates/admin/company_user/edit.html` — thêm picker branch (giống `register.html`), prefill từ `company_user.branches`

#### service

- [ ] `src/app/services/company_user/company_user.py` — `update_company_user` đọc `branch_ids` và gọi `set_branches_for_company_user` khi `role == BRANCH_MANAGER`

#### repo

- [ ] `src/app/db/repositories/company_user/company_user_repository.py` — `update_company_user` nhận `branch_ids`, đồng bộ `company_user_branches`

#### Tests

- [ ] chạy lại test suite liên quan (`company_user`, `branch`, `department`) trong `ha-speaking-admin-web`

### Optional checks

- [ ] `src/app/db/repositories/branch/branch_repository.py` — đổi tên/xoá `insert_department()` gây nhầm với `Department`
- [ ] `src/app/services/company/company.py` — PM xác nhận có tự tạo branch `"本社"` khi tạo company mới không
- [ ] `ha-speaking-company-web/src/app/infrastructure/persistence/department_scope.py` — gom logic resolve branch→department cho `BRANCH_MANAGER`

## Ghi chú (Notes)

- Bảng/cột đụng trực tiếp: `branches` (mới), `company_user_branches` (mới), `departments.branch_id` (thêm, `NOT NULL` sau backfill). Không đổi cột ở `companies`, `company_users`, `company_user_departments`, `haij_students`.
- So với lần audit trước cùng ngày, phần lớn Must ở `ha-speaking-admin-web` (thiếu `branch_id` khi insert department, thiếu `branch_id` trong bulk register, thiếu relationship `CompanyUser.branches`/`Branch.company_users`, thiếu validate ≥1 branch cho `BRANCH_MANAGER`, thiếu toggle UI đúng theo role, `docs/db-erd.md` chưa cập nhật) **đã được fix** — chỉ còn gap ở `edit.html` + đường update branch cho user đã tồn tại.
- Bug relationship ở `ha-speaking-api` (`CompanyUser.branches` back_populates trỏ tới thuộc tính không tồn tại trên `Branch`) là finding mới, mức độ nghiêm trọng cao nhất trong báo cáo này.
- `departments.company_id` cố ý giữ lại — consumer vẫn join/filter theo `company_id` được trong giai đoạn chuyển tiếp.
- `ha-speaking-haij-student-api` bỏ qua vì không có entity `Company`/`Department`/`Branch` ngoài `company_id`.
- Không gồm kế hoạch rollout/rollback/deploy-order.
