# Branch — Báo cáo impact (`ha-speaking-haij-student-web`)

## Thay đổi nguồn (Source change)

- Model: `Branch`, `CompanyUserBranch`; liên quan `Department.branch_id`
- Migration: `ha-speaking-api/src/app/migrations/versions/5b3548f846a2_create_branches_table.py`
- Tóm tắt:
  - Thêm bảng `branches`, `company_user_branches`; thêm `departments.branch_id` (NOT NULL sau backfill)
  - **Không** đổi schema bảng `haij_students` hay contract API student hiện tại
  - Branch là khái niệm quản trị company staff (`CompanyUser`), không phải học viên (`HaijStudent`)

## Tóm tắt migration (góc nhìn student-web)

- Repo này là **Nuxt 3 frontend** — không kết nối MySQL, không có ORM/entity
- Mọi request đi qua proxy `src/server/api/[...path].ts` → `ha-speaking-haij-student-api`
- Migration Branch chạy trên DB shared nhưng **student-web không đọc DB trực tiếp** → không cần sync schema local

## Rủi ro

- **Rủi ro trực tiếp cho student-web: thấp / không có** — không có code tham chiếu `Branch`, `Department`, `branch_id`, `department_id`
- **Rủi ro gián tiếp duy nhất:** nếu sau này `ha-speaking-haij-student-api` thêm field branch/department vào response profile → lúc đó mới cần cập nhật `TUser` và UI; **hiện tại API chưa expose** các field này
- Deploy student-web **không phụ thuộc** thứ tự migration Branch (khác admin-web / company-web)

## `ha-speaking-haij-student-web`

### Must update

*(Không có finding.)*

### Should verify

*(Không có finding bắt buộc cho migration Branch hiện tại.)*

### Maybe impacted

- `src/types/auth.type.ts` (`TUser`) `[layer: dto]`
  - reason: profile user chỉ có `companyType`, `userName`, exam ranks… — không có `branch`/`department`; khớp với student-api hiện tại
  - action: chỉ cập nhật khi PM yêu cầu hiển thị chi nhánh/部署 trên app học viên **và** student-api bổ sung field API

- `src/server/api/[...path].ts` `[layer: service]`
  - reason: proxy pass-through tới student-api — không parse/transform payload theo branch
  - action: không cần sửa cho migration này; verify lại nếu API contract đổi

- `src/components/dashboard/*.vue` (dùng `user?.companyType`) `[layer: template]`
  - reason: logic freemium vs corporate dựa `companyType`, không liên quan Branch
  - action: không cần sửa

## Kết quả quét repo

| Hạng mục | Kết quả |
|----------|---------|
| Grep `branch` / `Branch` / `department` / `department_id` trong `src/` | **0 hit** domain (chỉ git/deploy docs ngoài `src/`) |
| ORM / migration / seed | **Không có** |
| TypeScript types liên quan Branch | **Không có** |
| API client | Gọi `/api/v1/user/profile` và endpoint khác qua proxy — không field branch |
| i18n / policy text "company" | Text pháp lý Human Academy — không liên quan model `Branch` |

## Phụ thuộc upstream

| Repo | Impact với Branch |
|------|-------------------|
| `ha-speaking-haij-student-api` | Không có entity `Branch`/`Department`; `HaijStudent` giữ `company_id` + `department_id` ở DB nhưng **API không expose** → student-web không bị breaking |
| `ha-speaking-api` | Owner migration — student-web không deploy Alembic |
| `ha-speaking-company-web` / `ha-speaking-admin-web` | Consumer Branch — **ngoài phạm vi** student-web |

## Checklist

### `ha-speaking-haij-student-web`

#### Tests

- [ ] Không bắt buộc test regression Branch — không có thay đổi code

### Optional checks

- [ ] PM xác nhận: app học viên **không** cần hiển thị/chọn chi nhánh → giữ nguyên, bỏ qua Branch
- [ ] Nếu sau này API thêm `branchName`/`departmentName` → cập nhật `TUser` + màn profile/dashboard

## Ghi chú (Notes)

- `ha-speaking-haij-student-web` **không nằm** trong `.claude/config/repos.md` (map 4 repo Python) — đây là frontend Nuxt, pattern impact = **API contract + types + UI**, không phải entity sync.
- Branch phục vụ **phân quyền staff** (admin-web, company-web), không phải luồng học viên đăng nhập HAi-J app.
- So với `ha-speaking-company-web`: company-web phải resolve `user.branches → departments` cho `BRANCH_MANAGER`; student-web **không có** role staff hay filter department.
- Không gồm kế hoạch rollout/rollback/deploy-order.
