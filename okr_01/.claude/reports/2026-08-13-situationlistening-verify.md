# SituationListening — Báo cáo verify

## Nguồn (Source)

- Model: `SituationListeningQuestion`, `SituationListeningAnswer`, `SituationListeningLog`
- Baseline report: `.claude/reports/2026-08-13-situationlistening-impact.md`
- Verified at: 2026-08-13

## Tóm tắt (Summary)

- Resolved: `4` / `6`
- Still pending: `2`
- Not found: `0`

## Resolved

- `ha-speaking-api/src/app/db/db_models.py:751-790`
  - evidence: 3 class `SituationListeningQuestion`/`SituationListeningAnswer`/`SituationListeningLog` vẫn khớp đúng migration `887b68188247` (tên bảng, cột, FK, index `idx_situation_listening_questions_scene`) — không phát sinh lệch mới

- `ha-speaking-admin-web/src/app/db/db_models.py`
  - evidence: đã thêm đủ 3 class `SituationListeningQuestion` (line 758), `SituationListeningAnswer` (line 775), `SituationListeningLog` (line 787) — khớp bản gốc `ha-speaking-api`

- `ha-speaking-admin-web/src/app/services/situation_word/`, `src/app/db/repositories/situation_word/`
  - evidence: `situation_word_service.py` và `situation_word_repository.py` đã xuất hiện lại trong 2 thư mục (trước đó chỉ còn `__pycache__`) — nghi vấn "mất code" ở baseline đã được xác nhận là tạm thời/đã khôi phục

- Route/template quản trị `situation_listening_questions` (admin-web)
  - evidence: đã build đầy đủ CRUD mới — `src/app/services/situation_listening/situation_listening_service.py`, `src/app/db/repositories/situation_listening/situation_listening_question_repository.py` + `situation_listening_answer_repository.py`, `src/app/utils/check/situation_listening_check.py`, template `src/app/templates/admin/situation-listening/{list,register,edit,detail}.html`

## Still pending

- `ha-speaking-haij-student-api/src/app/domain/entities/`, `src/app/application/interfaces/situation/`, `src/app/infrastructure/repositories/situation/`
  - old ref found: không tìm thấy file nào tên `situation_listening*` ở cả 3 tầng (grep 0 kết quả) — vẫn chưa có entity/interface/repo cho `SituationListening*`
  - suggested action: nếu PM xác nhận tính năng nghe hiểu lộ ra cho học sinh, tạo entity trong `domain/entities/`, interface trong `application/interfaces/situation/`, repo impl trong `infrastructure/repositories/situation/`, DTO trong `application/dto/` theo đúng pattern `situation_practice`/`situation_capture` hiện có

- `ha-speaking-haij-student-api/src/app/presentation/controllers/`
  - old ref found: vẫn không có controller nào cho domain "situation" (grep 0 kết quả, kể cả `SituationPractice` cũ)
  - suggested action: xác nhận với team route hiện tại của `SituationPractice` nằm ở đâu trước khi thêm controller mới cho `SituationListening` (đề xuất route `GET /v1/scenes/{scene}/listening-questions`, `POST .../answer`)

## Not found

- (không có)

## Ghi chú (Notes)

- `ha-speaking-company-web`: baseline chỉ có `Maybe impacted`, không có Must/Should nên không tính vào tổng verify — hiện vẫn chưa có entity nào cho `situation_listening` (đúng như kỳ vọng, chờ xác nhận PM).
- Chưa thấy test nào trong `ha-speaking-admin-web/src/tests` cho `situation_listening` dù CRUD đã build — nên bổ sung test trước khi merge.
- Re-scan dùng cùng search terms từ baseline report (`SituationListening`, `situation_listening_*`, tên file/thư mục liên quan).
