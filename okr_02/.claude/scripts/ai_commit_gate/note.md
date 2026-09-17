local env_file = ... | Biến chỉ tồn tại trong hàm, 
-f "$env_file" | kiểm tra file có không
[ ] = lệnh test cũ của shell.

while ...; do Lặp đến hết file.

IFS= Tạm tắt tách field theo space/tab — đọc nguyên dòng.

read -r line  Đọc 1 dòng vào line. -r = không hiểu \ là escape.
|| [ -n "$line" ] Nếu dòng cuối không có newline, read fail nhưng vẫn còn nội dung → vẫn xử lý dòng đó.

=~ so sánh với ...

:-60 Không set → mặc định 60 giây.

\#   |  Comment|

|VAR=value | Gán biến |

|"$VAR" | Lấy giá trị (an toàn có space) |

|local | Biến chỉ trong hàm |

|fn() { } | Định nghĩa hàm |

[ -f file ]   File tồn tại?

[ -z str ]  Chuỗi rỗng?

[[ a == pattern ]] So khớp pattern

|| “hoặc”: lệnh trái fail thì chạy phải

&& “và”: lệnh trái OK thì chạy phải

continue Sang vòng lặp tiếp

return 0 Thoát hàm thành công

${VAR:-default} Fallback nếu trống

export Biến môi trường

$(cmd) Lấy output lệnh

>&2 In ra stderr

2>/dev/null Giấu stderr

-n = chuỗi không rỗng?