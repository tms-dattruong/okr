# BasicSituationPracticeContent — Báo cáo impact

## Thay đổi nguồn (Source change)

- Model: `BasicSituationPracticeContent`
- Migration: `ha-speaking-api/src/app/migrations/versions/53611a7e4414_update_situation_table_name.py`
- Tóm tắt:
  - Đổi tên toàn bộ nhóm bảng `situation_practice_*` sang tiền tố `basic_situation_practice_*` (thực chất là `create_table` bảng mới + `drop_table` bảng cũ, không phải `RENAME TABLE`)
  - Đổi tên 3 cột khóa ngoại theo tiền tố mới: `situation_practice_capture_id` → `basic_situation_practice_capture_id` (trên bảng questions), `situation_practice_log_id` → `basic_situation_practice_log_id` và `situation_practice_question_id` → `basic_situation_practice_question_id` (trên bảng log_details)
  - Cột `situation_practice_content_id` (trên captures và logs) giữ nguyên tên — không đổi

## Tóm tắt migration

- `create_table` 5 bảng mới: `basic_situation_practice_contents`, `basic_situation_practice_captures`, `basic_situation_practice_questions`, `basic_situation_practice_logs`, `basic_situation_practice_log_details` — cấu trúc cột giống bảng cũ, chỉ đổi tên bảng + 3 cột FK nêu trên
- `drop_table` 5 bảng cũ tương ứng: `situation_practice_contents`, `situation_practice_captures`, `situation_practice_questions`, `situation_practice_logs`, `situation_practice_log_details`
- Đây là cutover cứng (drop hẳn bảng cũ), không phải đổi tên tại chỗ — mọi ORM/raw SQL còn trỏ tên bảng cũ sẽ lỗi ngay khi migration chạy trên DB dùng chung
- Kèm thêm vài thay đổi comment cột không liên quan model này: `exam_logs.talk_session_id/exam_start_datetime/exam_end_datetime`, `scenarios.description` (chỉ đổi `comment`, không đổi kiểu/tên — bỏ qua trong audit này)

## Rủi ro

- `ha-speaking-admin-web` và `ha-speaking-company-web` có bản sao ORM riêng (`db_models.py` / `domain/entities/situation_practice.py`) vẫn khai báo `__tablename__` theo tên bảng cũ → mọi query CRUD vào tính năng situation practice ở 2 repo này sẽ lỗi "table doesn't exist" ngay sau khi migration chạy trên DB chung
- `ha-speaking-haij-student-api` có entity riêng cùng tên bảng cũ, đồng thời là consumer sâu nhất (tính năng "conversation" học sinh dùng chính là situation practice) — nếu không sync cùng lúc, toàn bộ luồng luyện tập hội thoại của học sinh sập
- 3 cột FK đổi tên (`*_capture_id`, `*_log_id`, `*_question_id`) chỉ ảnh hưởng object `SituationPracticeQuestion` và `SituationPracticeLogDetail` — nơi nào còn truy cập attribute cũ sẽ lỗi `AttributeError`/sai tên cột SQL
- `ha-speaking-haij-student-api/src/app/infrastructure/database/seeds/clear_seed_data.py` chạy raw SQL `DELETE FROM situation_practice_*` / `ALTER TABLE ... AUTO_INCREMENT` trên tên bảng cũ — script seed sẽ lỗi thẳng sau migration
- Bảng lang-mapping `situation_practice_content_lang_mappings` (cả 3 repo có bản sao) không nằm trong migration này (không đổi tên), join với content chỉ qua `scene` (không FK) — không lỗi nhưng tên bảng lệch với nhóm bảng `basic_situation_practice_*` mới, nên xác nhận có chủ đích hay cần đổi tên đồng bộ ở lần sau
- `ha-speaking-api/docs/db-erd.md` mô tả ERD cũ (tên bảng + quan hệ) chưa cập nhật — tài liệu sẽ sai lệch với schema thật

## `ha-speaking-api`

### Must update

- `docs/db-erd.md` `[layer: raw-sql]`
  - reason: ERD liệt kê quan hệ và cấu trúc cột theo tên bảng cũ (`situation_practice_contents`, `situation_practice_captures`, `situation_practice_questions`, `situation_practice_logs`, `situation_practice_log_details`) ở dòng 501-554, và các dòng 1148-1179 mô tả nhóm bảng "Basic Learning" join lỏng qua `situation_practice_contents.scene`
  - action: cập nhật toàn bộ tên bảng trong ERD sang `basic_situation_practice_*`; giữ nguyên mô tả join qua `scene` cho nhóm "Basic Learning"

### Maybe impacted

- `src/app/db/db_models.py` `[layer: entity]`
  - reason: model classes (`BasicSituationPracticeContent`, `BasicSituationPracticeCapture`, `BasicSituationPracticeQuestion`, `BasicSituationPracticeLog`, `BasicSituationPracticeLogDetail`) đã dùng đúng tên bảng mới và cột FK mới — đã đồng bộ với migration, không cần sửa
  - action: không cần hành động, chỉ xác nhận lại khi review
- `src/app/db/db_models.py` — class `SituationPracticeContentLangMapping` `[layer: entity]`
  - reason: bảng `situation_practice_content_lang_mappings` vẫn giữ tiền tố cũ dù bảng content chính đã đổi sang `basic_`; join qua `scene`, không FK nên không lỗi
  - action: xác nhận với PM có cần đổi tên bảng lang-mapping cho đồng bộ ở migration sau không

## `ha-speaking-admin-web`

### Must update

- `src/app/db/db_models.py` `[layer: entity]`
  - reason: class `SituationPracticeContent`, `SituationPracticeCapture`, `SituationPracticeQuestion`, `SituationPracticeLog`, `SituationPracticeLogDetail` (dòng 713-905) vẫn khai báo `__tablename__` theo tên bảng cũ — bảng này đã bị `drop_table` trong migration
  - action: đổi tên class sang `Basic*`, `__tablename__` sang `basic_situation_practice_*`, và đổi cột FK `situation_practice_capture_id` → `basic_situation_practice_capture_id`, `situation_practice_log_id` → `basic_situation_practice_log_id`, `situation_practice_question_id` → `basic_situation_practice_question_id`
- `src/app/db/repositories/situation_practice/situation_practice_content_repository.py` `[layer: repo]`
  - reason: import trực tiếp `SituationPracticeContent` từ `db_models.py`, toàn bộ query dùng class này
  - action: đổi import + tham chiếu sang `BasicSituationPracticeContent` sau khi model đổi tên
- `src/app/services/learning_statistics/learning_log_models.py` `[layer: service]`
  - reason: import `SituationPracticeLog` vào tuple `LEARNING_LOG_MODELS` dùng để tổng hợp thống kê học tập theo `haij_student_id`/`created_at`
  - action: đổi import sang `BasicSituationPracticeLog`; các field dùng (`haij_student_id`, `created_at`) không đổi tên nên logic tổng hợp không cần sửa thêm

### Should verify

- `src/app/services/situation_practice/situation_pratice_content.py` `[layer: service]`
  - reason: gọi `SituationPracticeContentRepository` qua tên class repository (không đổi), không truy cập trực tiếp field/table cũ
  - action: chạy lại route `/admin/situation-practice-content/*` sau khi rename để xác nhận không lỗi import dây chuyền
- `src/app/services/situation_word/situation_word_service.py` `[layer: service]`
  - reason: dùng `SituationPracticeContentRepository` để lấy `scene_situation` theo `scene`, biến local đặt tên `situation_practice_contents` (không phải tên bảng/cột thật)
  - action: rerun tính năng situation-word sau khi repository/model đổi tên
- `src/app/services/situation_listening/situation_listening_service.py` `[layer: service]`
  - reason: tương tự — gọi `SituationPracticeContentRepository.get_content_item_by_scene`, không đụng field/table cũ trực tiếp
  - action: rerun tính năng situation-listening sau khi repository/model đổi tên

## `ha-speaking-company-web`

### Must update

- `src/app/domain/entities/situation_practice.py` `[layer: entity]`
  - reason: toàn bộ 5 class + `SituationPracticeContentLangMapping` khai báo `__tablename__` theo tên bảng cũ, bảng đã bị `drop_table`
  - action: đổi tên class sang `Basic*`, `__tablename__` sang `basic_situation_practice_*`, đổi cột FK `situation_practice_capture_id` (trên Question) và `situation_practice_log_id`/`situation_practice_question_id` (trên LogDetail) sang tiền tố `basic_`; cột `situation_practice_content_id` (trên Capture, Log) giữ nguyên
- `src/app/domain/entities/__init__.py` `[layer: entity]`
  - reason: re-export `SituationPracticeContent`, `SituationPracticeCapture`, `SituationPracticeLog`, `SituationPracticeLogDetail`, `SituationPracticeQuestion`
  - action: đổi tên export sang `Basic*` khớp entity mới
- `src/app/domain/entities/haij_student.py` `[layer: entity]`
  - reason: relationship `situation_logs: Mapped[List["SituationPracticeLog"]]` tham chiếu class cũ qua forward-ref string
  - action: đổi string type-hint sang `"BasicSituationPracticeLog"`
- `src/app/infrastructure/persistence/student_repository_impl.py` `[layer: repo]`
  - reason: import và dùng trực tiếp `SituationPracticeContent`, `SituationPracticeLog` để đếm/join tính số bài luyện tập của học sinh (nhiều query, dòng 37-436)
  - action: đổi import + mọi tham chiếu class sang `Basic*`; attribute `situation_practice_content_id`, `haij_student_id`, `result` giữ nguyên tên
- `src/app/infrastructure/persistence/student_statistics_repository_impl.py` `[layer: repo]`
  - reason: import `SituationPracticeLog` để tính thống kê học sinh
  - action: đổi import sang `BasicSituationPracticeLog`
- `src/app/infrastructure/persistence/strategy/practice_log_strategy.py` `[layer: repo]`
  - reason: import và join `SituationPracticeContent`, `SituationPracticeLog` để build danh sách lịch sử luyện tập (practice log strategy pattern)
  - action: đổi import + join reference sang `Basic*`
- `src/app/interfaces/routes/homework_category_item_loader.py` `[layer: repo]`
  - reason: `select(SituationPracticeContent).order_by(SituationPracticeContent.scene)` để load candidate bài tập về nhà theo category
  - action: đổi tham chiếu sang `BasicSituationPracticeContent`
- `src/app/interfaces/routes/homework_item_candidate_loader.py` `[layer: repo]`
  - reason: nhiều query join `SituationPracticeContent` theo `scene` để lấy candidate item cho homework (dòng 148-194)
  - action: đổi toàn bộ tham chiếu sang `BasicSituationPracticeContent`

## `ha-speaking-haij-student-api`

Ghi chú: tính năng "conversation" ở repo này (DTO/service đặt tên `Conversation*`) chính là situation practice — impact sâu và trải khắp cả 4 layer.

### Must update

- `src/app/domain/entities/situation_practice.py` `[layer: entity]`
  - reason: 5 class entity + `SituationPracticeContentLangMapping`, khai báo `__tablename__` và FK theo tên cũ, bảng đã bị `drop_table`
  - action: đổi class name, `__tablename__`, và 2 cột FK cần đổi: `SituationPracticeQuestion.situation_practice_capture_id` → `basic_situation_practice_capture_id`; `SituationPracticeLogDetail.situation_practice_log_id`/`situation_practice_question_id` → tiền tố `basic_`
- `src/app/domain/entities/__init__.py` `[layer: entity]`
  - reason: export danh sách entity theo tên cũ
  - action: đổi export sang `Basic*`
- `src/app/domain/entities/student.py` `[layer: entity]`
  - reason: relationship `situation_logs: Mapped[List["SituationPracticeLog"]]` (dòng 61-62) tham chiếu class cũ
  - action: đổi sang `"BasicSituationPracticeLog"`
- `src/app/application/interfaces/situation/situation_capture_repository.py` `[layer: repo]`
  - reason: type hint `List[SituationPracticeCapture]`
  - action: đổi import + type hint sang `BasicSituationPracticeCapture`
- `src/app/application/interfaces/situation/situation_content_repository.py` `[layer: repo]`
  - reason: type hint trả về `SituationPracticeContent` ở nhiều method (`get_scene`, `get_scene_detail`)
  - action: đổi sang `BasicSituationPracticeContent`
- `src/app/application/interfaces/situation/situation_log_repository.py` `[layer: repo]`
  - reason: type hint `SituationPracticeLog` ở `get_situation_practice_logs`, `get_by_id`
  - action: đổi sang `BasicSituationPracticeLog`
- `src/app/application/interfaces/situation/situation_log_detail_repository.py` `[layer: repo]`
  - reason: type hint `SituationPracticeLogDetail`
  - action: đổi sang `BasicSituationPracticeLogDetail`
- `src/app/application/interfaces/situation/situation_question_repository.py` `[layer: repo]`
  - reason: type hint `SituationPracticeQuestion`
  - action: đổi sang `BasicSituationPracticeQuestion`
- `src/app/infrastructure/repositories/situation/situation_capture_repository.py` `[layer: repo]`
  - reason: implement interface trên, dùng entity cũ trong query
  - action: đổi import/tham chiếu sang `Basic*`
- `src/app/infrastructure/repositories/situation/situation_content_repository.py` `[layer: repo]`
  - reason: implement interface trên, nhiều query dùng `SituationPracticeContent`
  - action: đổi import/tham chiếu sang `BasicSituationPracticeContent`
- `src/app/infrastructure/repositories/situation/situation_log_repository.py` `[layer: repo]`
  - reason: implement interface trên, query dùng `SituationPracticeLog`
  - action: đổi import/tham chiếu sang `BasicSituationPracticeLog`
- `src/app/infrastructure/repositories/situation/situation_question_repository.py` `[layer: repo]`
  - reason: dòng 78 dùng trực tiếp cột đổi tên `SituationPracticeQuestion.situation_practice_capture_id`
  - action: đổi sang `BasicSituationPracticeQuestion.basic_situation_practice_capture_id`
- `src/app/infrastructure/repositories/situation/situation_log_detail_repository.py` `[layer: repo]`
  - reason: dòng 44, 46 dùng trực tiếp 2 cột đổi tên `situation_practice_log_id`, `situation_practice_question_id`
  - action: đổi sang `basic_situation_practice_log_id`, `basic_situation_practice_question_id` trên `BasicSituationPracticeLogDetail`
- `src/app/application/dto/situation_dto.py` `[layer: dto]`
  - reason: `ConversationQuestionDTO.situation_practice_capture_id` map trực tiếp từ field cùng tên trên entity Question — field này đã đổi tên trong migration
  - action: đổi field DTO sang `basic_situation_practice_capture_id` (hoặc alias tường minh nếu muốn giữ contract API không đổi)
- `src/app/application/services/conversation_service.py` `[layer: service]`
  - reason: import + dùng trực tiếp cả 5 class (`SituationPracticeContent/Capture/Log/LogDetail/Question`) xuyên suốt luồng tạo/chấm bài hội thoại
  - action: đổi toàn bộ import/tham chiếu class sang `Basic*`; chú ý field `conversation.situation_practice_content_id` giữ nguyên tên, không cần đổi
- `src/app/application/services/conversation_practice_service.py` `[layer: service]`
  - reason: import trực tiếp `SituationPracticeCapture`, dùng làm generic type cho `BaseServiceImpl`
  - action: đổi sang `BasicSituationPracticeCapture`
- `src/app/application/services/lesson_service.py` `[layer: service]`
  - reason: import trực tiếp `SituationPracticeContent`, dùng làm generic type cho `BaseServiceImpl` và nhiều return type
  - action: đổi sang `BasicSituationPracticeContent`
- `src/app/application/services/homework_service.py` `[layer: service]`
  - reason: dòng 49, 154 import và dùng trực tiếp `SituationPracticeContent` để load candidate bài tập
  - action: đổi sang `BasicSituationPracticeContent`
- `src/app/infrastructure/repositories/homework_checkers/situation_completion_checker.py` `[layer: repo]`
  - reason: dùng `SituationPracticeLog` để kiểm tra học sinh đã hoàn thành scenario (dòng 34-72)
  - action: đổi sang `BasicSituationPracticeLog`; field `situation_practice_content_id`, `haij_student_id`, `result`, `exam_type` giữ nguyên
- `src/app/infrastructure/repositories/learned_word_repository.py` `[layer: repo]`
  - reason: join `SituationPracticeContent`/`SituationPracticeLog` để tính từ vựng đã học qua scene đã pass
  - action: đổi tham chiếu class sang `Basic*`
- `src/app/infrastructure/repositories/learned_expression_repository.py` `[layer: repo]`
  - reason: join tương tự learned_word nhưng cho expression
  - action: đổi tham chiếu class sang `Basic*`
- `src/app/infrastructure/repositories/practice_log_repository.py` `[layer: repo]`
  - reason: `SQLAlchemyRepository[SituationPracticeLog]` — generic type trực tiếp
  - action: đổi sang `BasicSituationPracticeLog`
- `src/app/infrastructure/repositories/practice_log/activity_log.py` `[layer: repo]`
  - reason: dùng `SituationPracticeLog` để tính hoạt động luyện tập theo ngày
  - action: đổi sang `BasicSituationPracticeLog`
- `src/app/infrastructure/repositories/practice_log/level_completed.py` `[layer: repo]`
  - reason: join `SituationPracticeContent`/`SituationPracticeLog` để tính level đã hoàn thành
  - action: đổi tham chiếu class sang `Basic*`
- `src/app/infrastructure/repositories/practice_log/practice_streak.py` `[layer: repo]`
  - reason: dùng `SituationPracticeLog.created_at` để tính streak luyện tập
  - action: đổi sang `BasicSituationPracticeLog`
- `src/app/infrastructure/repositories/practice_log/statistics.py` `[layer: repo]`
  - reason: dùng `SituationPracticeContent`/`SituationPracticeLog` để tính thống kê tổng (star, words, expressions)
  - action: đổi tham chiếu class sang `Basic*`
- `src/app/infrastructure/database/seeds/situation.py` `[layer: seed]`
  - reason: seed `SituationPracticeContent`, `SituationPracticeContentLangMapping` — bảng content đã đổi tên
  - action: đổi import/tham chiếu sang `BasicSituationPracticeContent`
- `src/app/infrastructure/database/seeds/situation_capture.py` `[layer: seed]`
  - reason: seed `SituationPracticeCapture`/`SituationPracticeQuestion`, dùng trực tiếp cột đổi tên `situation_practice_capture_id` (dòng 58-106)
  - action: đổi class + cột sang `Basic*` / `basic_situation_practice_capture_id`
- `src/app/infrastructure/database/seeds/dev.py` `[layer: seed]`
  - reason: seed toàn bộ 5 bảng, dùng cả 3 cột FK bị đổi tên (`situation_practice_capture_id`, `situation_practice_log_id`, `situation_practice_question_id` — dòng 248-357)
  - action: đổi toàn bộ class + 3 cột FK sang tiền tố `basic_`
- `src/app/infrastructure/database/seeds/clear_seed_data.py` `[layer: raw-sql]`
  - reason: raw SQL `DELETE FROM`/`ALTER TABLE ... AUTO_INCREMENT` trực tiếp trên 5 tên bảng cũ — bảng đã bị drop, script sẽ lỗi ngay khi chạy
  - action: đổi toàn bộ tên bảng trong raw SQL sang `basic_situation_practice_*`

### Should verify

- `src/app/application/services/practice_log_service.py` `[layer: service]`
  - reason: chỉ dùng qua interface `ISituationPracticeLogRepository` và message code `SituationPracticeCodes` (không phải entity/table), không truy cập field/table trực tiếp — nhưng nằm giữa luồng chấm bài chính
  - action: rerun toàn bộ luồng practice-log sau khi interface implementation đổi tên entity bên dưới
- `src/app/application/services/homework_progress_service.py` `[layer: service]`
  - reason: chỉ dùng `SituationPracticeExamTypeEnum` (enum không đổi tên trong migration này) để map `category_level_4` → `exam_type`
  - action: xác nhận mapping vẫn đúng, không cần đổi code
- `src/app/infrastructure/database/seeds/lets_talk.py` `[layer: seed]`
  - reason: chỉ tham chiếu tên file JSON `situation_practice_contents.json` (không phải tên bảng/class thật)
  - action: xác nhận file JSON seed có cần đổi tên đồng bộ hay giữ nguyên
- `tests/unit/service/test_conversation_service.py`, `tests/unit/controllers/test_conversation_controller.py`, `tests/unit/controllers/test_lesson_controller.py`, `tests/unit/service/test_conversation_practice_service.py`, `tests/unit/service/test_lesson_service.py` `[layer: entity]`
  - reason: mock/fixture khả năng tham chiếu tên class hoặc field cũ
  - action: rerun và sửa fixture theo tên entity/field mới sau khi áp dụng checklist trên

### Maybe impacted

- `src/app/domain/entities/enum.py` `[layer: entity]`
  - reason: `SituationPracticeQuestionJudgmentEnum`, `SituationPracticeExamTypeEnum` không nằm trong migration (không đổi bảng/cột) — chỉ trùng tiền tố tên gọi
  - action: không bắt buộc đổi; cân nhắc đổi tên cho nhất quán ở lần rename model tiếp theo nếu team muốn

## Checklist

### `ha-speaking-api`

#### raw-sql

- [ ] `docs/db-erd.md` — cập nhật tên bảng ERD sang `basic_situation_practice_*`

#### Tests

- [ ] chạy lại test suite liên quan trong `ha-speaking-api`

### `ha-speaking-admin-web`

#### entity

- [ ] `src/app/db/db_models.py` — đổi 5 class + tablename + 3 cột FK sang `basic_`

#### repo

- [ ] `src/app/db/repositories/situation_practice/situation_practice_content_repository.py` — đổi import sang `BasicSituationPracticeContent`

#### service

- [ ] `src/app/services/learning_statistics/learning_log_models.py` — đổi import sang `BasicSituationPracticeLog`

#### Tests

- [ ] chạy lại test suite liên quan trong `ha-speaking-admin-web`

### `ha-speaking-company-web`

#### entity

- [ ] `src/app/domain/entities/situation_practice.py` — đổi 5 class + tablename + 2 cột FK sang `basic_`
- [ ] `src/app/domain/entities/__init__.py` — đổi export sang `Basic*`
- [ ] `src/app/domain/entities/haij_student.py` — đổi relationship type-hint sang `BasicSituationPracticeLog`

#### repo

- [ ] `src/app/infrastructure/persistence/student_repository_impl.py` — đổi import/tham chiếu sang `Basic*`
- [ ] `src/app/infrastructure/persistence/student_statistics_repository_impl.py` — đổi import sang `BasicSituationPracticeLog`
- [ ] `src/app/infrastructure/persistence/strategy/practice_log_strategy.py` — đổi import/join sang `Basic*`
- [ ] `src/app/interfaces/routes/homework_category_item_loader.py` — đổi tham chiếu sang `BasicSituationPracticeContent`
- [ ] `src/app/interfaces/routes/homework_item_candidate_loader.py` — đổi tham chiếu sang `BasicSituationPracticeContent`

#### Tests

- [ ] chạy lại test suite liên quan trong `ha-speaking-company-web`

### `ha-speaking-haij-student-api`

#### entity

- [ ] `src/app/domain/entities/situation_practice.py` — đổi 5 class + tablename + 2 cột FK sang `basic_`
- [ ] `src/app/domain/entities/__init__.py` — đổi export sang `Basic*`
- [ ] `src/app/domain/entities/student.py` — đổi relationship type-hint sang `BasicSituationPracticeLog`

#### repo

- [ ] `src/app/application/interfaces/situation/situation_capture_repository.py` — đổi type hint sang `BasicSituationPracticeCapture`
- [ ] `src/app/application/interfaces/situation/situation_content_repository.py` — đổi type hint sang `BasicSituationPracticeContent`
- [ ] `src/app/application/interfaces/situation/situation_log_repository.py` — đổi type hint sang `BasicSituationPracticeLog`
- [ ] `src/app/application/interfaces/situation/situation_log_detail_repository.py` — đổi type hint sang `BasicSituationPracticeLogDetail`
- [ ] `src/app/application/interfaces/situation/situation_question_repository.py` — đổi type hint sang `BasicSituationPracticeQuestion`
- [ ] `src/app/infrastructure/repositories/situation/situation_capture_repository.py` — đổi tham chiếu sang `Basic*`
- [ ] `src/app/infrastructure/repositories/situation/situation_content_repository.py` — đổi tham chiếu sang `BasicSituationPracticeContent`
- [ ] `src/app/infrastructure/repositories/situation/situation_log_repository.py` — đổi tham chiếu sang `BasicSituationPracticeLog`
- [ ] `src/app/infrastructure/repositories/situation/situation_question_repository.py` — đổi cột `situation_practice_capture_id` → `basic_situation_practice_capture_id`
- [ ] `src/app/infrastructure/repositories/situation/situation_log_detail_repository.py` — đổi cột `situation_practice_log_id`/`situation_practice_question_id` → tiền tố `basic_`
- [ ] `src/app/infrastructure/repositories/homework_checkers/situation_completion_checker.py` — đổi tham chiếu sang `BasicSituationPracticeLog`
- [ ] `src/app/infrastructure/repositories/learned_word_repository.py` — đổi tham chiếu sang `Basic*`
- [ ] `src/app/infrastructure/repositories/learned_expression_repository.py` — đổi tham chiếu sang `Basic*`
- [ ] `src/app/infrastructure/repositories/practice_log_repository.py` — đổi generic type sang `BasicSituationPracticeLog`
- [ ] `src/app/infrastructure/repositories/practice_log/activity_log.py` — đổi tham chiếu sang `BasicSituationPracticeLog`
- [ ] `src/app/infrastructure/repositories/practice_log/level_completed.py` — đổi tham chiếu sang `Basic*`
- [ ] `src/app/infrastructure/repositories/practice_log/practice_streak.py` — đổi tham chiếu sang `BasicSituationPracticeLog`
- [ ] `src/app/infrastructure/repositories/practice_log/statistics.py` — đổi tham chiếu sang `Basic*`

#### dto

- [ ] `src/app/application/dto/situation_dto.py` — đổi field `situation_practice_capture_id` → `basic_situation_practice_capture_id`

#### service

- [ ] `src/app/application/services/conversation_service.py` — đổi toàn bộ import/tham chiếu sang `Basic*`
- [ ] `src/app/application/services/conversation_practice_service.py` — đổi sang `BasicSituationPracticeCapture`
- [ ] `src/app/application/services/lesson_service.py` — đổi sang `BasicSituationPracticeContent`
- [ ] `src/app/application/services/homework_service.py` — đổi sang `BasicSituationPracticeContent`

#### seed

- [ ] `src/app/infrastructure/database/seeds/situation.py` — đổi sang `BasicSituationPracticeContent`
- [ ] `src/app/infrastructure/database/seeds/situation_capture.py` — đổi class + cột FK sang `basic_`
- [ ] `src/app/infrastructure/database/seeds/dev.py` — đổi toàn bộ class + 3 cột FK sang `basic_`
- [ ] `src/app/infrastructure/database/seeds/clear_seed_data.py` — đổi tên bảng raw SQL sang `basic_situation_practice_*`

#### Tests

- [ ] chạy lại test suite liên quan trong `ha-speaking-haij-student-api`

### Optional checks

- [ ] `ha-speaking-api/src/app/db/db_models.py` (class `SituationPracticeContentLangMapping`) — xác nhận có cần đổi tên bảng lang-mapping cho đồng bộ *(Maybe impacted)*
- [ ] `ha-speaking-haij-student-api/src/app/domain/entities/enum.py` — xác nhận có cần đổi tên 2 enum cho đồng bộ *(Maybe impacted)*
- [ ] `ha-speaking-haij-student-api/src/app/infrastructure/database/seeds/lets_talk.py` — xác nhận tên file JSON seed *(Maybe impacted)*

## Ghi chú (Notes)

- Migration dùng `create_table` + `drop_table` (không phải `RENAME TABLE`), nên đây là cutover cứng — 3 repo consumer phải deploy đồng thời với migration, không thể rollout dần
- `ha-speaking-haij-student-api` là repo bị ảnh hưởng rộng nhất vì tính năng "conversation" (đặt tên khác trong DTO/service) chính là situation practice — soát kỹ layer service/dto khi review
- Chỉ 3 cột FK đổi tên (`*_capture_id` trên Question, `*_log_id`/`*_question_id` trên LogDetail); cột `situation_practice_content_id` (trên Capture, Log) **không đổi** — tránh sửa nhầm
- Không bao gồm kế hoạch rollout/rollback/thứ tự deploy trong báo cáo này theo quy định
