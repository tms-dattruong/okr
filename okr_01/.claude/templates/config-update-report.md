# Cập nhật config model-impact

Layout for `/update-model-impact-config` (skill `model-impact-config-update`).

**Language:** follow `.claude/config/report-writing-style.md` — changelog prose in clear, non-mixed Vietnamese; keep identifiers as-is: paths, class/field/table names, repo names, layer tags, config section headings. (Config file bodies themselves stay English — see `model-impact-config-update` rules.)

## Mode và input

- Mode: `<reports | full-scan | full-scan+reports>`
- Reports: `<PATH_OR_none>`
- Chạy lúc: `<DATE>`

## File đã sửa

- `<CONFIG_PATH>` — `<WHY_VI>`
- *(Nếu không sửa file nào: viết một dòng "Không có thay đổi config.")*

## Thêm / sửa / xóa

### `<CONFIG_PATH>`

- Added: `<QUOTED_OR_SUMMARIZED_ROW_VI>`
- Updated: `<BEFORE>` → `<AFTER>`
- Removed: `<ROW_AND_EVIDENCE_VI>` *(chỉ khi model rename/removed hoặc path biến mất trên disk)*

*(Omit empty bullets. One subsection per changed config file.)*

## Bỏ qua (Skipped)

- `<MODEL_OR_PATH>` — `<LOW_CONFIDENCE_OR_ALREADY_CURRENT_VI>`

## Ghi chú (Notes)

- High-confidence matches only for domain-map rows
- `full-scan` không ghi `impact-map.md` và không sửa change-type matrix
- Save: `.claude/reports/YYYY-MM-DD-config-update.md`
