# Branch → HaijStudent — Báo cáo impact (`ha-speaking-company-web`)

## Thay đổi nguồn (Source change)

- Model: `Branch`, `CompanyUserBranch`; liên quan gián tiếp `Department.branch_id` → `HaijStudent.department_id`
- Migration: `ha-speaking-api/src/app/migrations/versions/5b3548f846a2_create_branches_table.py`
- Tóm tắt:
  - Thêm bảng `branches`, `company_user_branches`; thêm `departments.branch_id` (NOT NULL sau backfill)
  - **Không** thêm/sửa/xoá cột nào trên bảng `haij_students`
  - Cây dữ liệu mới: Company → Branch → Department; `HaijStudent` vẫn gắn Department qua FK `department_id`

## Tóm tắt migration (liên quan HaijStudent)

- `haij_students` không đổi schema — không cần sync entity `HaijStudent` vì thêm/xoá cột
- Mọi student hiện có vẫn trỏ `department_id` cũ; department sau migration có `branch_id` hợp lệ (backfill `"本社"`)
- Phạm vi xem student theo role không còn chỉ Company/Department mà thêm nhánh `BRANCH_MANAGER`: user → `company_user_branches` → `branches` → `departments` → `HaijStudent.department_id`

## Rủi ro

- **`BRANCH_MANAGER` chưa được gán branch** (gap admin-web `edit.html` / update `company_user_branches`) → `get_department_ids` trả `[]` → list student, dashboard, export trống — không phải lỗi code company-web nhưng ảnh hưởng trực tiếp UX HaijStudent
- **`send_mail` không áp department scope** — `condition.department_ids` mặc định `None` (= ADMIN, thấy toàn company) → STAFF/`BRANCH_MANAGER` có thể gửi mail promote tới student ngoài phạm vi chi nhánh
- **`get_student_detail` / history / export history không check scope** — chỉ filter theo `student_id`, không verify `company_id` hay `department_id` thuộc branch được phép → IDOR xem lịch sử student ngoài chi nhánh nếu biết ID
- **Filter UI vẫn theo department**, không có lớp branch — đúng với model hiện tại (student không có `branch_id`) nhưng `BRANCH_MANAGER` nhiều chi nhánh phải lọc thủ công theo department con

## `ha-speaking-company-web`

### Must update

*(Không có — entity và luồng list/export/dashboard đã đồng bộ migration Branch.)*

### Should verify

- `src/app/application/services/student_service.py` (`send_mail`) `[layer: service]`
  - reason: không gọi `user_repository.get_department_ids(user_id)` trước `find_all` — khác `get_student_list`/`export_csv` đã set scope; với role `BRANCH_MANAGER` mới, rủi ro gửi mail tới HaijStudent ngoài chi nhánh
  - action: truyền `user_id`, set `condition.department_ids = self.user_repository.get_department_ids(user_id)` giống `export_csv`

- `src/app/application/services/student_service.py` (`get_student_detail`, `get_practice_logs`) `[layer: service]`
  - reason: `find_by_id(student_id)` không filter `company_id`/`department_id`; sau Branch, ranh giới phân quyền là department thuộc branch — detail/history có thể vượt scope `BRANCH_MANAGER`/STAFF
  - action: thêm check: load student kèm `department_id`, so với `get_department_ids(user_id)`; `abort(404)` nếu ngoài scope hoặc khác `company_id` JWT

- `src/app/interfaces/routes/student_route.py` (`show`, `student_history`, `export_student_history_csv`) `[layer: validation]`
  - reason: route không truyền `user_id`/`company_id` xuống service để enforce scope
  - action: truyền `get_user_id_from_jwt()` + `get_company_id_from_jwt()` vào service sau khi service có guard

### Maybe impacted

- `src/app/domain/entities/haij_student.py` `[layer: entity]`
  - reason: không có `branch_id` hay relationship tới `Branch` — đúng với migration (chỉ FK `department_id`); truy cập branch gián tiếp qua `student.department.branch` nếu cần hiển thị
  - action: chỉ thêm property/relationship khi PM yêu cầu hiển thị tên chi nhánh trên màn student

- `src/app/application/dto/student_dto.py` + `src/app/templates/pages/student/show.html` `[layer: dto / template]`
  - reason: DTO detail/list không expose `department_name`/`branch_name` — Branch không breaking nhưng staff không thấy student thuộc chi nhánh nào
  - action: optional — thêm field từ join `Department`/`Branch` nếu product cần

- `src/app/templates/pages/student/index.html` + `src/app/static/js/student.js` `[layer: template]`
  - reason: multi-select filter chỉ theo department (`_get_filter_departments` đã resolve branch→department cho `BRANCH_MANAGER`); không có filter branch riêng
  - action: không bắt buộc; cân nhắc group department theo branch nếu UX yêu cầu

- `src/app/infrastructure/persistence/department_scope.py` `[layer: repo]`
  - reason: logic resolve `user.branches → department_ids` lặp ở `user_repository_impl`, `student_route`, `message_service`, `homework_service`, `__init__.py` — không ảnh hưởng đúng/sai HaijStudent query hiện tại
  - action: refactor gom helper `branch_manager_department_ids(user)` — tránh lệch sau này

## Luồng HaijStudent đã xử lý Branch (không cần sửa)

| Luồng | File | Cách scope HaijStudent |
|-------|------|------------------------|
| Danh sách + phân trang | `student_service.get_student_list` → `student_repository_impl` | `get_department_ids` + `department_scope_clause(HaijStudent.department_id, ...)` |
| Export CSV list | `student_service.export_csv` | Giống list |
| Filter dropdown | `student_route._get_filter_departments` | `BRANCH_MANAGER`: flatten `user.branches[].departments` |
| Dashboard thống kê student | `home_service.index` → `student_statistics_repository_impl._active_student_conditions` | `get_department_ids` + `department_scope_clause` |
| Message/homework chọn student | `message_service` / `homework_service` `_get_department_ids` | Filter `HaijStudent.department_id.in_(department_ids)` |
| Sidebar / context | `__init__.py` inject departments | Resolve branch→department cho `BRANCH_MANAGER` |
| Eager load user | `user_repository_impl.find_by_id` | `joinedload(CompanyUser.branches).joinedload(Branch.departments)` |

Entity liên quan đã sync: `branch.py`, `company_user_branch.py`, `department.branch_id`, `CompanyUser.branches`.

## Checklist

### `ha-speaking-company-web`

#### service

- [ ] `src/app/application/services/student_service.py` — `send_mail`: set `condition.department_ids` từ `get_department_ids(user_id)`
- [ ] `src/app/application/services/student_service.py` — `get_student_detail` / `get_practice_logs`: enforce company + department scope cho STAFF/`BRANCH_MANAGER`

#### validation (route)

- [ ] `src/app/interfaces/routes/student_route.py` — truyền `user_id`/`company_id` vào detail/history/export history

#### Tests

- [ ] chạy lại test suite liên quan trong `ha-speaking-company-web` (student list scope, dashboard stats nếu có test role)

### Optional checks

- [ ] `src/app/application/dto/student_dto.py` + `pages/student/show.html` — hiển thị department/branch name
- [ ] `src/app/infrastructure/persistence/department_scope.py` — gom logic branch→department_ids
- [ ] `ha-speaking-admin-web` — đảm bảo `BRANCH_MANAGER` được gán branch trước khi test company-web

## Ghi chú (Notes)

- Migration **không đụng** `haij_students` → **không có Must update entity** cho `HaijStudent`.
- Branch ảnh hưởng HaijStudent **gián tiếp** qua `HaijStudent.department_id` → `Department.branch_id`; phân quyền mới chủ yếu qua role `BRANCH_MANAGER`.
- So với báo cáo Branch tổng thể (`2026-08-19-branch-impact.md`), phần company-web cho HaijStudent **đã implement** list/export/stats/message/homework; gap còn lại tập trung **send_mail** và **detail/history không check scope**.
- `ha-speaking-haij-student-api`: không impact — student API không có entity Branch/Department ngoài `company_id`.
- Không gồm kế hoạch rollout/rollback/deploy-order.
