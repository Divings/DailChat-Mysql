import Dail_Core
import traceback

try:
    Dail_Core.main()
except Exception as e:
    print("")
    print(" 予期せぬエラーが発生しました。")
    print(f" {type(e).__name__}: {e}")
    traceback.print_exc()