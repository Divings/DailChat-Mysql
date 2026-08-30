import Dail_Core
import traceback
import sys
sys.stdin.reconfigure(
    encoding="utf-8",
    errors="replace"
)

sys.stdout.reconfigure(
    encoding="utf-8",
    errors="replace"
)

sys.stderr.reconfigure(
    encoding="utf-8",
    errors="replace"
)

try:
    Dail_Core.main()
except Exception as e:
    print("")
    print(" 予期せぬエラーが発生しました。")
    print(f" {type(e).__name__}: {e}")
    traceback.print_exc()