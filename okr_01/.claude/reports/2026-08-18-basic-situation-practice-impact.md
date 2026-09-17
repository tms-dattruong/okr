# BasicSituationPractice — Báo cáo impact

## Thay đổi nguồn (Source change)

- Model: `BasicSituationPractice*` (đổi tên/redesign từ `SituationPractice*`)
- Migration: `ha-speaking-api/src/app/migrations/versions/dc6116284358_xxxxxxxx.py`
- Tóm tắt:
  - Đổi tên 6 bảng: `situation_practice_content_lang_mappings`, `situation_practice_contents`, `situation_practice_captures`, `situation_practice_questions`, `situation_practice_logs`, `situation_practice_log_details` → `basic_situation_practice_*` (tương ứng)
  - Cấu trúc cột giữ nguyên (so sánh `upgrade`/`downgrade`) — chỉ đổi tên bảng và tên cột FK tham chiếu (`situation_practice_content_id` → `basic_situation_practice_content_id`, tương tự cho các FK khác)
  - `db_models.py` của `ha-speaking-api` **đã cập nhật xong** sang class `BasicSituationPractice*` — migration khớp với model hiện tại của repo nguồn

*(2 thay đổi khác trong cùng file migration — thêm `created_at`/`updated_at` cho `company_user_branches`, và đổi `comment` cho `exam_logs`/`scenarios` — nằm ngoài phạm vi báo cáo này theo lựa chọn của user.)*

## Tóm tắt migration

- `upgrade()`: tạo mới 6 bảng `basic_situation_practice_*` (cấu trúc cột giống bảng cũ), sau đó `drop_table` 6 bảng `situation_practice_*` cũ
- `downgrade()`: ngược lại — tạo lại 6 bảng `situation_practice_*` cũ, xoá 6 bảng `basic_situation_practice_*`
- Không có thay đổi kiểu dữ liệu, nullability, hay field mới/field bị xoá trong nhóm bảng này — bản chất là **đổi tên bảng + đổi tên cột FK liên quan**

## Rủi ro

- Sau khi migration chạy trên MySQL chung, 6 bảng `situation_practice_*` bị xoá hoàn toàn — nhưng `ha-speaking-admin-web`, `ha-speaking-company-web`, `ha-speaking-haij-student-api` vẫn còn ORM/entity map vào tên bảng cũ → lỗi SQL "table doesn't exist" ngay khi có query chạm tới các bảng này
- `ha-speaking-haij-student-api` có phạm vi ảnh hưởng lớn nhất: entity, toàn bộ package `repositories/situation/`, nhiều service nghiệp vụ (`conversation_service.py`, `lesson_service.py`, `practice_log_service.py`...), controller, seed, test đều còn tên cũ — nguy cơ vỡ nhiều luồng cùng lúc (hội thoại, homework, thống kê học tập)
- `ha-speaking-company-web`: `student_repository_impl.py` dựng subquery/join phức tạp (`situation_practice_count`, join theo `scene`) trên `SituationPracticeLog`/`SituationPracticeContent` — đổi tên sai cột/alias có thể làm sai số liệu thống kê học viên mà không báo lỗi rõ ràng
- FK string và `relationship()` string (`ForeignKey("situation_practice_contents.id")`, `relationship("SituationPracticeContent")`) nằm rải trong nhiều file ở cả 3 repo — thiếu đồng bộ 1 chỗ có thể gây lỗi SQLAlchemy mapper configure ngay lúc import module (crash toàn app, không chỉ 1 request)
- File seed JSON `situation_practice_contents_lang_map.json` (student-api) vẫn dùng tên cũ — cần rà soát nếu logic seed phụ thuộc tên file

## `ha-speaking-api`

*(Không có finding — `db_models.py` đã đổi sang `BasicSituationPractice*` khớp migration; đã kiểm tra `db/views/views.py`, `db/seed.py`, `db/seed/`, `src/app/models/` không có tham chiếu `situation_practice` cũ. Repo nguồn đã đồng bộ đầy đủ.)*

## `ha-speaking-admin-web`

### Must update

- `src/app/db/db_models.py` `[layer: entity]`
  - reason: 5 class (`SituationPracticeContent`, `SituationPracticeCapture`, `SituationPracticeLog`, `SituationPracticeQuestion`, `SituationPracticeLogDetail`, dòng 713–848) vẫn map vào tên bảng cũ `situation_practice_*` — bảng này sẽ bị xoá trên MySQL chung
  - action: đổi tên class → `BasicSituationPractice*`, `__tablename__` → `basic_situation_practice_*`, đổi FK string (`situation_practice_content_id` → `basic_situation_practice_content_id` v.v.) và `relationship("SituationPracticeContent", ...)` → `relationship("BasicSituationPracticeContent", ...)`
- `src/app/services/learning_statistics/learning_log_models.py` `[layer: service]`
  - reason: import `SituationPracticeLog` ở 2 vị trí (dòng 11, 25) — sẽ vỡ khi class ở `db_models.py` đổi tên
  - action: đổi import/tham chiếu sang `BasicSituationPracticeLog`

### Optional checks

- `src/app/db/repositories/situation_practice/`, `src/app/services/situation_practice/` `[layer: repo/service]`
  - reason: 2 thư mục tồn tại nhưng chỉ chứa `__pycache__` cũ, không có file `.py` nào được commit git — không phải code sống
  - action: có thể xoá thư mục rác này khi dọn dẹp (không bắt buộc theo migration này)

## `ha-speaking-company-web`

### Must update

- `src/app/domain/entities/situation_practice.py` `[layer: entity]`
  - reason: định nghĩa 6 class `SituationPractice*` (dòng 21–153) map vào bảng cũ, gồm FK string và `relationship()` nội bộ
  - action: đổi tên file/class → `BasicSituationPractice*`, đổi toàn bộ `__tablename__`, FK string, relationship string sang tên bảng/class mới
- `src/app/domain/entities/__init__.py` `[layer: entity]`
  - reason: re-export `SituationPracticeContent/Capture/Log/Question/LogDetail/ContentLangMapping` (dòng 30, 96–101)
  - action: cập nhật export list theo tên class mới
- `src/app/domain/entities/haij_student.py` `[layer: entity]`
  - reason: import `SituationPracticeLog` và relationship `situation_logs` (dòng 25, 51–52) tham chiếu class sẽ đổi tên
  - action: đổi import + relationship string sang `BasicSituationPracticeLog`
- `src/app/infrastructure/persistence/student_repository_impl.py` `[layer: repo]`
  - reason: dùng nặng nhất (36 hit) — subquery `situation_practice_count` group theo `haij_student_id`, join `SituationPracticeContent`/`SituationPracticeLog` nhiều nơi (dòng 17–45, 91–105, 237–306, 357–436)
  - action: đổi import class, đổi tên cột FK trong `.filter()`/`.join()`, giữ nguyên alias `situation_practice_count` nếu không đổi field DTO (xem finding DTO dưới)
- `src/app/infrastructure/persistence/student_statistics_repository_impl.py` `[layer: repo]`
  - reason: import `SituationPracticeLog` 2 lần (dòng 35, 55)
  - action: đổi sang `BasicSituationPracticeLog` (và kiểm tra import trùng lặp luôn khi sửa)
- `src/app/infrastructure/persistence/strategy/practice_log_strategy.py` `[layer: repo]`
  - reason: select/join `SituationPracticeLog`/`SituationPracticeContent` cho log strategy (dòng 20–152)
  - action: đổi import + tên class trong select/join/filter
- `src/app/interfaces/routes/homework_category_item_loader.py`, `src/app/interfaces/routes/homework_item_candidate_loader.py` `[layer: repo]`
  - reason: cả 2 file import và query trực tiếp `SituationPracticeContent` cho luồng chọn nội dung homework
  - action: đổi import + select/filter sang `BasicSituationPracticeContent`
- `src/app/common/constant/constant.py` `[layer: raw-sql]`
  - reason: hằng số CSV column name `"situation_practice_count"` (dòng 13)
  - action: xác nhận tên cột export CSV có cần đổi theo hay giữ nguyên (đây là field DTO tính toán, không phải tên bảng — xem ghi chú Should verify)

### Should verify

- `src/app/application/dto/student_dto.py` `[layer: dto]`
  - reason: field `situation_practice_count` (dòng 54) là field tính toán, không map trực tiếp tên bảng — có thể không cần đổi tên field nếu contract API/CSV giữ nguyên
  - action: xác nhận với PM/FE có cần đổi tên field DTO theo naming mới hay giữ nguyên để tránh vỡ contract
- `src/app/templates/pages/student/index.html` `[layer: template]`
  - reason: render `{{ student.situation_practice_count }}` (dòng 173) — phụ thuộc trực tiếp field DTO trên
  - action: chỉ cần sửa nếu field DTO đổi tên

### Maybe impacted

- `src/app/domain/entities/enum.py` `[layer: entity]`
  - reason: `SituationPracticeQuestionJudgmentEnum` (dòng 31) là tên enum, không map tên bảng/cột DB — đổi tên chỉ để nhất quán naming, không bắt buộc về mặt schema
  - action: đổi tên enum thành `BasicSituationPracticeQuestionJudgmentEnum` nếu muốn nhất quán, không ảnh hưởng runtime nếu bỏ qua

## `ha-speaking-haij-student-api`

### Must update

- `src/app/domain/entities/situation_practice.py` `[layer: entity]`
  - reason: định nghĩa 6 class `SituationPractice*` (44 hit) map vào bảng cũ, gồm FK và relationship nội bộ
  - action: đổi tên file/class + `__tablename__` + FK string + relationship string sang `BasicSituationPractice*`
- `src/app/domain/entities/__init__.py` `[layer: entity]`
  - reason: re-export toàn bộ `SituationPractice*` (17 hit)
  - action: cập nhật export list
- `src/app/domain/entities/student.py` `[layer: entity]`
  - reason: import `SituationPracticeLog`, relationship `situation_logs` (dòng 28, 61–62)
  - action: đổi import + relationship string
- `src/app/domain/entities/enum.py` `[layer: entity]`
  - reason: `SituationPracticeQuestionJudgmentEnum`, `SituationPracticeExamTypeEnum` (dòng 26, 52) — enum gắn trực tiếp với model bị đổi tên trong cùng module
  - action: đổi tên đồng bộ để tránh nhầm lẫn khi import cùng file entity
- `src/app/infrastructure/repositories/situation/` (5 file: `situation_content_repository.py`, `situation_log_repository.py`, `situation_question_repository.py`, `situation_capture_repository.py`, `situation_log_detail_repository.py`, + `__init__.py`) `[layer: repo]`
  - reason: toàn bộ package repository riêng cho model này (89 + 68 + 16 + 11 + 19 + 10 hit) — CRUD/query chính đi qua đây
  - action: đổi import class + FK/column reference trong từng repo; đổi tên package nếu muốn nhất quán (`situation/` → `basic_situation_practice/`)
- `src/app/infrastructure/repositories/learned_word_repository.py`, `learned_expression_repository.py` `[layer: repo]`
  - reason: join `MasterLearnWord`/expression với `SituationPracticeContent` theo `scene` (16 hit mỗi file)
  - action: đổi import + điều kiện join sang `BasicSituationPracticeContent`
- `src/app/infrastructure/repositories/practice_log_repository.py`, `practice_log/practice_streak.py`, `practice_log/activity_log.py`, `practice_log/statistics.py`, `practice_log/level_completed.py` `[layer: repo]`
  - reason: dùng `SituationPracticeLog` làm type param hoặc trong tính streak/activity/statistics/level-completed
  - action: đổi import + type reference sang `BasicSituationPracticeLog`
- `src/app/infrastructure/repositories/homework_checkers/situation_completion_checker.py` `[layer: repo]`
  - reason: checker hoàn thành homework dựa trên `SituationPractice*` (17 hit)
  - action: đổi import + logic check sang class mới
- `src/app/infrastructure/repositories/__init__.py` `[layer: repo]`
  - reason: wire DI cho các repo `SituationPractice*` (dòng 79–83, 161–165)
  - action: cập nhật DI binding theo tên class/repo mới
- `src/app/application/dto/situation_dto.py`, `src/app/application/dto/statistic_dto.py` `[layer: dto]`
  - reason: field/type tham chiếu `SituationPractice*`
  - action: đổi tên field/type theo model mới, xác nhận contract API có đổi hay không
- `src/app/application/services/conversation_service.py`, `conversation_practice_service.py`, `lesson_service.py`, `practice_log_service.py`, `statistic_service.py`, `homework_progress_service.py` `[layer: service]`
  - reason: 6 service nghiệp vụ chính dùng `SituationPractice*` (77, 23, 12, 9, 5, 4 hit) — hội thoại, luyện tập, thống kê, tiến độ homework
  - action: đổi import + gọi hàm repo/entity theo tên mới; ưu tiên `conversation_service.py` vì hit nhiều nhất
- `src/app/application/services/basic_listening_practice_service.py`, `basic_grammar_quiz_service.py`, `basic_grammar_service.py`, `basic_vocabulary_service.py`, `basic_expression_service.py`, `basic_vocabulary_practice_service.py`, `basic_expression_practice_service.py`, `src/app/application/services/homework_service.py` `[layer: service]`
  - reason: mỗi file có 2 hit import nhẹ `SituationPracticeLog`/`Content` (tiền tố `basic_` trong tên file này là của domain riêng, không liên quan model đang đổi)
  - action: đổi import sang class mới, không cần đổi tên file
- `src/app/presentation/controllers/conversation/controller.py`, `conversation/schema.py`, `conversation_practice/controller.py`, `lesson/controller.py`, `statistic/controller.py`, `practice_log/controller.py` `[layer: controller]`
  - reason: 6 controller/schema expose API dựa trên `SituationPractice*` qua service ở trên
  - action: đổi import/type reference; kiểm tra `response_model`/schema không lộ tên class cũ ra API contract
- `src/app/infrastructure/database/seeds/dev.py`, `situation_capture.py`, `situation.py`, `mappings.py`, `clear_seed_data.py`, `lets_talk.py`, `json/situation_practice_contents_lang_map.json` `[layer: seed]`
  - reason: toàn bộ seed data cho model (70, 28, 24, 13, 10, 1 hit) — `situation.py` load file JSON theo tên cũ, `mappings.py` insert vào `SituationPracticeContentLangMapping`, `clear_seed_data.py` liệt kê bảng để dọn seed
  - action: đổi import class trong `.py`; đổi tên file JSON `situation_practice_contents_lang_map.json` → `basic_situation_practice_contents_lang_map.json` và sửa đường dẫn load trong `situation.py`

### Should verify

- `tests/unit/service/test_conversation_service.py`, `test_conversation_practice_service.py`, `test_lesson_service.py` `[layer: test]`
  - reason: 103 + 55 + 9 hit mock/fixture dùng `SituationPractice*` cho service tương ứng ở trên
  - action: rà soát fixture/mock theo tên class mới sau khi service đổi xong; ưu tiên `test_conversation_service.py`

### Tests

- [ ] chạy lại test suite liên quan sau khi đổi tên (đặc biệt `test_conversation_service.py`, `test_conversation_practice_service.py`)

## Checklist

### `ha-speaking-admin-web`

#### entity

- [ ] `src/app/db/db_models.py` — đổi 5 class + `__tablename__` + FK string sang `BasicSituationPractice*`

#### service

- [ ] `src/app/services/learning_statistics/learning_log_models.py` — đổi 2 import `SituationPracticeLog` → `BasicSituationPracticeLog`

#### Tests

- [ ] chạy lại test suite liên quan trong `ha-speaking-admin-web`

### `ha-speaking-company-web`

#### entity

- [ ] `src/app/domain/entities/situation_practice.py` — đổi tên file/6 class + FK/relationship
- [ ] `src/app/domain/entities/__init__.py` — cập nhật export list
- [ ] `src/app/domain/entities/haij_student.py` — đổi import + relationship `situation_logs`

#### repo

- [ ] `src/app/infrastructure/persistence/student_repository_impl.py` — đổi import + FK trong subquery/join `situation_practice_count`
- [ ] `src/app/infrastructure/persistence/student_statistics_repository_impl.py` — đổi 2 import `SituationPracticeLog`
- [ ] `src/app/infrastructure/persistence/strategy/practice_log_strategy.py` — đổi import + select/join
- [ ] `src/app/interfaces/routes/homework_category_item_loader.py` — đổi import + query `SituationPracticeContent`
- [ ] `src/app/interfaces/routes/homework_item_candidate_loader.py` — đổi import + query `SituationPracticeContent`

#### raw-sql

- [ ] `src/app/common/constant/constant.py` — xác nhận đổi hằng số CSV `situation_practice_count` hay giữ nguyên

#### Tests

- [ ] chạy lại test suite liên quan trong `ha-speaking-company-web`

### Optional checks

- [ ] `src/app/application/dto/student_dto.py` — xác nhận đổi field `situation_practice_count` hay giữ nguyên *(Should verify)*
- [ ] `src/app/templates/pages/student/index.html` — sửa theo nếu field DTO đổi *(Should verify)*
- [ ] `src/app/domain/entities/enum.py` — đổi tên `SituationPracticeQuestionJudgmentEnum` cho nhất quán *(Maybe impacted)*

### `ha-speaking-haij-student-api`

#### entity

- [ ] `src/app/domain/entities/situation_practice.py` — đổi tên file/6 class + FK/relationship
- [ ] `src/app/domain/entities/__init__.py` — cập nhật export list
- [ ] `src/app/domain/entities/student.py` — đổi import + relationship `situation_logs`
- [ ] `src/app/domain/entities/enum.py` — đổi 2 enum class name

#### repo

- [ ] `src/app/infrastructure/repositories/situation/` (5 file + `__init__.py`) — đổi import + FK/column trong toàn bộ package
- [ ] `src/app/infrastructure/repositories/learned_word_repository.py` — đổi join theo `scene`
- [ ] `src/app/infrastructure/repositories/learned_expression_repository.py` — đổi join theo `scene`
- [ ] `src/app/infrastructure/repositories/practice_log_repository.py` + `practice_log/practice_streak.py`, `activity_log.py`, `statistics.py`, `level_completed.py` — đổi import/type `SituationPracticeLog`
- [ ] `src/app/infrastructure/repositories/homework_checkers/situation_completion_checker.py` — đổi logic check
- [ ] `src/app/infrastructure/repositories/__init__.py` — cập nhật DI binding

#### dto

- [ ] `src/app/application/dto/situation_dto.py` — đổi field/type
- [ ] `src/app/application/dto/statistic_dto.py` — đổi field/type

#### service

- [ ] `src/app/application/services/conversation_service.py` — đổi import + logic (77 hit)
- [ ] `src/app/application/services/conversation_practice_service.py` — đổi import + logic
- [ ] `src/app/application/services/lesson_service.py` — đổi import + logic
- [ ] `src/app/application/services/practice_log_service.py` — đổi import + logic
- [ ] `src/app/application/services/statistic_service.py` — đổi import + logic
- [ ] `src/app/application/services/homework_progress_service.py` — đổi import + logic
- [ ] `src/app/application/services/basic_listening_practice_service.py`, `basic_grammar_quiz_service.py`, `basic_grammar_service.py`, `basic_vocabulary_service.py`, `basic_expression_service.py`, `basic_vocabulary_practice_service.py`, `basic_expression_practice_service.py`, `homework_service.py` — đổi import nhẹ

#### controller

- [ ] `src/app/presentation/controllers/conversation/controller.py` + `schema.py` — đổi import/type
- [ ] `src/app/presentation/controllers/conversation_practice/controller.py` — đổi import/type
- [ ] `src/app/presentation/controllers/lesson/controller.py` — đổi import/type
- [ ] `src/app/presentation/controllers/statistic/controller.py` — đổi import/type
- [ ] `src/app/presentation/controllers/practice_log/controller.py` — đổi import/type

#### seed

- [ ] `src/app/infrastructure/database/seeds/dev.py` — đổi import/logic seed
- [ ] `src/app/infrastructure/database/seeds/situation_capture.py` — đổi import/logic seed
- [ ] `src/app/infrastructure/database/seeds/situation.py` — đổi import + đường dẫn load JSON
- [ ] `src/app/infrastructure/database/seeds/mappings.py` — đổi import `SituationPracticeContentLangMapping`
- [ ] `src/app/infrastructure/database/seeds/clear_seed_data.py` — đổi danh sách class cần dọn
- [ ] `src/app/infrastructure/database/seeds/lets_talk.py` — đổi import
- [ ] `src/app/infrastructure/database/seeds/json/situation_practice_contents_lang_map.json` — đổi tên file theo naming mới

#### Tests

- [ ] `tests/unit/service/test_conversation_service.py` — rà soát fixture/mock
- [ ] `tests/unit/service/test_conversation_practice_service.py` — rà soát fixture/mock
- [ ] `tests/unit/service/test_lesson_service.py` — rà soát fixture/mock
- [ ] chạy lại test suite liên quan trong `ha-speaking-haij-student-api`

## Ghi chú (Notes)

- `ha-speaking-api` đã đồng bộ đầy đủ với migration (model, views, seed, docs không có tham chiếu cũ) — không có finding cho repo này
- 3 repo consumer (`admin-web`, `company-web`, `student-api`) đều 100% còn dùng tên cũ `situation_practice_*`/`SituationPractice*` — chưa có repo nào bắt đầu đổi tên
- `ha-speaking-haij-student-api` có phạm vi lớn nhất do model này gắn liền với luồng hội thoại (`conversation_service.py`) và luyện tập chính, không chỉ là 1 feature phụ
- File tài liệu `.cursor/skills/sqlalchemy/SKILL.md` (student-api, dòng 123–126) cũng có ví dụ code dùng tên cũ — không ảnh hưởng runtime nhưng nên cập nhật để tránh doc lỗi thời
- 2 thư mục rác `situation_practice/` (chỉ chứa `__pycache__`, không có source git-tracked) ở admin-web không nằm trong scope bắt buộc, liệt kê ở Optional checks để dọn dẹp nếu muốn
- Không bao gồm kế hoạch rollout/rollback/deploy order theo yêu cầu
