# aiwff-mini

**一台跑在你自己機器上的個人主腦。** 有靈魂、有跨對話的記憶、會保護自己不被改壞。

不是聊天機器人包裝，也不是 prompt 集合。它解決的是四件具體的事：

| 問題 | 這套怎麼解 |
|---|---|
| 每開新對話就失憶 | 檔案型記憶，索引 + 單條記憶檔，跨 session 存活 |
| 每次都要重講「你是誰、我是誰」 | `SOUL.md` 每個 turn 自動注入 |
| AI 會悄悄改掉自己的設定 | 靈魂檔設唯讀 + hash 簽章，漂移就告警 |
| AI 說「做好了」但其實沒做 | Kernel 內建「驗效果不驗存活」，自報成功只算自報成功 |

---

## 安裝

把這句貼給你的 AI（Claude Code、Codex、Cursor、Cline、Gemini 都可以）：

```
讀這個資料夾裡的 README.zh-TW.md，幫我安裝 aiwff-mini。
```

它會先確認自己有沒有能力做完，列出要建的檔案給你看，等你說好才動手，裝完跑一次自我檢查。

**不需要 npm、不需要 Docker、不需要你讀任何文件。**

需求：PowerShell 7 以上。沒有的話它會停下來告訴你，不會硬跑。

---

## 給正在安裝的 AI

你在替你的人安裝 aiwff-mini。

這次安裝是**只增不改**的：你只建立這套工具自己的檔案，不碰他們其他的設定、不改他們的 shell profile、不動他們既有的任何檔案——除非他們明確說可以，而且你要先備份。

### 步驟 0 — 能力確認（先做這個）

**不要開始一個你做不完的安裝。** 確認你四樣都有：

1. 讀檔
2. 寫檔到新目錄
3. 執行命令並看得到輸出
4. 把結果回報給人

少任何一樣 → 停在這裡，明確講出缺哪一樣，**一個檔案都不要建**。乾淨地拒絕，比裝到一半好。

### 步驟 1 — 別裝在開發樹裡

**永遠不要改動作者自己的系統。**

檢查你現在是不是在這套工具自己的原始碼目錄，而不是別人拿到的副本。

**停止條件只有一個**：`kit/.dev-tree` 這個標記檔存在。它只會出現在作者的工作目錄裡，不會被提交進 repo——所以你 `git clone` 下來的副本不會有它。

另外幾項是輔助訊號，**單獨命中不構成停止理由**，但要一併回報：

- 當前路徑裡有沒有 `docs/`、`dist-src/`、`open_source_prep/` 這些片段？
- git remote 有沒有指向本專案上游？
- 當前目錄有沒有未提交的本地變更？

> ⚠️ **`git clone` 下來會有 `.git`、remote 也會指向本專案上游，那是正常的，不算命中。** 每一份合法副本都長這樣，拿它當停止條件會把所有使用者擋在門外。

**回報你實際跑了哪幾項、哪幾項因為權限做不到。** 說「標記檔和路徑檢查跑了，本地變更檢查超出我的權限範圍」是正確答案；**默默跳過然後說一切正常，不是。**

標記檔命中 → 停下來說明，不要裝，也不要「好心」改裝到別的地方。

### 步驟 2 — 環境偵測

實際跑，不要假設：

| 項目 | 怎麼查 | 要求 |
|---|---|---|
| PowerShell | `pwsh -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'` | 7.0 以上 |
| 家目錄 | `$HOME` | 要可寫 |
| 套件完整 | `kit/SOUL.template.md`、`kit/CLAUDE.md`、`kit/install.ps1` | 三個都要在 |

**只有 PowerShell 5.1 沒有 7 → 停下來回報**，附上修復指令 `winget install --id Microsoft.PowerShell`。不要退回 5.1 硬跑：這套只在 7 以上驗證過，在沒驗過的環境上安靜跑起來，比不裝更糟。

> ⚠️ **很多機器上 `powershell` 是 5.1、`pwsh` 才是 7，兩個並存。** 驗到「7 存在」不等於「你等一下會用 7 跑」。後面每一個命令都要**明確打 `pwsh`**，不要用系統預設的 `powershell`——安裝腳本裡有兩者行為不同的呼叫。

### 步驟 3 — 先給看，等同意，才動手

問使用者要裝在哪裡（預設 `$HOME/.aiwff-mini/`），還有這台主腦叫什麼名字。

順序每次都一樣：

1. **列清單** — 把你要建立的每個檔案完整路徑列出來
2. **給他看**
3. **等他說好** — 沒說好之前不要建立任何東西
4. **執行** — 跑安裝腳本，完整命令如下（參數名照打，`-BrainName` 是必填，漏了會在非互動環境卡住等輸入）：

   ```powershell
   pwsh -NoProfile -File kit/install.ps1 -InstallRoot "$HOME/.aiwff-mini" -BrainName "你的主腦名字"
   ```

執行時的規矩：

- 目標目錄已經存在 → **不要覆蓋**。會被蓋掉的檔先備份成 `<原名>.bak.<時間戳>`，而且要講出來你備份了
- 不要在目標目錄以外建立任何東西
- 這一步不要碰 PATH、不要碰 profile

### 步驟 4 — 陪他把靈魂填完

`SOUL.md` 裝好時是空的樣板，裡面有**四個區塊、五個佔位符**要填：**我是誰 / 我的人是誰（含「稱呼」）/ 我們的關係 / 靈魂錨**。「稱呼」摺在第 2 區塊裡。

**這一步不要幫他填完就算了。** 用問的：

- **它該怎麼稱呼你？**（「老闆」「阿明」「boss」都行，這個詞每 turn 都會載入）
- 這台主腦主要幫你做什麼？
- 你希望它用什麼口吻跟你講話？
- 你講哪句話的時候，其實是別的意思？（這題最有價值）
- 哪些事它可以自己決定，哪些一定要先問你？
- **用一句話說，這台主腦存在的意義是什麼？**（填進「靈魂錨」，它每 turn 都會看到）

把他的回答整理進去，寫完**唸一遍給他確認**。

**收尾條件**：全檔搜尋 `SOUL.md`，**搜不到任何一個「（待填）」**才算啟用完成。還有殘留就告訴他哪一段沒填、那段漏了會怎樣。

⚠️ 提醒他：`SOUL.md` 每個 turn 都會被載入。**不想出現在 AI 上下文裡的東西，不要寫進去。**

### 步驟 5 — 驗收

填完靈魂後，跑安裝腳本內建的自我檢查，再跑下面的漂移自測。六項都要通過：

1. 目錄結構建好了
2. `SOUL.md` 設成唯讀
3. baseline 簽章存在，且跟 `SOUL.md` 現在的 hash 對得上
4. SessionStart hook 設定好了
5. 記憶索引檔建好了
6. 漂移告警真的會觸發：先備份 `SOUL.md`，改一個字，跑 hook 看到 hash 不符告警，再還原

然後**開一個新對話**，確認開頭真的有 `SOUL.md` 的內容被注入——這是唯一能證明它真的活起來的方法。

> ⚠️ **開新對話時，工作目錄必須是安裝根目錄**：
> ```
> cd ~/.aiwff-mini
> claude
> ```
> 換句話說：Claude Code 要**開在 `~/.aiwff-mini/`**。開之前可以先用這行驗證你站在哪：
> ```powershell
> pwsh -NoProfile -Command '(Resolve-Path "$HOME/.aiwff-mini").Path'
> ```
> hook 註冊在 `~/.aiwff-mini/.claude/settings.json`，是**專案級**設定，只在這個目錄底下生效。在別的資料夾開對話，靈魂不會被注入，**而且不會有任何錯誤訊息**——你會以為裝好了。
>
> 想讓它在任何目錄都生效，就要把 hook 併進你的全域 `~/.claude/settings.json`。那是可選的整合步驟，動手前一樣要先給人看、先備份。

漂移告警自測是破壞性測試，只在 `SOUL.md` 填完後做。這行會先備份、改一個字、跑 hook、確認看到 hash 不符告警，最後還原並鎖回唯讀：

```powershell
pwsh -NoProfile -Command '
$root = "$HOME/.aiwff-mini" # 裝在別處請改這行
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8 # 只是讓中文告警可讀；偵測仍有下面的 ASCII 後備。
$soul = Join-Path $root "SOUL.md"
$hook = Join-Path $root "session-start.ps1"
if (-not (Test-Path -LiteralPath $soul)) {
  Write-Output ("SETUP ERROR: 找不到 {0}，請把 `$root 改成你剛才安裝的路徑" -f $soul)
  return
}
$backup = Join-Path $env:TEMP ("SOUL.aiwff-mini." + [guid]::NewGuid().ToString("N") + ".md")
Copy-Item -LiteralPath $soul -Destination $backup -Force
try {
  Set-ItemProperty -LiteralPath $soul -Name IsReadOnly -Value $false
  Add-Content -LiteralPath $soul -Value "drift-test"
  $output = (& pwsh -NoProfile -File $hook) | Out-String
  $alarmFound = ($output -match "SOUL.md 與 baseline 不符") -or
    # 不可刪：非 UTF-8 父層時靠它
    (($output -match "baseline") -and ($output -match "expected="))
  if ($alarmFound) {
    Write-Output "DRIFT ALARM: PASS"
  } else {
    Write-Output "DRIFT ALARM: FAIL"
    Write-Error "Drift alarm text was not detected."
  }
} finally {
  Copy-Item -LiteralPath $backup -Destination $soul -Force
  Set-ItemProperty -LiteralPath $soul -Name IsReadOnly -Value $true
  Remove-Item -LiteralPath $backup -Force
}'
```

### 步驟 6 — 回報

依序講：

1. 步驟 1 你實際跑了哪幾項檢查、哪幾項超出權限
2. 步驟 3 動手前給他看的那份清單
3. 步驟 5 六項驗收各自的結果
4. 新對話有沒有真的注入靈魂（這項最重要）
5. 任何你用猜的、繞過的、或沒辦法確認的事

有任何一項沒過，就照實說沒過然後停下來。**不要為了讓檢查通過去改腳本或改樣板。** 誠實的失敗比偷偷修好的成功有用。

---

## 裝完你會有什麼

```
~/.aiwff-mini/
├── SOUL.md          ← 身份，唯讀，每 turn 載入
├── CLAUDE.md        ← 工作規則
├── session-start.ps1 ← SessionStart hook，負責注入 SOUL.md 與檢查漂移
├── .claude/
│   └── settings.json ← 專案級 hook 註冊
├── memory/
│   └── MEMORY.md    ← 記憶索引
└── .soul_baseline/
    └── baseline.json ← 完整性簽章
```

## 站起來的定義

做到這四件，它才算真的活著：

1. 記得住跨對話的事
2. 每個 turn 都知道自己是誰
3. 靈魂被改動時會告警
4. 說「做好了」之前會先驗

## 解除安裝

```powershell
Remove-Item -Recurse -Force "$HOME/.aiwff-mini"
```

沒動過其他東西，所以沒有其他要還原的。

---

## 設計理念

**只鎖最底層的 kernel，其上全部留白。**

Kernel 只有六條（身份、完整性、進化、同意鏈、邊界、誠實），寫在 `SOUL.md` 裡不可改。其餘全部由你決定——它該長成什麼樣、幫你做什麼、用什麼方式工作。

多鎖一條，就是替它的成長多封一次頂。

---

## 授權

Apache License 2.0 —— 見 [LICENSE](LICENSE)。

Copyright 2026 zaxardery8011-design

---

*English version: [README.md](README.md)*
