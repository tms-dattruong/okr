# BasicSituationPracticeContent — Báo cáo verify

## Nguồn (Source)

- Model: `BasicSituationPracticeContent`
- Baseline report: `.claude/reports/2026-08-14-basicsituationpracticecontent-impact.md`
- Migration: `ha-speaking-api/src/app/migrations/versions/53611a7e4414_update_situation_table_name.py`
- Verified at: 2026-08-14

## Tóm tắt (Summary)

- Resolved: `4` / `53`
- Still pending: `49`
- Not found: `0` 

Hầu hết checklist trong baseline **chưa được áp dụng**. Toàn bộ entity/repo/service/seed cốt lõi ở cả 3 repo consumer vẫn tham chiếu tên class/bảng/cột cũ (`SituationPractice*`, `situation_practice_*`). Riêng `ha-speaking-api` (docs ERD) và phần lớn `ha-speaking-haij-student-api` (business logic) là nhóm pending nặng nhất.

## Resolved

- `ha-speaking-admin-web/src/app/services/situation_practice/situation_pratice_content.py`
  - evidence: chỉ gọi `SituationPracticeContentRepository` qua tên class repository, không có field/table cũ trực tiếp — đúng như dự đoán "Should verify", không cần sửa code
- `ha-speaking-admin-web/src/app/services/situation_listening/situation_listening_service.py`
  - evidence: tương tự — chỉ gọi `SituationPracticeContentRepository.get_content_item_by_scene`, không tham chiếu bảng/field cũ trực tiếp
- `ha-speaking-haij-student-api/tests/unit/service/test_conversation_practice_service.py`
  - evidence: không còn tham chiếu class/field/table cũ nào theo pattern baseline
- `ha-speaking-haij-student-api/tests/unit/service/test_lesson_service.py`
  - evidence: không còn tham chiếu class/field/table cũ nào theo pattern baseline

## Still pending

### `ha-speaking-api`

- `docs/db-erd.md`
  - old ref found: `situation_practice_contents`, `situation_practice_captures`, `situation_practice_questions`, `situation_practice_logs`, `situation_practice_log_details`, `situation_practice_capture_id`, `situation_practice_log_id`, `situation_practice_question_id` (dòng 501-557, 1148-1179)
  - suggested action: cập nhật ERD sang tên bảng/cột `basic_situation_practice_*`

### `ha-speaking-admin-web`

- `src/app/db/db_models.py`
  - old ref found: class `SituationPracticeContent/Capture/Question/Log/LogDetail`, tablename `situation_practice_*`, cột `situation_practice_capture_id`/`situation_practice_log_id`/`situation_practice_question_id`
  - suggested action: đổi tên class + tablename sang `Basic*`/`basic_situation_practice_*`, đổi 3 cột FK sang tiền tố `basic_`
- `src/app/db/repositories/situation_practice/situation_practice_content_repository.py`
  - old ref found: import và toàn bộ tham chiếu `SituationPracticeContent`
  - suggested action: đổi sang `BasicSituationPracticeContent` sau khi model đổi tên
- `src/app/services/learning_statistics/learning_log_models.py`
  - old ref found: import `SituationPracticeLog` trong `LEARNING_LOG_MODELS`
  - suggested action: đổi sang `BasicSituationPracticeLog`

### `ha-speaking-company-web`

- `src/app/domain/entities/situation_practice.py`
  - old ref found: cả 5 class + tablename cũ, cột `situation_practice_capture_id`/`situation_practice_log_id`/`situation_practice_question_id`
  - suggested action: đổi toàn bộ sang `Basic*`/`basic_situation_practice_*` theo baseline
- `src/app/domain/entities/__init__.py`
  - old ref found: export `SituationPracticeContent/Capture/Log/LogDetail/Question`
  - suggested action: đổi export sang `Basic*`
- `src/app/domain/entities/haij_student.py`
  - old ref found: relationship type-hint `"SituationPracticeLog"` (dòng 51-52)
  - suggested action: đổi sang `"BasicSituationPracticeLog"`
- `src/app/infrastructure/persistence/student_repository_impl.py`
  - old ref found: import + nhiều tham chiếu `SituationPracticeContent`/`SituationPracticeLog`
  - suggested action: đổi toàn bộ sang `Basic*`
- `src/app/infrastructure/persistence/student_statistics_repository_impl.py`
  - old ref found: import `SituationPracticeLog`
  - suggested action: đổi sang `BasicSituationPracticeLog`
- `src/app/infrastructure/persistence/strategy/practice_log_strategy.py`
  - old ref found: import + join `SituationPracticeContent`/`SituationPracticeLog`
  - suggested action: đổi sang `Basic*`
- `src/app/interfaces/routes/homework_category_item_loader.py`
  - old ref found: `SituationPracticeContent` trong query load candidate
  - suggested action: đổi sang `BasicSituationPracticeContent`
- `src/app/interfaces/routes/homework_item_candidate_loader.py`
  - old ref found: nhiều query join `SituationPracticeContent`
  - suggested action: đổi sang `BasicSituationPracticeContent`

### `ha-speaking-haij-student-api`

- `src/app/domain/entities/situation_practice.py`
  - old ref found: cả 5 class + tablename cũ, 2 cột FK (`situation_practice_capture_id` trên Question; `situation_practice_log_id`/`situation_practice_question_id` trên LogDetail)
  - suggested action: đổi toàn bộ sang `Basic*`/`basic_situation_practice_*`
- `src/app/domain/entities/__init__.py`
  - old ref found: export cả 5 class cũ
  - suggested action: đổi sang `Basic*`
- `src/app/domain/entities/student.py`
  - old ref found: relationship type-hint `SituationPracticeLog` (dòng 28, 61-62)
  - suggested action: đổi sang `BasicSituationPracticeLog`
- `src/app/application/interfaces/situation/situation_capture_repository.py`
  - old ref found: type hint `SituationPracticeCapture`
  - suggested action: đổi sang `BasicSituationPracticeCapture`
- `src/app/application/interfaces/situation/situation_content_repository.py`
  - old ref found: type hint `SituationPracticeContent`
  - suggested action: đổi sang `BasicSituationPracticeContent`
- `src/app/application/interfaces/situation/situation_log_repository.py`
  - old ref found: type hint `SituationPracticeLog`
  - suggested action: đổi sang `BasicSituationPracticeLog`
- `src/app/application/interfaces/situation/situation_log_detail_repository.py`
  - old ref found: type hint `SituationPracticeLogDetail`
  - suggested action: đổi sang `BasicSituationPracticeLogDetail`
- `src/app/application/interfaces/situation/situation_question_repository.py`
  - old ref found: type hint `SituationPracticeQuestion`
  - suggested action: đổi sang `BasicSituationPracticeQuestion`
- `src/app/infrastructure/repositories/situation/situation_capture_repository.py`
  - old ref found: tham chiếu `SituationPracticeCapture` xuyên suốt
  - suggested action: đổi sang `BasicSituationPracticeCapture`
- `src/app/infrastructure/repositories/situation/situation_content_repository.py`
  - old ref found: tham chiếu `SituationPracticeContent`/`SituationPracticeLog` dày đặc (~50 dòng)
  - suggested action: đổi sang `Basic*`
- `src/app/infrastructure/repositories/situation/situation_log_repository.py`
  - old ref found: tham chiếu `SituationPracticeLog/Capture/Question/LogDetail`, cột `situation_practice_capture_id`/`situation_practice_question_id`/`situation_practice_log_id` (dòng 160, 169-170, 230, 239-240)
  - suggested action: đổi class + 3 cột FK sang `Basic*`/tiền tố `basic_`
- `src/app/infrastructure/repositories/situation/situation_question_repository.py`
  - old ref found: dòng 78 `SituationPracticeQuestion.situation_practice_capture_id`
  - suggested action: đổi sang `BasicSituationPracticeQuestion.basic_situation_practice_capture_id`
- `src/app/infrastructure/repositories/situation/situation_log_detail_repository.py`
  - old ref found: dòng 44, 46 `situation_practice_log_id`/`situation_practice_question_id`
  - suggested action: đổi sang `basic_situation_practice_log_id`/`basic_situation_practice_question_id`
- `src/app/application/dto/situation_dto.py`
  - old ref found: dòng 10 field `situation_practice_capture_id` trong `ConversationQuestionDTO`
  - suggested action: đổi sang `basic_situation_practice_capture_id`
- `src/app/application/services/conversation_service.py`
  - old ref found: import + tham chiếu cả 5 class cũ, cột `situation_practice_question_id`/`situation_practice_log_id` ở nhiều dòng (306, 404-405, 422)
  - suggested action: đổi toàn bộ class + cột FK liên quan sang `Basic*`/tiền tố `basic_`
- `src/app/application/services/conversation_practice_service.py`
  - old ref found: import `SituationPracticeCapture`
  - suggested action: đổi sang `BasicSituationPracticeCapture`
- `src/app/application/services/lesson_service.py`
  - old ref found: import + generic type `SituationPracticeContent`
  - suggested action: đổi sang `BasicSituationPracticeContent`
- `src/app/application/services/homework_service.py`
  - old ref found: dòng 49, 154 `SituationPracticeContent`
  - suggested action: đổi sang `BasicSituationPracticeContent`
- `src/app/infrastructure/repositories/homework_checkers/situation_completion_checker.py`
  - old ref found: `SituationPracticeLog`/`SituationPracticeContent` xuyên suốt
  - suggested action: đổi sang `Basic*`
- `src/app/infrastructure/repositories/learned_word_repository.py`
  - old ref found: `SituationPracticeContent`/`SituationPracticeLog` trong join
  - suggested action: đổi sang `Basic*`
- `src/app/infrastructure/repositories/learned_expression_repository.py`
  - old ref found: `SituationPracticeContent`/`SituationPracticeLog` trong join
  - suggested action: đổi sang `Basic*`
- `src/app/infrastructure/repositories/practice_log_repository.py`
  - old ref found: `SQLAlchemyRepository[SituationPracticeLog]`
  - suggested action: đổi sang `BasicSituationPracticeLog`
- `src/app/infrastructure/repositories/practice_log/activity_log.py`
  - old ref found: `SituationPracticeLog` xuyên suốt
  - suggested action: đổi sang `BasicSituationPracticeLog`
- `src/app/infrastructure/repositories/practice_log/level_completed.py`
  - old ref found: `SituationPracticeContent`/`SituationPracticeLog`
  - suggested action: đổi sang `Basic*`
- `src/app/infrastructure/repositories/practice_log/practice_streak.py`
  - old ref found: `SituationPracticeLog.created_at`
  - suggested action: đổi sang `BasicSituationPracticeLog`
- `src/app/infrastructure/repositories/practice_log/statistics.py`
  - old ref found: `SituationPracticeContent`/`SituationPracticeLog`
  - suggested action: đổi sang `Basic*`
- `src/app/infrastructure/database/seeds/situation.py`
  - old ref found: `SituationPracticeContent`, tablename `situation_practice_contents`
  - suggested action: đổi sang `BasicSituationPracticeContent`
- `src/app/infrastructure/database/seeds/situation_capture.py`
  - old ref found: `SituationPracticeCapture`/`SituationPracticeQuestion`, cột `situation_practice_capture_id` (dòng 106, 85)
  - suggested action: đổi class + cột FK sang `Basic*`/`basic_situation_practice_capture_id`
- `src/app/infrastructure/database/seeds/dev.py`
  - old ref found: toàn bộ 5 class + 3 cột FK (`situation_practice_capture_id`, `situation_practice_log_id`, `situation_practice_question_id`)
  - suggested action: đổi toàn bộ sang `Basic*`/tiền tố `basic_`
- `src/app/infrastructure/database/seeds/clear_seed_data.py`
  - old ref found: raw SQL `DELETE FROM`/`ALTER TABLE` trên cả 5 tên bảng cũ — bảng đã bị drop, script sẽ lỗi khi chạy
  - suggested action: đổi toàn bộ tên bảng raw SQL sang `basic_situation_practice_*`
- `src/app/application/services/practice_log_service.py`
  - old ref found: dòng 60 gọi `get_situation_practice_logs` (tên method chứa "situation_practice_logs" — chỉ là tên method, không phải bảng thật)
  - suggested action: xác nhận lại đây chỉ là false-positive theo tên method, không cần sửa; nếu muốn đồng bộ có thể đổi tên method
- `src/app/application/services/homework_progress_service.py`
  - old ref found: dòng 298 docstring nhắc `SituationPracticeLog.exam_type`
  - suggested action: chỉ là comment/docstring — cập nhật cho khớp tên entity mới, không ảnh hưởng runtime
- `src/app/infrastructure/database/seeds/lets_talk.py`
  - old ref found: dòng 19 tên file `situation_practice_contents.json`
  - suggested action: xác nhận có cần đổi tên file JSON seed cho đồng bộ hay giữ nguyên (không bắt buộc)
- `tests/unit/service/test_conversation_service.py`
  - old ref found: field `situation_practice_capture_id`/`situation_practice_question_id` trong fixture/mock (8 vị trí)
  - suggested action: cập nhật fixture theo tên field mới sau khi sửa entity/DTO
- `tests/unit/controllers/test_conversation_controller.py`
  - old ref found: `SituationPracticeContent`, field `situation_practice_capture_id` trong fixture
  - suggested action: cập nhật fixture theo tên class/field mới
- `tests/unit/controllers/test_lesson_controller.py`
  - old ref found: `SituationPracticeContent` trong fixture
  - suggested action: cập nhật fixture theo tên class mới

## Not found

*(không có)*

## Ghi chú (Notes)

- Baseline dùng chung 1 bộ search term (class name / table name / 3 cột FK đổi tên) để re-scan toàn bộ 53 finding Must+Should
- 49/53 vẫn pending — về bản chất checklist audit gốc **chưa được áp dụng** ở cả `ha-speaking-admin-web`, `ha-speaking-company-web`, và gần như toàn bộ `ha-speaking-haij-student-api`; chỉ 4 mục vốn không yêu cầu sửa code (2 Should ở admin-web, 2 test file ở student-api) được xác nhận resolved
- Rủi ro cao nhất không đổi so với baseline: bảng cũ đã bị `drop_table`, nên khi migration này chạy trên DB dùng chung mà code 3 repo consumer chưa cập nhật, toàn bộ tính năng situation practice (đặc biệt luồng "conversation" ở `ha-speaking-haij-student-api`) và seed script `clear_seed_data.py` sẽ lỗi ngay lập tức
- Khuyến nghị: áp dụng checklist Must trước (entity → repo → service/dto → seed) ở cả 3 repo consumer rồi chạy lại `/verify-model-impact` trước khi merge/deploy
