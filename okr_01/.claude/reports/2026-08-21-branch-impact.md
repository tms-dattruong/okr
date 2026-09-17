# Branch — Báo cáo impact

## Thay đổi nguồn (Source change)

- Model: `Branch`, `CompanyUserBranch` (bảng mới), `Department` (thêm `branch_id`)
- Migration: `ha-speaking-api/src/app/migrations/versions/5b3548f846a2_create_branches_table.py`
- Tóm tắt:
  - Tạo bảng `branches` (thuộc `Company`, có `status` là `VisibilityStatusEnum`)
  - Tạo bảng join `company_user_branches` (many-to-many giữa `CompanyUser` và `Branch`)
  - Thêm `departments.branch_id` (FK tới `branches.id`), backfill dữ liệu rồi set `NOT NULL`

## Tóm tắt migration

- `upgrade()`: tạo bảng `branches` (FK `company_id` → `companies.id`, index `company_id`, `status`)
- Tạo bảng `company_user_branches` (FK `company_user_id`, `branch_id`, mỗi FK có index riêng)
- Thêm cột `departments.branch_id` (nullable trước), tạo FK + index
- Chạy data migration: insert 1 branch mặc định "本社" cho mỗi company hiện có, rồi `UPDATE departments` set `branch_id` theo company tương ứng
- Sau backfill, `alter_column` đổi `departments.branch_id` thành `NOT NULL`
- `downgrade()`: drop FK/cột `branch_id` trên `departments`, drop bảng `company_user_branches`, drop bảng `branches`

## Rủi ro

- Bước `alter_column NOT NULL` sẽ fail nếu có `department` nào không backfill được `branch_id` (ví dụ `department.company_id` không khớp company nào trong `branches` mới insert) — cần chạy migration trên dữ liệu thật đã kiểm tra kỹ trước khi apply production.
- Toàn bộ logic ứng dụng cho `Branch`/`CompanyUserBranch`/`BRANCH_MANAGER` đã được code sẵn ở `ha-speaking-admin-web` và `ha-speaking-company-web` (đi trước migration) — nếu migration này chưa chạy trên một môi trường mà code đã deploy, các route liên quan (branch CRUD, company_user branch assignment, BRANCH_MANAGER scoping) sẽ lỗi do thiếu bảng/cột.
- Không có test tự động nào cho tính năng `Branch`/`BRANCH_MANAGER` ở `ha-speaking-admin-web` (`src/tests/`) và `ha-speaking-company-web` (`src/tests/`) — thay đổi logic scope theo branch có thể regressions mà không bị phát hiện.

## `ha-speaking-api`

*(Không có finding Must/Should — chỉ ghi chú)*

- `src/app/db/db_models.py` `[layer: entity]` — `Branch`, `CompanyUserBranch`, `Department.branch_id` đã khớp hoàn toàn với migration (quan hệ `Company.branches`, `Department.branch`, `CompanyUser.branches` đều đã có `back_populates` đúng chiều).
- Không có `repositories/`, `services/`, `models/` (Pydantic) cho `Branch`/`Department` trong api — đúng theo kiến trúc hiện tại: `ha-speaking-api` không expose CRUD company/department/branch qua API riêng, các repo consumer đọc MySQL trực tiếp.
- `src/app/db/views/views.py` và `src/app/db/seed/` — không có view hoặc seed nào tham chiếu `companies`/`departments`/`branches`, không bị ảnh hưởng.

## `ha-speaking-admin-web`

### Should verify

- `src/tests/` `[layer: seed]` (thực chất: thiếu test)
  - reason: không tồn tại `src/tests/branch/` hay `src/tests/department/` — tính năng branch CRUD, gán branch cho company_user (role `BRANCH_MANAGER`), và validation liên quan chưa có test tự động.
  - action: xác nhận với dev có nên bổ sung test cho `branch_check.py`, `branch_repository.py`, luồng department yêu cầu `branch_id` bắt buộc.

*(Các phần entity/repo/service/dto/template/validation/raw-sql đều đã Must-implemented sẵn — xem Ghi chú)*

## `ha-speaking-company-web`

### Should verify

- `src/tests/` `[layer: seed]` (thực chất: thiếu test)
  - reason: `src/tests/` chỉ có `home/`, `talk_history/` — không có test cho entity `Branch`/`CompanyUserBranch`, cho `UserRepositoryImpl.get_department_ids` (nhánh `BRANCH_MANAGER`), hay cho context processor trong `src/app/__init__.py` resolve department theo branch.
  - action: xác nhận với dev có nên bổ sung test cho luồng `BRANCH_MANAGER` (dedup department qua nhiều branch, `is_branch_manager` flag).

### Maybe impacted

- `src/app/infrastructure/persistence/` — không có `branch_repository_impl.py`, không có route/DTO/schema quản lý `Branch` riêng.
  - reason: company-web hiện chỉ đọc `Branch` gián tiếp qua quan hệ (`user.branches`, `branch.departments`) để tính scope, không có tính năng CRUD branch cho company staff — đúng với domain map ("company-web: add entity file only if company staff needs to read/write table"). Không cần thêm gì trừ khi có yêu cầu nghiệp vụ mới.

*(Entity, enum `BRANCH_MANAGER`, context processor, `user_repository_impl.get_department_ids`, các route/service dùng `is_branch_manager` đều đã Must-implemented sẵn — xem Ghi chú)*

## `ha-speaking-haij-student-api`

*(Không có finding — repo bị skip)*

- Không có `Branch`/`Department` entity trong `src/app/domain/entities/` (chỉ có `company.py`, `company_user.py`), và grep toàn repo không có tham chiếu `branch`/`Branch` nào ngoài file migration mẫu (`script.py.mako`) và 1 seed JSON không liên quan (`vocabulary/0003_haij_vocabulary_add.json`, trùng từ khóa ngẫu nhiên).
  - reason: đúng theo domain map — student-api chỉ cần `company_id`, không cần biết `department`/`branch`.

## Checklist

### `ha-speaking-api`

- [ ] chạy lại test suite liên quan (migration/model) trong `ha-speaking-api`

### `ha-speaking-admin-web`

#### Tests

- [ ] `src/tests/branch/` — xác nhận với dev có cần thêm test cho `branch_check.py`, `branch_repository.py`, department register/edit yêu cầu `branch_id`
- [ ] chạy lại test suite liên quan trong `ha-speaking-admin-web`

### `ha-speaking-company-web`

#### Tests

- [ ] `src/tests/` — xác nhận với dev có cần thêm test cho `UserRepositoryImpl.get_department_ids` (nhánh `BRANCH_MANAGER`) và context processor trong `src/app/__init__.py`
- [ ] chạy lại test suite liên quan trong `ha-speaking-company-web`

### Optional checks

- [ ] `ha-speaking-company-web/src/app/infrastructure/persistence/` — xác nhận PM có cần tính năng company-web tự quản lý `Branch` (hiện chưa có, chỉ đọc gián tiếp qua quan hệ)

## Ghi chú (Notes)

- Toàn bộ entity, repository, service, template, validation cho `Branch`/`CompanyUserBranch`/`Department.branch_id` đã được implement sẵn ở cả `ha-speaking-admin-web` và `ha-speaking-company-web` **trước khi** migration này được audit — migration này đưa DB schema bắt kịp code đã có, không phải code chạy sau migration.
- Do đó không có finding "Must update" nào — rủi ro chính nằm ở tính đúng đắn của backfill dữ liệu khi chạy migration thật và ở việc thiếu test tự động cho logic branch/BRANCH_MANAGER đã được viết.
- `ha-speaking-haij-student-api` bị skip vì không có entity và không có tham chiếu nào tới `branch`/`department`.
- Save: `.claude/reports/2026-08-21-branch-impact.md`
