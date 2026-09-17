# Branch Impact Report

## Source change

- Model: `Branch`
- Summary:
  - Thêm bảng `branches` xen giữa `companies` và `departments`
  - `Department.company_id` (FK trực tiếp tới `companies`) bị thay bằng `Department.branch_id` (FK tới `branches`)
  - `Branch` có `company_id` FK tới `companies`, và quan hệ `1 company -> N branches -> N departments`

**Note:** `ha-speaking-api/src/app/db/db_models.py` đã có sẵn thay đổi này ở working tree (uncommitted, `git status` = `M`), gồm `Branch` class mới, `Department.company_id`/`Department.company` bị comment out và thay bằng `branch_id`/`branch`. Chưa có alembic migration tương ứng.

## `ha-speaking-api`

### Must update

- `src/app/db/db_models.py`
  - reason: model change đang là **uncommitted diff** — `Branch` class mới, `Department.branch_id` mới, `Department.company_id`/`company` relationship bị comment out. Đây là điểm gốc mọi impact bên dưới.
  - action: hoàn thiện model (bỏ comment cũ, xác nhận `back_populates` khớp cả 2 chiều), rồi generate alembic migration.
- `src/app/migrations/versions/` (chưa có file mới)
  - reason: không tìm thấy migration nào tạo bảng `branches` hoặc sửa `departments` — repo đang thiếu migration cho schema change này.
  - action: tạo migration: `CREATE TABLE branches (...)`, `ALTER TABLE departments ADD COLUMN branch_id`, backfill (tạo 1 branch mặc định cho mỗi company hiện có, gán `department.branch_id` tương ứng), rồi mới `DROP COLUMN company_id` + drop FK cũ `fk_departments_company_id`.

### Should verify

- `src/app/migrations/versions/be3c1e75e803_create_department.py`
  - reason: migration gốc tạo `departments.company_id` — migration mới phải alter đúng bảng/constraint này, tránh trùng tên FK.
  - action: kiểm tra tên constraint cũ trước khi viết migration mới để down-migration revert đúng.

## `ha-speaking-admin-web`

Repo này **tự duplicate toàn bộ ORM models** trong `src/app/db/db_models.py` (không import từ `ha-speaking-api`) — mọi thay đổi schema phải làm lại thủ công ở đây.

### Must update

- `src/app/db/db_models.py:512-570`
  - reason: có `Company`/`Department` riêng, `Department.company_id` trực tiếp tới `companies`, chưa có class `Branch`.
  - action: thêm class `Branch`, đổi `Department.company_id` → `branch_id`, sửa relationship 2 chiều.
- `src/app/db/repositories/department/department_repository.py`
  - reason: toàn bộ query lọc theo `Department.company_id` (`filter_departments_paginated`, `get_departments_by_company_id`, `get_department_by_id_and_company`, `insert_department`, `create_department_pending`, `get_all_departments` với `joinedload(Department.company)`).
  - action: đổi sang lọc/join qua `Branch` (`Department.branch_id` → `Branch.company_id`), hoặc thêm tham số `branch_id` cho các hàm tạo/tìm department.
- `src/app/services/department/department.py`
  - reason: toàn bộ route (`department_list`, `department_register`, `create_department`, `update_department`) nhận `company_id` từ query/form rồi gọi thẳng repo theo company — không có khái niệm branch.
  - action: thêm bước chọn branch (dropdown) trước khi chọn/tạo department; truyền `branch_id` thay vì `company_id` xuống repo.
- `src/app/services/department/department_bulk_register.py`
  - reason: bulk-register CSV department nhận `company_id` trực tiếp, gọi `create_department_pending(company_id, ...)`.
  - action: CSV cần thêm cột branch (hoặc chọn 1 branch trước khi upload), sửa hàm tạo pending department dùng `branch_id`.
- `src/app/services/csv/csv_department.py:43`
  - reason: raw SQL `f"WHERE d.company_id = {company_id}"` — string-interpolated, phụ thuộc trực tiếp cột sẽ bị xoá.
  - action: sửa query join `departments d JOIN branches b ON d.branch_id = b.id WHERE b.company_id = ...` (giữ nguyên style bind param, không f-string trực tiếp giá trị nếu có thể tránh SQL injection risk — hiện tại `company_id` đã ép `int()` nên an toàn, nhưng nên parameterize khi sửa).
- `src/app/db/repositories/company_user/company_user_repository.py:60-61`
  - reason: subquery `select(Department.company_id)` dùng để lọc `CompanyUser.company_id.in_(...)`.
  - action: đổi subquery join qua `Branch.company_id`.
- `src/app/services/company_user/company_user.py:84-86` và `src/app/services/haij_student/haij_student.py:144-146`
  - reason: cả 2 đọc `department.company_id` / `department.company.name` để hiển thị tên company cho department — field/relationship này sẽ mất.
  - action: đổi thành `department.branch.company_id` / `department.branch.company.name` (hoặc thêm property tiện lợi trên `Department`).
- `src/app/services/learning_statistics/learning_statistics_service.py:200-203, 235`
  - reason: raw `.join(Company, Department.company_id == Company.id)` và `.join(Company, HaijStudent.company_id == Company.id)` — dòng Department join sẽ vỡ ngay khi cột bị đổi (dòng HaijStudent join không bị ảnh hưởng vì `HaijStudent.company_id` vẫn giữ nguyên).
  - action: sửa join Department thành `Department -> Branch -> Company` (2 join thay vì 1).
- `src/app/db/repositories/haij_student/haij_student_bulk_register_repository.py:61`
  - reason: build map `{c.id: {d.name: d.id for d in departments if d.company_id == c.id}}` — dùng trực tiếp `d.company_id`.
  - action: đổi điều kiện match sang qua `branch.company_id`.
- `src/app/db/repositories/learning_statistics/daily_learning_statistics_repository.py`
  - reason: lưu `company_id` theo từng department vào bảng thống kê hàng ngày — nguồn `company_id` hiện lấy trực tiếp từ `Department`.
  - action: xác nhận nguồn `row["company_id"]` (đến từ query ở `learning_statistics_service.py` nói trên) đã được sửa để join qua Branch trước khi insert.

### Should verify

- `src/app/templates/admin/department/list.html`, `detail.html`, `bulk-register-result.html`
  - reason: trang quản lý department hiện chỉ biết context "company" — sau khi thêm Branch, luồng UI cần thêm cấp branch (breadcrumb, filter).
  - action: kiểm tra template có cần thêm cột/label "Branch" và điều hướng company → branch → department.
- `src/app/templates/admin/company_user/list.html`, `register.html`
  - reason: chọn department cho company_user hiện chỉ lọc theo company; sau khi có branch, danh sách department cần biết thuộc branch nào (đặc biệt nếu 1 company có nhiều branch trùng tên department).
  - action: kiểm tra UX chọn branch trước khi chọn department còn hợp lý không.
- `src/app/templates/admin/haij-student/list.html`, `register.html`, `edit.html`
  - reason: hiển thị company/department của student — có đọc `department.company.name` gián tiếp qua service ở trên.
  - action: verify hiển thị đúng sau khi service đổi sang `department.branch.company.name`.
- `src/app/utils/check/haij_student_check.py`
  - reason: matched trong scan ban đầu (company_id/department liên quan) nhưng chưa đọc chi tiết nội dung.
  - action: đọc lại file, xác nhận không có validate logic dựa trực tiếp vào `Department.company_id`.

### Maybe impacted

- `src/tests/department/*`, `src/tests/company_user/*`, `src/tests/haij_student/*`, `src/tests/learning_statistics/*`
  - reason: không tìm thấy test nào tạo `Department(company_id=...)` trực tiếp (có thể dùng mock/factory), nhưng test sẽ cần cập nhật nếu mock trả về object có field `company_id`/`company` trên Department.
  - action: chạy lại test suite sau khi sửa model, sửa fixture nếu fail.

## `ha-speaking-company-web`

Repo này cũng **tự duplicate ORM entities** dưới `src/app/domain/entities/` (Clean Architecture, tách entity riêng) — không import từ `ha-speaking-api`.

### Must update

- `src/app/domain/entities/company.py:49-56`
  - reason: `Company.departments` relationship dùng `primaryjoin=... Company.id == foreign(Department.company_id) ...` — trực tiếp phụ thuộc cột sẽ bị xoá.
  - action: đổi sang join qua Branch, hoặc thêm entity `Branch` + relationship `Company.branches` rồi `Branch.departments`.
- `src/app/domain/entities/department.py:23-34`
  - reason: `Department.company_id` FK trực tiếp + `Department.company` relationship.
  - action: thêm `Branch` entity, đổi `company_id` → `branch_id`, relationship → `branch`.
- `src/app/application/services/message_service.py:36-42`, `src/app/application/services/homework_service.py:49-55`
  - reason: `user.company.departments` dùng để lấy toàn bộ department của company khi user là Admin — phụ thuộc trực tiếp relationship `Company.departments` ở trên.
  - action: nếu sửa relationship thành 2 cấp (qua Branch), code này vẫn hoạt động miễn `Company.departments` (derived) được giữ nguyên interface — verify sau khi sửa entity.
- `src/app/interfaces/routes/student_route.py:73-84`, `src/app/interfaces/routes/talk_history.py:29-40`
  - reason: `_get_filter_departments()` dùng `user.company.departments` tương tự — cùng phụ thuộc.
  - action: verify không đổi hành vi sau khi entity update (nếu giữ `Company.departments` là derived property xuyên Branch thì các file này không cần sửa).

### Should verify

- `src/app/infrastructure/persistence/student_statistics_repository_impl.py`
  - reason: dùng `Department` trong query thống kê tuần theo `department_ids` — không thấy join trực tiếp `Department.company_id` trong đoạn đã xem, nhưng cần xác nhận toàn file.
  - action: đọc toàn bộ file, kiểm tra có join Company qua Department ở đâu không.
- `src/app/infrastructure/persistence/user_repository_impl.py:35`
  - reason: `joinedload(CompanyUser.company).joinedload(Company.departments)` — phụ thuộc gián tiếp vào relationship `Company.departments` (như trên).
  - action: verify eager-load vẫn hoạt động đúng sau khi đổi cấu trúc relationship.

### Maybe impacted

- `src/app/infrastructure/persistence/homework_repository_impl.py`, `message_repository_impl.py`
  - reason: dùng `company_id`/`department_ids` làm tham số filter (qua `CompanyUserDepartment`, không qua `Department.company_id` trực tiếp) — có vẻ an toàn vì không match trực tiếp cột bị đổi.
  - action: verify nhanh không có join nào khác tới `Department.company_id` trong 2 file này ngoài phần đã xem.
- `src/app/infrastructure/persistence/department_scope.py`
  - reason: chỉ nhận `department_id_column` + `department_ids` (đã resolve sẵn), không tự query DB — không phụ thuộc trực tiếp cột `company_id`.
  - action: không cần sửa, chỉ cần đảm bảo nơi gọi truyền đúng `department_ids` đã resolve qua Branch.

## `ha-speaking-haij-student-api`

### Maybe impacted (không có evidence trực tiếp)

- `src/app/domain/entities/student.py`, `src/app/domain/entities/company.py`
  - reason: `HaijStudent` entity ở repo này chỉ có `company_id` (FK tới `companies`), **không có** field hay relationship nào tới `Department`/`Branch`. `Company` entity ở đây cũng không có relationship `departments`.
  - action: không cần sửa gì ngay. Chỉ verify lại nếu tương lai thêm department/branch filter cho student-facing API.

## Checklist

- [ ] Hoàn thiện `Branch`/`Department` model trong `ha-speaking-api`, tạo alembic migration (kèm backfill data)
- [ ] Thêm `Branch` model + đổi FK trong `ha-speaking-admin-web/src/app/db/db_models.py`
- [ ] Sửa toàn bộ query/service/raw-SQL trong `ha-speaking-admin-web` đang dùng `Department.company_id` trực tiếp (repository, service, raw SQL CSV export)
- [ ] Thêm UI chọn Branch trong luồng quản lý department/company_user ở admin-web
- [ ] Thêm `Branch` entity + sửa relationship trong `ha-speaking-company-web/src/app/domain/entities/`
- [ ] Verify các nơi dùng `Company.departments`/`user.company.departments` ở company-web vẫn hoạt động đúng sau khi đổi entity
- [ ] Chạy lại test suite ở cả 3 repo sau khi sửa
- [ ] `ha-speaking-haij-student-api`: không cần sửa (không đụng Department/Branch)

## Notes

- Cả 3 repo backend (`ha-speaking-api`, `ha-speaking-admin-web`, `ha-speaking-company-web`) đều tự định nghĩa ORM model riêng cho `Company`/`Department` (không share code) — nghĩa là thay đổi schema này phải làm **3 lần thủ công**, không tự động đồng bộ.
- `ha-speaking-api` đã có sẵn code thay đổi (uncommitted) nhưng thiếu migration — nên hoàn thiện + migrate ở đây trước, dùng làm tham chiếu khi sửa 2 repo admin-web/company-web.
- Report này chỉ khảo sát (phase 1), không sửa code.
