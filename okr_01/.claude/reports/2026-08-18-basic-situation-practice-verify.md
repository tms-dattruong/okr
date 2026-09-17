# BasicSituationPractice — Báo cáo verify

## Nguồn (Source)

- Model: `BasicSituationPractice*` (đổi tên/redesign từ `SituationPractice*`)
- Baseline report: `.claude/reports/2026-08-18-basic-situation-practice-impact.md`
- Verified at: 2026-08-18

## Tóm tắt (Summary)

- Resolved: `0` / `28`
- Still pending: `28`
- Not found: `0`

*(Quét lại toàn bộ 28 finding Must update + Should verify từ baseline, trên cả 3 repo consumer. Không phát hiện bất kỳ tham chiếu `BasicSituationPractice*`/`basic_situation_practice_*` nào — nghĩa là chưa có thay đổi nào được áp dụng kể từ audit.)*

## Resolved

*(Không có — 0/28 finding được xử lý.)*

## Still pending

### `ha-speaking-admin-web`

- `src/app/db/db_models.py`
  - old ref found: 5 class `SituationPracticeContent` (dòng 713), `SituationPracticeCapture` (729), `SituationPracticeLog` (785), `SituationPracticeQuestion` (796), `SituationPracticeLogDetail` (840) — cùng toàn bộ `__tablename__` và FK string (`situation_practice_content_id`, `situation_practice_capture_id`, `situation_practice_log_id`, `situation_practice_question_id`) và `relationship("SituationPracticeContent", ...)`
  - suggested action: đổi tên class + `__tablename__` + FK string + relationship string sang `BasicSituationPractice*`/`basic_situation_practice_*` như baseline đã ghi
- `src/app/services/learning_statistics/learning_log_models.py`
  - old ref found: import `SituationPracticeLog` (dòng 11, 25)
  - suggested action: đổi sang `BasicSituationPracticeLog`

### `ha-speaking-company-web`

- `src/app/domain/entities/situation_practice.py`
  - old ref found: nguyên 6 class `SituationPractice*` (dòng 21–153), file chưa đổi tên
  - suggested action: đổi tên file + 6 class + `__tablename__` + FK/relationship string sang `BasicSituationPractice*`
- `src/app/domain/entities/__init__.py`
  - old ref found: import `situation_practice import *` (dòng 30), `__all__` (96–101) vẫn liệt kê tên cũ
  - suggested action: cập nhật export list theo tên class mới
- `src/app/domain/entities/haij_student.py`
  - old ref found: import `SituationPracticeLog` (dòng 25), relationship `situation_logs` dùng string `"SituationPracticeLog"` (51–52)
  - suggested action: đổi import + relationship string sang `BasicSituationPracticeLog`
- `src/app/infrastructure/persistence/student_repository_impl.py`
  - old ref found: import (dòng 17–18) + subquery/label `situation_practice_count` (37, 41, 91, 366, 369, 413–414) + join dùng `SituationPracticeContent`/`SituationPracticeLog` rải khắp 237–306, 357–436
  - suggested action: đổi import class + FK trong `.filter()`/`.join()`; giữ alias `situation_practice_count` nếu DTO/CSV không đổi tên field
- `src/app/infrastructure/persistence/student_statistics_repository_impl.py`
  - old ref found: import `SituationPracticeLog` (dòng 35, 55)
  - suggested action: đổi sang `BasicSituationPracticeLog`
- `src/app/infrastructure/persistence/strategy/practice_log_strategy.py`
  - old ref found: import (dòng 20–21) + select/join/filter dùng cột `situation_practice_content_id` (110) suốt 104–152
  - suggested action: đổi import + tên class/cột trong select/join/filter
- `src/app/interfaces/routes/homework_category_item_loader.py`
  - old ref found: import `SituationPracticeContent` (dòng 19), dùng ở query (98)
  - suggested action: đổi import + query sang `BasicSituationPracticeContent`
- `src/app/interfaces/routes/homework_item_candidate_loader.py`
  - old ref found: import (dòng 26), dùng ở 148, 151, 153, 191, 193–194
  - suggested action: đổi import + query sang `BasicSituationPracticeContent`
- `src/app/common/constant/constant.py`
  - old ref found: hằng số literal `"situation_practice_count"` (dòng 13)
  - suggested action: xác nhận có đổi tên hằng số CSV theo hay giữ nguyên (field DTO tính toán, không phải tên bảng)
- `src/app/application/dto/student_dto.py` *(Should verify)*
  - old ref found: field `situation_practice_count` (dòng 54) — chưa đổi
  - suggested action: xác nhận với PM/FE có cần đổi tên field DTO theo naming mới hay giữ nguyên
- `src/app/templates/pages/student/index.html` *(Should verify)*
  - old ref found: `{{ student.situation_practice_count }}` (dòng 173) — nhất quán với DTO chưa đổi ở trên
  - suggested action: chỉ sửa nếu DTO đổi tên field

### `ha-speaking-haij-student-api`

- `src/app/domain/entities/situation_practice.py`
  - old ref found: nguyên 6 class `SituationPractice*` — không có tham chiếu `Basic` nào trong repo
  - suggested action: đổi tên file/6 class + `__tablename__` + FK/relationship string
- `src/app/domain/entities/__init__.py`
  - old ref found: re-export tên cũ, không đổi
  - suggested action: cập nhật export list
- `src/app/domain/entities/student.py`
  - old ref found: import `SituationPracticeLog`, relationship `situation_logs`
  - suggested action: đổi import + relationship string
- `src/app/domain/entities/enum.py`
  - old ref found: `SituationPracticeQuestionJudgmentEnum`, `SituationPracticeExamTypeEnum` — chưa đổi
  - suggested action: đổi tên đồng bộ 2 enum
- `src/app/infrastructure/repositories/situation/` (6 file)
  - old ref found: số hit khớp chính xác baseline (89/68/16/11/19/10) — chưa động vào
  - suggested action: đổi import class + FK/column trong toàn bộ package
- `src/app/infrastructure/repositories/learned_word_repository.py`, `learned_expression_repository.py`
  - old ref found: mỗi file 16 hit, khớp baseline — chưa đổi
  - suggested action: đổi import + điều kiện join theo `scene`
- `src/app/infrastructure/repositories/practice_log_repository.py` + `practice_log/practice_streak.py`, `activity_log.py`, `statistics.py`, `level_completed.py`
  - old ref found: chưa đổi ở cả 5 file (3/3/13/33/17 hit)
  - suggested action: đổi import/type reference sang `BasicSituationPracticeLog`
- `src/app/infrastructure/repositories/homework_checkers/situation_completion_checker.py`
  - old ref found: 16 hit (baseline 17, sai biệt không đáng kể) — không có `Basic` nào
  - suggested action: đổi import + logic check
- `src/app/infrastructure/repositories/__init__.py`
  - old ref found: DI binding vẫn dùng `Situation*Repository` cũ (10 hit)
  - suggested action: cập nhật DI binding theo tên class/repo mới
- `src/app/application/dto/situation_dto.py`, `statistic_dto.py`
  - old ref found: 2 hit + 1 hit, chưa đổi
  - suggested action: đổi tên field/type theo model mới
- `src/app/application/services/conversation_service.py`, `conversation_practice_service.py`, `lesson_service.py`, `practice_log_service.py`, `statistic_service.py`, `homework_progress_service.py`
  - old ref found: hit khớp gần như chính xác baseline (77/23/12/9/5/4) — chưa đổi
  - suggested action: đổi import + logic; ưu tiên `conversation_service.py`
- `src/app/application/services/basic_listening_practice_service.py`, `basic_grammar_quiz_service.py`, `basic_grammar_service.py`, `basic_vocabulary_service.py`, `basic_expression_service.py`, `basic_vocabulary_practice_service.py`, `basic_expression_practice_service.py`, `homework_service.py`
  - old ref found: mỗi file đúng 2 hit import — chưa đổi
  - suggested action: đổi import sang class mới
- `src/app/presentation/controllers/conversation/controller.py` + `schema.py`, `conversation_practice/controller.py`, `lesson/controller.py`, `statistic/controller.py`, `practice_log/controller.py`
  - old ref found: 18/6/14/5/3/2 hit — chưa đổi
  - suggested action: đổi import/type reference; kiểm tra `response_model`/schema không lộ tên cũ
- `src/app/infrastructure/database/seeds/dev.py`, `situation_capture.py`, `situation.py`, `mappings.py`, `clear_seed_data.py`, `lets_talk.py`, `json/situation_practice_contents_lang_map.json`
  - old ref found: hit khớp baseline (70/28/24/13/10/1); file JSON seed vẫn tên cũ (`situation_practice_captures.json`, `situation_practice_contents.json`, `situation_practice_contents_lang_map.json`), `situation.py` vẫn load theo tên cũ
  - suggested action: đổi import trong `.py`; đổi tên file JSON và sửa đường dẫn load trong `situation.py`
- `tests/unit/service/test_conversation_service.py`, `test_conversation_practice_service.py`, `test_lesson_service.py` *(Should verify)*
  - old ref found: 102/55/9 hit (baseline 103/55/9, sai biệt không đáng kể) — fixture/mock chưa đổi
  - suggested action: rà soát fixture/mock theo tên class mới sau khi service đổi xong

## Not found

*(Không có — toàn bộ 28 file/khu vực từ baseline vẫn tồn tại đúng đường dẫn cũ, không file nào bị xoá/di chuyển.)*

## Ghi chú (Notes)

- Cả 3 repo consumer (`admin-web`, `company-web`, `haij-student-api`) đều **chưa áp dụng bất kỳ phần nào** của checklist trong baseline — grep repo-wide xác nhận 0 tham chiếu `BasicSituationPractice*`/`basic_situation_practice_*` ở cả 3 repo
- `ha-speaking-haij-student-api` vẫn là repo rủi ro cao nhất — toàn bộ 15 finding Must/Should còn nguyên, ảnh hưởng trực tiếp luồng hội thoại (`conversation_service.py`) và luyện tập
- Chưa cần chạy `/update-model-impact-config` — domain map/scan path trong baseline vẫn khớp đúng thực tế code, không có gì lệch cần cập nhật
- Không bao gồm kế hoạch rollout/rollback/deploy order theo quy tắc chung
