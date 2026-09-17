# SituationListening — Báo cáo impact

## Thay đổi nguồn (Source change)

- Model: `SituationListeningQuestion`, `SituationListeningAnswer`, `SituationListeningLog`
- Migration: `ha-speaking-api/src/app/migrations/versions/887b68188247_add_situation_listening_table.py`
- Tóm tắt:
  - Bảng mới `situation_listening_questions` (id, `scene` int không FK, question, explanation, audio_url, status, display_order, timestamps) — index `idx_situation_listening_questions_scene` trên `scene`
  - Bảng mới `situation_listening_answers` (id, `question_id` FK → `situation_listening_questions.id`, answer, is_correct, display_order, timestamps)
  - Bảng mới `situation_listening_logs` (id, `haij_student_id` FK, `question_id` FK, `answer_id` FK, timestamps) — log học sinh chọn đáp án nào cho câu hỏi nào
  - Loại thay đổi: **new model / new table**, nằm trong domain "situation" (dựa trên `scene` của `SituationPracticeContent`, cùng pattern với `SituationWord`)

Ghi chú: mỗi service tự giữ bản copy ORM riêng cho MySQL dùng chung (không import ORM cross-repo). Migration chỉ tạo bảng ở DB dùng chung — mỗi consumer phải tự thêm ORM class nếu cần đọc/ghi.

## Chiến lược migration

### Tương thích ngược (Backward compatibility)

- Bảng hoàn toàn mới, không code cũ nào đọc `situation_listening_*` cho tới khi consumer thêm ORM class — zero impact khi mới deploy migration.
- `scene` không có FK ràng buộc (giống `SituationWord.scene`) — không ảnh hưởng dữ liệu `situation_practice_contents` hiện có, nhưng cũng không có ràng buộc toàn vẹn tham chiếu — cần xác nhận tầng ứng dụng validate `scene` hợp lệ.
- `status` dùng lại `VisibilityStatusEnum` (`PUBLIC`/`PRIVATE`) — enum có sẵn, không cần thêm enum mới.

### Rollout

1. Chạy migration `887b68188247` (`alembic upgrade head`) trên MySQL dùng chung — ORM class trong `ha-speaking-api/src/app/db/db_models.py:751-790` đã khớp migration, không cần sửa gì thêm ở api.
2. Deploy `ha-speaking-admin-web` — thêm 3 ORM class còn thiếu, build CRUD nếu cần màn hình quản trị.
3. `ha-speaking-company-web` — tuỳ chọn, chỉ cần nếu company dashboard phải hiển thị lịch sử luyện nghe.
4. `ha-speaking-haij-student-api` — tuỳ chọn, chỉ cần khi tính năng nghe hiểu lộ ra cho học sinh; xác nhận phạm vi PM trước khi build (xem mục Should verify bên dưới).
5. Cập nhật `ha-speaking-api/docs/db-erd.md` nếu ERD đang theo dõi domain situation.

### Rollback

- Chạy `downgrade()` của migration `887b68188247` — drop theo thứ tự `situation_listening_logs` → `situation_listening_answers` → `situation_listening_questions` (đã đúng thứ tự FK trong file migration).
- Gỡ ORM class mới thêm ở admin-web/company-web/student-api nếu rollback trước khi có dữ liệu production.

## Thứ tự deploy (Deployment order)

1. `ha-speaking-api` — migration phải chạy trước, 3 bảng phải tồn tại trước khi consumer nào thêm ORM/CRUD.
2. `ha-speaking-admin-web` — consumer chính cần thêm ORM class (Must); CRUD/UI tuỳ nhu cầu quản trị nội dung.
3. `ha-speaking-company-web` — bỏ qua nếu PM xác nhận không cần hiển thị (xem Maybe impacted).
4. `ha-speaking-haij-student-api` — chỉ nằm trong deploy order khi tính năng nghe hiểu được xác nhận lộ ra cho học sinh.

## `ha-speaking-api`

### Should verify

- `src/app/db/db_models.py:751-790` `[layer: entity]`
  - reason: 3 class `SituationListeningQuestion`/`SituationListeningAnswer`/`SituationListeningLog` đã có sẵn, khớp đúng migration (tên bảng, cột, FK, index) — đã đối chiếu, không thấy lệch
  - action: confirm không còn drift trước khi merge — không cần sửa code

### Maybe impacted

- `src/app/models/`, `src/app/services/`, `src/app/db/repositories/` `[layer: dto]`
  - reason: không có Pydantic model/service/repository nào cho `SituationListening*` — giống hệt pattern hiện tại của `SituationWord` (api chỉ giữ ORM, không có HTTP surface, admin-web thao tác DB trực tiếp)
  - action: xác nhận đây là chủ đích (pattern nhất quán) trước khi build API riêng ở tầng này

## `ha-speaking-admin-web`

### Must update

- `src/app/db/db_models.py` `[layer: entity]`
  - reason: chưa có class `SituationListeningQuestion`/`SituationListeningAnswer`/`SituationListeningLog` nào trong bản copy của admin-web (grep 0 kết quả) — khác với `SituationWord` đã được sync trước đó
  - action: copy nguyên 3 class từ `ha-speaking-api/src/app/db/db_models.py:751-790`, giữ đúng `__tablename__`, FK (`question_id`, `answer_id`, `haij_student_id` → `haij_students.id`), relationship, `Index("idx_situation_listening_questions_scene", scene)`

### Should verify

- `src/app/services/situation_word/`, `src/app/db/repositories/situation_word/` `[layer: service/repo]`
  - reason: **cảnh báo** — báo cáo audit trước (`2026-08-12-situationword-impact.md`) ghi nhận CRUD `situation_word` "already on main" đầy đủ file, nhưng hiện tại 2 thư mục này **chỉ còn `__pycache__`, toàn bộ file `.py` nguồn đã biến mất** (không nằm trong phạm vi migration `situation_listening` này, nhưng ảnh hưởng trực tiếp tới việc dùng pattern này làm mẫu)
  - action: xác nhận với team đây là xoá có chủ đích (refactor/checkout nhánh khác) hay mất code ngoài ý muốn, **trước khi** copy pattern CRUD này để làm màn hình quản trị `situation_listening`
- Route/template quản trị mới cho `situation_listening_questions` (list/register/edit + quản lý answers con) `[layer: template/validation]`
  - reason: hiện chưa có UI nào cho domain "listening" ở admin-web — cần xây mới hoàn toàn nếu PM cần màn hình quản trị nội dung nghe hiểu
  - action: xác nhận phạm vi PM (có cần admin CRUD ngay hay chỉ seed/import) trước khi ước lượng effort

## `ha-speaking-company-web`

### Maybe impacted

- Không tìm thấy entity nào cho `situation_word`/`situation_listening`; chỉ có `src/app/domain/entities/situation_practice.py` dùng cho lịch sử luyện tập hiện có `[layer: entity]`
  - reason: company dashboard hiện không đọc bảng nào thuộc domain "situation" ngoài `situation_practice`; chưa rõ tính năng nghe hiểu có cần hiện trong "lịch sử luyện tập" của company staff không
  - action: xác nhận PM — nếu cần hiển thị log nghe hiểu trong company dashboard, thêm entity `situation_listening_log.py` + cập nhật DTO/template lịch sử luyện tập tương tự `situation_practice.py`; nếu không, bỏ qua repo này

## `ha-speaking-haij-student-api`

### Should verify

- `src/app/domain/entities/situation_practice.py` + `src/app/application/interfaces/situation/`, `src/app/infrastructure/repositories/situation/` `[layer: entity/repo/dto]`
  - reason: domain "situation" ở student-api đã có đầy đủ tầng entity/interface/repo/dto/seed cho content-question-log-log_detail, nhưng **chưa có entity/dto/repo nào cho `SituationListening*`** (grep 0 kết quả) và bảng mới không có FK vào `situation_practice_contents` (chỉ dùng `scene` rời, giống `SituationWord`)
  - action: nếu tính năng nghe hiểu cần lộ ra cho học sinh, tạo mới theo đúng pattern hiện có: entity trong `domain/entities/`, interface trong `application/interfaces/situation/`, repo impl trong `infrastructure/repositories/situation/`, DTO trong `application/dto/`
- `src/app/presentation/controllers/` `[layer: dto]`
  - reason: **lưu ý quan trọng** — hiện tại domain "situation" (kể cả `SituationPractice` đã tồn tại lâu) **chưa có controller/route public nào** (grep thư mục `presentation/controllers` cho "situation" ra 0 kết quả) — nghĩa là feature "luyện tập tình huống" hiện có thể chưa lộ API cho học sinh, hoặc route nằm ở nơi khác chưa xác định
  - action: xác nhận với team endpoint hiện tại của `SituationPractice` nằm ở đâu trước khi giả định cần thêm controller mới cho `SituationListening`; nếu xác nhận cần lộ API, tạo controller mới theo mẫu `presentation/controllers/haij_vocabulary/controller.py` (route đề xuất dạng `GET /v1/scenes/{scene}/listening-questions`, `POST .../answer` để ghi `situation_listening_logs`)

### Maybe impacted

- `src/app/infrastructure/database/seeds/situation.py` `[layer: seed]`
  - reason: seed hiện tại chỉ cover `situation_practice_contents`/`situation_capture`, không có seed cho listening — không bắt buộc vì đây là nội dung do admin nhập (giống `situation_words`), không phải master data
  - action: không cần seed ngay; chỉ bổ sung nếu cần dữ liệu demo/test

## Checklist

### `ha-speaking-api`

#### entity

- [ ] `src/app/migrations/versions/887b68188247_add_situation_listening_table.py` — chạy `alembic upgrade head` trên DB dùng chung
- [ ] `src/app/db/db_models.py:751-790` — xác nhận không lệch so với migration (đã kiểm tra, khớp)

#### Tests

- [ ] chạy lại test suite liên quan trong `ha-speaking-api`

### `ha-speaking-admin-web`

#### entity

- [ ] `src/app/db/db_models.py` — thêm 3 class `SituationListeningQuestion`/`SituationListeningAnswer`/`SituationListeningLog`

#### Tests

- [ ] chạy lại test suite liên quan trong `ha-speaking-admin-web`

### Optional checks

- [ ] `ha-speaking-admin-web/src/app/services/situation_word/`, `db/repositories/situation_word/` — xác nhận lý do file nguồn bị xoá trước khi dùng làm mẫu CRUD
- [ ] `ha-speaking-admin-web` — xây route/template quản trị mới cho `situation_listening_questions` (nếu PM yêu cầu)
- [ ] `ha-speaking-company-web/src/app/domain/entities/` — thêm entity `situation_listening_log.py` nếu company dashboard cần hiển thị (xác nhận PM)
- [ ] `ha-speaking-haij-student-api` — implement entity/interface/repo/dto/controller mới cho `SituationListening*` nếu học sinh cần dùng tính năng nghe hiểu (xác nhận PM + xác nhận route hiện tại của `SituationPractice`)

## Ghi chú (Notes)

- Migration khớp hoàn toàn với ORM đã có sẵn trong `ha-speaking-api` — nguồn api sẵn sàng, không cần sửa gì thêm.
- `scene` là Integer rời, không FK — giống hệt pattern `SituationWord.scene`; cần xác nhận tầng ứng dụng validate giá trị `scene` hợp lệ khi tạo câu hỏi mới.
- **Phát hiện ngoài phạm vi nhưng đáng lưu ý:** báo cáo audit trước (`2026-08-12-situationword-impact.md`, ngày 2026-08-12) ghi nhận admin-web đã có CRUD đầy đủ cho `situation_word` "already on main". Tính đến hôm nay (2026-08-13), source file của CRUD đó đã biến mất khỏi `services/situation_word/` và `db/repositories/situation_word/` (chỉ còn `__pycache__`) — nên xác nhận trước khi dùng làm mẫu cho `situation_listening`.
- Domain "situation" ở `ha-speaking-haij-student-api` (bao gồm cả `SituationPractice` có từ trước) hiện không thấy controller public nào — cần xác nhận route thực tế trước khi lên kế hoạch thêm endpoint cho `SituationListening`.
- Company-web và student-api đều chưa có code tham chiếu `SituationListening*` — đúng như kỳ vọng cho bảng hoàn toàn mới; không có Must ở 2 repo này, chỉ Should verify/Maybe chờ xác nhận phạm vi PM.
