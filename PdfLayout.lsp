;;;=============================================================
;;; MAP文件工具箱 PdfLayout.lsp  v2.16
;;;-------------------------------------------------------------
;;; 功能：识别模型空间已有图纸(PDFATTACH参考底图导入并摆放) →
;;;       复制模板布局(含图框) → 按可配置规则自动命名 →
;;;       每个布局视口自动对准模型空间对应图纸并锁定
;;; 命令：PDFLAYOUT    - 对话框版（需 PdfLayout.dcl）
;;; 适用：AutoCAD 2018+
;;;=============================================================
(vl-load-com)

;;;-------------------------------------------------------------
;;; 记录LSP文件所在路径（用于定位DCL）
;;;-------------------------------------------------------------
(defun PdfLayout_GetLspDir (/ lspDir)
  ;; 中望CAD的 *load-truename* 为 nil，无法获取 LSP 自身目录；
  ;; 不要退回 DWGPREFIX（会跟随当前图纸目录变化），取不到就返回 nil，
  ;; 由 SettingsPathLsp 改用固定的临时目录，保证记忆设置不随图纸丢失
  (setq lspDir nil)
  (if (and *load-truename* (/= *load-truename* ""))
    (setq lspDir (vl-filename-directory *load-truename*))
  )
  lspDir
)

(setq *PdfLayout_LspDir* (PdfLayout_GetLspDir))
(if *PdfLayout_LspDir*
  (princ (strcat "\n[调试] LSP目录: " *PdfLayout_LspDir*))
  (princ "\n[调试] LSP目录: (空)")
)
(princ (strcat "\n[调试] 临时目录: " (getvar "TEMPPREFIX")))

;;;-------------------------------------------------------------
;;; 全局状态与错误处理
;;;-------------------------------------------------------------
(setq *PdfLayout_ViewInset* 0.95)   ; 视口内边缩进系数，避免图纸贴边
(setq *PdfLayout_Running* nil)
(setq *PdfLayout_UndoOn* nil)
(setq *PdfLayout_CreatedLayouts* nil)
(setq *PdfLayout_OldError* *error*)
(setq *PdfLayout_Debug* nil)
(setq *PdfLayout_DclWritten* nil)
(setq *PdfLayout_PreviewPairs* nil)
(setq *PdfLayout_PreviewNames* nil)
(setq *PdfLayout_PreviewLbds* nil)
(setq *PdfLayout_LbdRows* nil)
(setq *PdfLayout_PreviewPrefix* "STR")
(setq *PdfLayout_PreviewStart* 1)
(setq *PdfLayout_PreviewDigits* 2)
(setq *PdfLayout_PreviewOrder* "1")
(setq *PdfLayout_PreviewSrc* "1")
(setq *PdfLayout_PreviewFilePath* "")
(setq *PdfLayout_PreviewResult* 0)
(setq *PdfLayout_PreviewBgMode* "0")
(setq *PdfLayout_PreviewBgColor* 7)
(setq *PdfLayout_PreviewBgScale* 1.5)
(setq *PdfLayout_RowTol* 10)
(setq *PdfLayout_Profiles* nil)
(setq *PdfLayout_CurrentProfile* "")
(setq *PdfLayout_IniPairs* nil)
(setq *PdfLayout_LastPdfFile* "")
(setq *PdfLayout_LastNamesXlsx* "")
(setq *PdfLayout_NamesXlsxList* nil)
(setq *PdfLayout_LayRule* "")
(setq *PdfLayout_LayLetters* "")
(setq *PdfLayout_LayPerGroup* 6)
(setq *PdfLayout_LayGStart* 1)
(setq *PdfLayout_ArrangeOnly* nil)
(setq *PdfLayout_ArrangeOnlyName* nil)
(setq *PdfLayout_SavedFd* nil)
(setq *PdfLayout_DclLines* (list
"// PdfLayout.dcl"
"// MAP文件工具箱 v2.16 - 对话框定义"
""
"PdfLayout : dialog {"
"  label = \"MAP文件工具箱 v2.16\";"
"  width = 62;"
""
"  : boxed_column {"
"    label = \"图纸识别（竖线标记模式）\";"
"    : row {"
"      : popup_list {"
"        label = \"竖线块名:\";"
"        key = \"marker_name\";"
"        edit_width = 22;"
"      }"
"    }"
"    : button {"
"      label = \"仅自动排序已导入的PDF(不建布局)\";"
"      key = \"btn_arrange\";"
"      width = 32;"
"    }"
"    : text {"
"      key = \"found_info\";"
"      label = \" \";"
"      width = 55;"
"    }"
"    : text {"
"      label = \"提示: 先用 PDFATTACH 导入PDF，再运行本命令自动排列底图并创建布局；竖线标记块默认名pdf\";"
"      width = 55;"
"    }"
"  }"
))

(setq *PdfLayout_DclLines* (append *PdfLayout_DclLines* (list
""
"  : boxed_column {"
"    label = \"布局\";"
"    : popup_list {"
"      label = \"模板布局(含图框):\";"
"      key = \"tmpl_layout\";"
"      edit_width = 26;"
"    }"
"    : row {"
"      : edit_box { label = \"布局名来自Excel分表:\"; key = \"names_xlsx\"; edit_width = 16; }"
"      : button { label = \"选择...\"; key = \"btn_names_xlsx\"; width = 10; }"
"    }"
"    : text { label = \"填Excel后按分表顺序命名布局(数量=分表数)；留空用下方规则\"; width = 55; }"
"    : row {"
"      : edit_box {"
"        label = \"复制数量:\";"
"        key = \"count\";"
"        edit_width = 6;"
"        value = \"0\";"
"        allow_accept = true;"
"      }"
"      : toggle {"
"        label = \"覆盖同名布局\";"
"        key = \"overwrite\";"
"        value = \"0\";"
)))

(setq *PdfLayout_DclLines* (append *PdfLayout_DclLines* (list
"      }"
"    }"
"  }"
""
"  : boxed_column {"
"    label = \"命名规则\";"
"    : edit_box {"
"      label = \"规则:\";"
"      key = \"rule\";"
"      edit_width = 34;"
"      value = \"INV{G2}{L}{N2}\";"
"      allow_accept = true;"
"    }"
"    : row {"
"      : edit_box {"
"        label = \"字母列表:\";"
"        key = \"letters\";"
"        edit_width = 10;"
"        value = \"AB\";"
"        allow_accept = true;"
)))

(setq *PdfLayout_DclLines* (append *PdfLayout_DclLines* (list
"      }"
"      : edit_box {"
"        label = \"每组张数:\";"
"        key = \"per_group\";"
"        edit_width = 5;"
"        value = \"6\";"
"        allow_accept = true;"
"      }"
"      : edit_box {"
"        label = \"编号起始:\";"
"        key = \"g_start\";"
"        edit_width = 5;"
"        value = \"1\";"
"        allow_accept = true;"
"      }"
"    }"
"    : text {"
"      label = \"占位符: {G2}=编号(2位)  {L}=字母循环  {N2}=组内序号(2位)\";"
"      width = 58;"
"    }"
)))

(setq *PdfLayout_DclLines* (append *PdfLayout_DclLines* (list
"    : text {"
"      label = \"例: INV{G2}{L}{N2} + 字母AB + 每组6张 -> INV01A01..A06, INV01B01..B06, INV02A01..\";"
"      width = 58;"
"    }"
"    : list_box {"
"      label = \"名称预览:\";"
"      key = \"preview\";"
"      height = 9;"
"    }"
"  }"
""
"  : boxed_column {"
"    label = \"视口\";"
"    : edit_box {"
"      label = \"模板无视口时按边距创建(mm):\";"
"      key = \"margin\";"
"      edit_width = 6;"
"      value = \"5\";"
"      allow_accept = true;"
"    }"
)))

(setq *PdfLayout_DclLines* (append *PdfLayout_DclLines* (list
"    : toggle {"
"      label = \"锁定视口显示(防误缩放)\";"
"      key = \"lock_vp\";"
"      value = \"0\";"
"    }"
"  }"
""
"  ok_cancel;"
"}"
""
"PdfRenamePreview : dialog {"
"  label = \"多行文字命名方案\";"
"  : boxed_column {"
"    label = \"方案预设\";"
"    : row {"
"      : popup_list { label = \"方案:\"; key = \"prof_list\"; edit_width = 18; }"
"    }"
"    : row {"
"      : edit_box { label = \"方案名:\"; key = \"prof_name\"; edit_width = 12; }"
"      : button { label = \"保存为方案\"; key = \"btn_saveprof\"; width = 14; }"
"      : button { label = \"删除方案\"; key = \"btn_delprof\"; width = 14; }"
)))

(setq *PdfLayout_DclLines* (append *PdfLayout_DclLines* (list
"    }"
"  }"
  "  : boxed_radio_column {"
  "    label = \"名称来源\";"
  "    : radio_button { label = \"自动生成（前缀+编号）\"; key = \"srcauto\"; value = \"1\"; }"
  "    : radio_button { label = \"从CSV导入(LBD标签两列)\"; key = \"srcfile2\"; }"
"  }"
"  : row {"
"    : edit_box { label = \"文件:\"; key = \"file_path\"; edit_width = 22; }"
"    : button { label = \"选择...\"; key = \"btn_file\"; width = 10; }"
"  }"
"  : row {"
"    : edit_box { label = \"前缀:\"; key = \"prefix\"; edit_width = 8; }"
"    : edit_box { label = \"起始编号:\"; key = \"start\"; edit_width = 5; }"
"    : edit_box { label = \"位数(0=不补零):\"; key = \"digits\"; edit_width = 4; }"
"  }"
"  : boxed_column {"
"    label = \"文字背景\";"
"    : radio_row {"
"      : radio_button { label = \"保持现状\"; key = \"bgkeep\"; value = \"1\"; }"
)))

(setq *PdfLayout_DclLines* (append *PdfLayout_DclLines* (list
"      : radio_button { label = \"开启填充\"; key = \"bgon\"; }"
"      : radio_button { label = \"关闭填充\"; key = \"bgoff\"; }"
"    }"
"    : row {"
"      : edit_box { label = \"颜色(ACI):\"; key = \"bg_color\"; edit_width = 4; }"
"      : edit_box { label = \"缩放系数:\"; key = \"bg_scale\"; edit_width = 4; }"
"    }"
"  }"
"  : boxed_radio_column {"
"    label = \"排序方式\";"
"    : radio_button { label = \"1 列优先: 左→右列、列内上→下\"; key = \"ord1\"; value = \"1\"; }"
"    : radio_button { label = \"2 行优先: 上→下行、行内左→右\"; key = \"ord2\"; }"
"    : radio_button { label = \"3 右->左/上->下\"; key = \"ord3\"; }"
"    : radio_button { label = \"4 下->上/左->右\"; key = \"ord4\"; }"
"    : radio_button { label = \"5 左->右/下->上\"; key = \"ord5\"; }"
"    : radio_button { label = \"6 右->左/下->上\"; key = \"ord6\"; }"
"    : radio_button { label = \"7 上->下/右->左\"; key = \"ord7\"; }"
"    : radio_button { label = \"8 下->上/右->左\"; key = \"ord8\"; }"
"  }"
"  : row {"
"    : edit_box { label = \"分行容差%(越大越并成一行):\"; key = \"row_tol\"; edit_width = 5; value = \"10\"; }"
"  }"
"  : boxed_column {"
)))

(setq *PdfLayout_DclLines* (append *PdfLayout_DclLines* (list
"    label = \"方案预览（左=顺序 右=名称）\";"
"    : row {"
"      : list_box { key = \"scheme_grid\"; height = 8; width = 26; }"
"      : list_box { key = \"name_list\"; height = 8; width = 22; }"
"    }"
"  }"
"  : text { key = \"info_text\"; label = \" \"; width = 60; }"
"  ok_cancel;"
"}"
)))

(defun PdfLayout_ErrorHandler (msg)
  (if *PdfLayout_UndoOn*
    (vl-catch-all-apply
      '(lambda () (command "._UNDO" "_E"))
    )
  )
  (if *PdfLayout_Running*
    (progn
      (foreach n *PdfLayout_CreatedLayouts*
        (if (PdfLayout_LayoutExists n)
          (PdfLayout_DeleteLayout n)
        )
      )
      (princ (strcat "\nPDF布局工具出错，已删除已创建的 "
                     (itoa (length *PdfLayout_CreatedLayouts*))
                     " 个布局: " msg))
      (setq *PdfLayout_Running* nil)
      (setq *PdfLayout_CreatedLayouts* nil)
    )
    (princ (strcat "\nPDF布局工具错误: " msg))
  )
  ;; 出错时恢复文件对话框开关，避免 FILEDIA 停留在 0 导致不再弹窗
  (if *PdfLayout_SavedFd*
    (progn
      (setvar "FILEDIA" *PdfLayout_SavedFd*)
      (setq *PdfLayout_SavedFd* nil)
    )
  )
  (setvar "CMDECHO" 1)
  (setvar "EXPERT" 0)
  (princ)
)

(setq *error* PdfLayout_ErrorHandler)

;;;-------------------------------------------------------------
;;; 全局参数
;;;-------------------------------------------------------------
(defun PdfLayout_GetDefaults ()
  (list
    (cons "Mode"           "marker")
    (cons "Filter"         "")
    (cons "TemplateLayout" "")
    (cons "Count"          0)
    (cons "Rule"           "INV{G2}{L}{N2}")
    (cons "Letters"        "AB")
    (cons "PerGroup"       6)
    (cons "GroupStart"     1)
    (cons "Margin"         5)
    (cons "Overwrite"      0)
  )
)

(defun PdfLayout_GetParam (params key)
  (cdr (assoc key params))
)

;;;-------------------------------------------------------------
;;; 通用小工具
;;;-------------------------------------------------------------
(defun PdfLayout_PadZero (num digits / s len)
  (setq s (itoa num))
  (setq len (strlen s))
  (if (< len digits)
    (repeat (- digits len)
      (setq s (strcat "0" s))
    )
  )
  s
)

(defun PdfLayout_GetExtentsSafeObj (obj / bb pmin pmax)
  (setq bb (vl-catch-all-apply 'vla-GetBoundingBox (list obj 'pmin 'pmax)))
  (if (vl-catch-all-error-p bb)
    nil
    (list (vlax-safearray->list pmin) (vlax-safearray->list pmax))
  )
)

(defun PdfLayout_BBoxCenter (bbox / minPt maxPt)
  (setq minPt (car bbox) maxPt (cadr bbox))
  (list (/ (+ (car minPt) (car maxPt)) 2.0)
        (/ (+ (cadr minPt) (cadr maxPt)) 2.0))
)

(defun PdfLayout_HasDuplicate (lst / seen x dup)
  (setq seen nil dup nil)
  (foreach x lst
    (if (member x seen)
      (setq dup T)
      (setq seen (cons x seen))
    )
  )
  dup
)

(defun PdfLayout_ValidLayoutName (name / bad ok c)
  (setq bad (list ">" "<" "/" "\\" "\"" ":" ";" "?" "*" "|" "=" "," "`"))
  (setq ok T)
  (foreach c bad
    (if (vl-string-search c name)
      (setq ok nil)
    )
  )
  ok
)

;;;-------------------------------------------------------------
;;; 命名规则引擎
;;; 占位符：
;;;   {G} 或 {G2}   编号段：编号循环完成后自动+1，位数缺省2
;;;   {L}           字母段：循环使用字母列表（如 AB 或 A-Z）
;;;   {N} 或 {N2}   序号段：每组从1开始，数到"每组张数"后换下一字母/编号
;;; 示例：INV{G2}{L}{N2} + 字母AB + 每组6张
;;;       → INV01A01..A06, INV01B01..B06, INV02A01..
;;;-------------------------------------------------------------
(defun PdfLayout_ParseRule (rule / i j token seg segs)
  (setq segs nil i 0)
  (while (< i (strlen rule))
    (if (= (substr rule (1+ i) 1) "{")
      (progn
        (setq j (vl-string-search "}" rule i))
        (if j
          (progn
            (setq token (strcase (substr rule (+ i 2) (- j i 1))))
            (cond
              ((= token "L")         (setq seg (cons "L" nil)))
              ((= token "G")         (setq seg (cons "G" nil)))
              ((= token "N")         (setq seg (cons "N" nil)))
              ((wcmatch token "G#*") (setq seg (cons "G" (atoi (substr token 2)))))
              ((wcmatch token "N#*") (setq seg (cons "N" (atoi (substr token 2)))))
              (t                     (setq seg (cons "T" (strcat "{" token "}"))))
            )
            (setq segs (append segs (list seg)))
            (setq i (1+ j))
          )
          (progn
            (setq segs (append segs (list (cons "T" "{"))))
            (setq i (1+ i))
          )
        )
      )
      (progn
        (setq j (vl-string-search "{" rule i))
        (if (not j) (setq j (strlen rule)))
        (setq segs (append segs (list (cons "T" (substr rule (1+ i) (- j i))))))
        (setq i j)
      )
    )
  )
  segs
)

(defun PdfLayout_ParseLetters (str / len c1 c2 code out i c)
  (setq str (strcase str))
  (setq len (strlen str))
  (setq out nil)
  (if (and (= len 3) (= (substr str 2 1) "-"))
    (progn
      (setq c1 (substr str 1 1) c2 (substr str 3 1))
      (if (and (>= c1 "A") (<= c1 "Z") (>= c2 "A") (<= c2 "Z") (<= c1 c2))
        (progn
          (setq code (ascii c1))
          (while (<= code (ascii c2))
            (setq out (append out (list (chr code))))
            (setq code (1+ code))
          )
        )
      )
    )
  )
  (if (not out)
    (progn
      (setq i 1)
      (while (<= i len)
        (setq c (substr str i 1))
        (if (and (>= c "A") (<= c "Z"))
          (setq out (append out (list c)))
        )
        (setq i (1+ i))
      )
    )
  )
  out
)

(defun PdfLayout_BuildNamePlan (rule lettersStr pg gStart
                                / segs letters hasN hasL hasG lenL nWidth gWidth
                                  rev s typ val pace plan vals)
  (setq segs (PdfLayout_ParseRule rule))
  (setq letters (PdfLayout_ParseLetters lettersStr))
  (setq hasN (assoc "N" segs))
  (setq hasL (assoc "L" segs))
  (setq hasG (assoc "G" segs))
  (setq lenL (if hasL (length letters) 1))
  (setq nWidth (if (and hasN (cdr hasN)) (cdr hasN) 2))
  (setq gWidth (if (and hasG (cdr hasG)) (cdr hasG) 2))
  (setq plan nil)
  (setq pace 1)
  (setq rev (reverse segs))
  (foreach s rev
    (setq typ (car s))
    (cond
      ((= typ "T")
        (setq plan (cons s plan))
      )
      ((= typ "N")
        (setq vals (if (and (not hasL) (not hasG)) nil pg))
        (setq plan (cons (cons "N"
                               (list (cons "width" nWidth)
                                     (cons "start" 1)
                                     (cons "vals" vals)
                                     (cons "pace" pace)))
                         plan))
        (if vals (setq pace (* pace vals)))
      )
      ((= typ "L")
        (setq plan (cons (cons "L"
                               (list (cons "letters" letters)
                                     (cons "pace" pace)))
                         plan))
        (setq pace (* pace lenL))
      )
      ((= typ "G")
        (setq plan (cons (cons "G"
                               (list (cons "width" gWidth)
                                     (cons "start" gStart)
                                     (cons "pace" pace)))
                         plan))
      )
    )
  )
  plan
)

(defun PdfLayout_NameAt (plan i / out s typ p letters vals idx)
  (setq out "")
  (foreach s plan
    (setq typ (car s))
    (cond
      ((= typ "T")
        (setq out (strcat out (cdr s)))
      )
      ((= typ "G")
        (setq p (cdr s))
        (setq out (strcat out
                          (PdfLayout_PadZero
                            (+ (cdr (assoc "start" p))
                               (fix (/ i (cdr (assoc "pace" p)))))
                            (cdr (assoc "width" p)))))
      )
      ((= typ "L")
        (setq p (cdr s))
        (setq letters (cdr (assoc "letters" p)))
        (setq out (strcat out
                          (nth (rem (fix (/ i (cdr (assoc "pace" p))))
                                    (length letters))
                               letters)))
      )
      ((= typ "N")
        (setq p (cdr s))
        (setq vals (cdr (assoc "vals" p)))
        (setq idx (if vals
                    (rem (fix (/ i (cdr (assoc "pace" p)))) vals)
                    (fix (/ i (cdr (assoc "pace" p))))))
        (setq out (strcat out
                          (PdfLayout_PadZero
                            (+ (cdr (assoc "start" p)) idx)
                            (cdr (assoc "width" p)))))
      )
    )
  )
  out
)

(defun PdfLayout_MaxDistinct (plan / gEnt lEnt nEnt lInfo nInfo)
  (setq gEnt (assoc "G" plan))
  (setq lEnt (assoc "L" plan))
  (setq nEnt (assoc "N" plan))
  (cond
    (gEnt 0)
    ((and nEnt (not lEnt)) 0)
    (lEnt
      (setq lInfo (cdr lEnt))
      (setq nInfo (if nEnt (cdr nEnt) nil))
      (* (length (cdr (assoc "letters" lInfo)))
         (if nInfo (cdr (assoc "vals" nInfo)) 1))
    )
    (t 1)
  )
)

(defun PdfLayout_GenNames (rule lettersStr pg gStart count
                           / segs letters hasL plan names i maxD)
  (setq segs (PdfLayout_ParseRule rule))
  (setq letters (PdfLayout_ParseLetters lettersStr))
  (setq hasL (assoc "L" segs))
  (if (and hasL (not letters))
    nil
    (progn
      (setq plan (PdfLayout_BuildNamePlan rule lettersStr pg gStart))
      (setq maxD (PdfLayout_MaxDistinct plan))
      (if (and (/= maxD 0) (< maxD count))
        nil
        (progn
          (setq names nil i 0)
          (while (< i count)
            (setq names (append names (list (PdfLayout_NameAt plan i))))
            (setq i (1+ i))
          )
          names
        )
      )
    )
  )
)

(defun PdfLayout_ValidateRule (rule lettersStr
                               / segs letters hasL hasN hasG msg)
  (setq segs (PdfLayout_ParseRule rule))
  (setq letters (PdfLayout_ParseLetters lettersStr))
  (setq hasL (assoc "L" segs))
  (setq hasN (assoc "N" segs))
  (setq hasG (assoc "G" segs))
  (setq msg nil)
  (if (not (or hasL hasN hasG))
    (setq msg "命名规则中至少需要一个占位符 {G} / {L} / {N}，例如 INV{G2}{L}{N2}")
  )
  (if (and hasL (not letters))
    (setq msg (strcat "命名规则使用了 {L}，但字母列表无效: "
                      lettersStr
                      "（示例: AB 或 A-Z）"))
  )
  msg
)

;;;-------------------------------------------------------------
;;; 图纸识别（模型空间）
;;;-------------------------------------------------------------
(defun PdfLayout_ScanMarkers (markerName / doc ms obj name bbox lst)
  (setq doc (vla-get-ActiveDocument (vlax-get-Acad-Object)))
  (setq ms (vla-get-ModelSpace doc))
  (setq markerName (strcase (if markerName markerName "pdf")))
  (setq lst nil)
  (vlax-for obj ms
    (if (= (vla-get-ObjectName obj) "AcDbBlockReference")
      (progn
        (setq name (strcase (vla-get-Name obj)))
        (if (= name markerName)
          (progn
            (setq bbox (PdfLayout_GetExtentsSafeObj obj))
            (if bbox
              (setq lst (append lst (list (cons obj bbox))))
            )
          )
        )
      )
    )
  )
  ;; 排序：同一行先从左往右，行与行从上往下；
  ;; 按底端 y 分行并自动估算容差，竖线长短不一、摆放不整齐也能正确分行
  (PdfLayout_SortMarkersRowMajor lst)
)

(defun PdfLayout_IsUnderlay (objName / up)
  (setq up (strcase objName))
  (or (= up "ACDBPDFREFERENCE")
      (= up "ACDBUNDERLAYREFERENCE")
      (= up "ACDBDWFREFERENCE")
      (vl-string-search "PDF" up)
      (vl-string-search "UNDERLAY" up))
)

(defun PdfLayout_CountUnderlays (/ doc ms n obj)
  ;; 统计模型空间里现有的 PDF/底图对象数量，用于判断导入是否成功
  (setq doc (vla-get-ActiveDocument (vlax-get-Acad-Object)))
  (setq ms (vla-get-ModelSpace doc))
  (setq n 0)
  (vlax-for obj ms
    (if (PdfLayout_IsUnderlay (vla-get-ObjectName obj))
      (setq n (1+ n))
    )
  )
  n
)

(defun PdfLayout_ListObjectNames (/ doc ms out obj)
  ;; 诊断用：列出模型空间所有对象的 ObjectName
  (setq doc (vla-get-ActiveDocument (vlax-get-Acad-Object)))
  (setq ms (vla-get-ModelSpace doc))
  (setq out "")
  (vlax-for obj ms
    (setq out (strcat out (if (= out "") "" ", ") (vla-get-ObjectName obj)))
  )
  out
)

(defun PdfLayout_EntityNameList (/ doc ms out obj)
  ;; 收集模型空间所有实体的 ename，用于对比导入前后的新增对象
  (setq doc (vla-get-ActiveDocument (vlax-get-Acad-Object)))
  (setq ms (vla-get-ModelSpace doc))
  (setq out nil)
  (vlax-for obj ms
    (setq out (cons (vlax-vla-object->ename obj) out))
  )
  out
)

(defun PdfLayout_ImportPdfFile (path / oldNames newNames newObjs oldFd ok before after)
  ;; 仅用 PDFATTACH 自动导入：整份 PDF 由 ZWCAD 按页生成参考底图对象，
  ;; 通过导入前后实体列表对比找出新增对象并返回；
  ;; 若导入页数与 PDF 页数不符，可在弹窗中勾选“弹窗选页”手动选择页面
  (setq oldNames (PdfLayout_EntityNameList))
  (if *PdfLayout_Debug*
    (progn
      (princ (strcat "\n[调试] 导入前实体数=" (itoa (length oldNames)) "  PDF=" path))
      (princ (strcat "\n[调试] 模型空间对象: " (PdfLayout_ListObjectNames)))
    )
  )
  (princ (strcat "\n正在导入 PDF: " path))
  (setq oldFd (getvar "FILEDIA"))
  (setq *PdfLayout_SavedFd* oldFd)
  (setvar "FILEDIA" 0)
  (setq ok nil)
  ;; 尝试1：路径 → 插入点(0,0) → 比例1 → 旋转0
  (setq before (length (PdfLayout_EntityNameList)))
  (vl-catch-all-apply
    '(lambda ()
      (command "._PDFATTACH" path "0,0" "1" "0")
      (command)
    )
  )
  (setq after (length (PdfLayout_EntityNameList)))
  (if (> after before) (setq ok T))
  ;; 尝试2：只给路径，让 ZWCAD 用默认值（诊断确认不会挂起）
  (if (not ok)
    (progn
      (setq before (length (PdfLayout_EntityNameList)))
      (vl-catch-all-apply
        '(lambda ()
          (command "._PDFATTACH" path)
          (command)
        )
      )
      (setq after (length (PdfLayout_EntityNameList)))
      (if (> after before) (setq ok T))
    )
  )
  (setq *PdfLayout_SavedFd* nil)
  (setvar "FILEDIA" oldFd)
  (setq newNames (PdfLayout_EntityNameList))
  (setq newObjs nil)
  (foreach e newNames
    (if (not (member e oldNames))
      (setq newObjs (cons (vlax-ename->vla-object e) newObjs))
    )
  )
  (setq newObjs (reverse newObjs))
  (if *PdfLayout_Debug*
    (progn
      (princ (strcat "\n[调试] 导入后实体数=" (itoa (length newNames))
                     "  新增对象数=" (itoa (length newObjs))))
      (princ (strcat "\n[调试] 模型空间对象: " (PdfLayout_ListObjectNames)))
    )
  )
  (if newObjs
    (progn
      (princ (strcat "\nPDF 导入成功，新增 " (itoa (length newObjs))
                     " 个底图（若少于 PDF 页数，可勾选“弹窗选页”重新导入）"))
      newObjs
    )
    (progn
      (alert "PDF 自动导入未完成：PDFATTACH 未能导入任何页面。\n请勾选“弹窗选页”手动选择页面后重试，或先手动执行 PDFATTACH 导入。")
      nil
    )
  )
)
(defun PdfLayout_ImportPdfDialog (path / oldNames newNames newObjs oldFd)
  ;; 启动 ZWCAD 原生 PDFATTACH 选页窗口：
  ;; 命令行模式下输入 ~ 强制弹出文件选择窗口（ZWCAD 官方机制），
  ;; 之后插入点/比例/旋转已自动填好，用户只需选文件、全选页面、点确定；
  ;; 完成后自动识别新增底图并返回，适合 144 页这类多页 PDF
  (setq oldNames (PdfLayout_EntityNameList))
  (princ "\n正在启动 PDFATTACH 选页窗口…")
  (princ "\n请在窗口中选择 PDF，并在页面列表按住 Ctrl 全选需要的页面（或点第一页、Shift 点最后一页），点确定；")
  (princ "\n插入点/比例/旋转已自动填好，无需输入。完成后程序自动识别新底图并排列。")
  (setq oldFd (getvar "FILEDIA"))
  (setq *PdfLayout_SavedFd* oldFd)
  (setvar "FILEDIA" 0)
  (vl-catch-all-apply
    '(lambda ()
      (command "._PDFATTACH" "~" "0,0" "1" "0")
      (command)
    )
  )
  (setq *PdfLayout_SavedFd* nil)
  (setvar "FILEDIA" oldFd)
  (setq newNames (PdfLayout_EntityNameList))
  (setq newObjs nil)
  (foreach e newNames
    (if (not (member e oldNames))
      (setq newObjs (cons (vlax-ename->vla-object e) newObjs))
    )
  )
  (setq newObjs (reverse newObjs))
  (if *PdfLayout_Debug*
    (progn
      (princ (strcat "\n[调试] 弹窗选页后新增对象数=" (itoa (length newObjs))))
      (princ (strcat "\n[调试] 模型空间对象: " (PdfLayout_ListObjectNames)))
    )
  )
  (if newObjs
    (progn
      (princ (strcat "\nPDF 导入成功，新增 " (itoa (length newObjs)) " 个底图"))
      newObjs
    )
    (progn
      (alert "未检测到新增 PDF 底图（可能已取消选页或未选择页面）。\n请重新运行，并在 PDFATTACH 窗口中按住 Ctrl 全选需要的页面后点击确定。")
      nil
    )
  )
)
(defun PdfLayout_PickPdfFile (/ fpath)
  (setq fpath (getfiled "选择要导入的 PDF 文件" "" "pdf" 4))
  (if fpath
    (progn
      (setq *PdfLayout_LastPdfFile* fpath)
      (set_tile "pdf_path" fpath)
    )
  )
)

(defun PdfLayout_PickNamesXlsx (/ fpath det)
  (setq fpath (getfiled "选择标签Excel(分表名=布局名)" "" "xlsx;xls" 4))
  (if fpath
    (progn
      (setq *PdfLayout_LastNamesXlsx* fpath)
      (set_tile "names_xlsx" fpath)
      (setq *PdfLayout_NamesXlsxList* (PdfLayout_GetXlsxSheetNames fpath))
      (if (not *PdfLayout_NamesXlsxList*)
        (alert "无法读取Excel分表名，请确认文件存在且未被占用。")
        (progn
          ;; 自动识别分表名的命名规律并记忆为方案
          (setq det (PdfLayout_DetectRuleFromNames *PdfLayout_NamesXlsxList*))
          (if det
            (progn
              (setq *PdfLayout_LayRule* (nth 0 det))
              (setq *PdfLayout_LayLetters* (nth 1 det))
              (setq *PdfLayout_LayPerGroup* (nth 2 det))
              (setq *PdfLayout_LayGStart* (nth 3 det))
              (set_tile "rule" *PdfLayout_LayRule*)
              (set_tile "letters" *PdfLayout_LayLetters*)
              (set_tile "per_group" (itoa *PdfLayout_LayPerGroup*))
              (set_tile "g_start" (itoa *PdfLayout_LayGStart*))
              (princ (strcat "\n已识别命名规律并记忆: " *PdfLayout_LayRule*))
              (PdfLayout_SaveSettings)
            )
            (princ "\n未能识别分表名的命名规律，将直接使用分表名作为布局名。")
          )
        )
      )
      (PdfLayout_UpdatePreview)
    )
  )
)

(defun PdfLayout_MatchMarkerUnderlay (pt / doc ms obj objName bb c d area
                                      containBest containArea nearest nearestD)
  (setq doc (vla-get-ActiveDocument (vlax-get-Acad-Object)))
  (setq ms (vla-get-ModelSpace doc))
  (setq containBest nil containArea nil nearest nil nearestD nil)
  (vlax-for obj ms
    (setq objName (vla-get-ObjectName obj))
    (if (PdfLayout_IsUnderlay objName)
      (progn
        (setq bb (PdfLayout_GetExtentsSafeObj obj))
        (if bb
          (progn
            (setq c (PdfLayout_BBoxCenter bb))
            (setq d (+ (* (- (car c) (car pt)) (- (car c) (car pt)))
                       (* (- (cadr c) (cadr pt)) (- (cadr c) (cadr pt)))))
            (if (and (>= (car pt) (car (car bb)))
                     (<= (car pt) (car (cadr bb)))
                     (>= (cadr pt) (cadr (car bb)))
                     (<= (cadr pt) (cadr (cadr bb))))
              (progn
                (setq area (* (- (car (cadr bb)) (car (car bb)))
                              (- (cadr (cadr bb)) (cadr (car bb)))))
                (if (or (not containArea) (< area containArea))
                  (progn
                    (setq containBest obj containArea area)
                  )
                )
              )
            )
            (if (or (not nearestD) (< d nearestD))
              (progn (setq nearest obj nearestD d))
            )
          )
        )
      )
    )
  )
  (if containBest containBest nearest)
)

(defun PdfLayout_ScanMarkerDrawings (markerName / markers out pt u bb objName)
  (setq markers (PdfLayout_ScanMarkers markerName))
  (if *PdfLayout_Debug*
    (princ (strcat "\n[调试] 标记识别到 " (itoa (length markers)) " 个"))
  )
  (setq out nil)
  (foreach m markers
    (setq pt (PdfLayout_BBoxCenter (cdr m)))
    (setq u (PdfLayout_MatchMarkerUnderlay pt))
    (setq bb (if u (PdfLayout_GetExtentsSafeObj u) (cdr m)))
    (if *PdfLayout_Debug*
      (progn
        (princ (strcat "\n[调试] 标记中心 "
                       (rtos (car pt) 2 2) "," (rtos (cadr pt) 2 2)))
        (if (and u bb)
          (progn
            (setq objName (vla-get-ObjectName u))
            (princ (strcat " -> 底图 " objName " 范围 "
                           (rtos (car (car bb)) 2 2) ","
                           (rtos (cadr (car bb)) 2 2) " - "
                           (rtos (car (cadr bb)) 2 2) ","
                           (rtos (cadr (cadr bb)) 2 2)))
          )
          (princ (if u " -> 底图已匹配但范围读取失败" " -> 未匹配到底图"))
        )
      )
    )
    (if bb
      (setq out (append out (list bb)))
    )
  )
  out
)
(defun PdfLayout_ArrangePagesToMarkers (markers / doc ms pages obj objName bb pt i m p
                                        nDone res newBb)
  ;; 把模型空间里已导入的 PDF 底图/块先按 左→右/上→下 排序
  ;; （位置完全重叠时按实体顺序兜底，避免 vl-sort 丢项），
  ;; 再逐个移动到对应竖线标记的位置（页角对齐标记角），并包裹撤销；
  ;; 用 vla-Move 整体移动（ZWCAD 的 PDF 底图不支持直接改插入点），
  ;; 移动后校验新位置，未到位会给出警告
  (setq doc (vla-get-ActiveDocument (vlax-get-Acad-Object)))
  (setq ms (vla-get-ModelSpace doc))
  (setq pages nil i 0 nDone 0)
  (vlax-for obj ms
    (setq objName (vla-get-ObjectName obj))
    (if (PdfLayout_IsUnderlay objName)
      (progn
        (setq bb (PdfLayout_GetExtentsSafeObj obj))
        (if bb
          (setq pages (append pages (list (cons i (cons obj bb)))))
        )
      )
    )
    (setq i (1+ i))
  )
  (setq pages (PdfLayout_StableSort pages 'PdfLayout_CmpPages))
  (setq i 0)
  (foreach m markers
    (setq p (if pages (nth i pages) nil))
    (if p
      (progn
        (setq p (cdr p))
        (setq obj (car p) bb (cdr p))
        (setq pt (car (cdr m)))
        (setq res (vl-catch-all-apply
                    'vla-Move
                    (list obj
                          (vlax-3d-point (car (car bb)) (cadr (car bb)) 0.0)
                          (vlax-3d-point (car pt) (cadr pt) 0.0))))
        (setq newBb (PdfLayout_GetExtentsSafeObj obj))
        (if (and newBb (not (vl-catch-all-error-p res))
                 (< (abs (- (car (car newBb)) (car pt))) 1e-6)
                 (< (abs (- (cadr (car newBb)) (cadr pt))) 1e-6))
          (setq nDone (1+ nDone))
          (princ (strcat "\n[警告] 第 " (itoa (1+ i)) " 个底图未移动到目标标记 ("
                         (rtos (car pt) 2 2) "," (rtos (cadr pt) 2 2) ")，可能被锁定或对象类型不支持移动"))
        )
      )
    )
    (setq i (1+ i))
  )
  (princ (strcat "\n已按 左→右/上→下 排列 " (itoa nDone)
                 " 个PDF底图到竖线标记位置（共 " (itoa (length pages))
                 " 个底图，" (itoa (length markers)) " 个标记）"))
)

(defun PdfLayout_ArrangeObjsToMarkers (objs markers / pages i m p pt bb obj nDone res newBb)
  ;; 把指定对象（新导入的底图）按 左→右/上→下 排序后移动到竖线标记位置，
  ;; 用 vla-Move 移动（对任何对象有效），不依赖对象名识别；移动后校验是否到位
  (setq pages nil i 0 nDone 0)
  (foreach obj objs
    (setq bb (PdfLayout_GetExtentsSafeObj obj))
    (if bb
      (setq pages (append pages (list (cons i (cons obj bb)))))
    )
    (setq i (1+ i))
  )
  (setq pages (PdfLayout_StableSort pages (quote PdfLayout_CmpPages)))
  (if (not markers)
    (princ "\n未识别到竖线标记，跳过自动排列（请确认已画好竖线标记块且块名与弹窗中一致）。")
  )
  (setq i 0)
  (foreach m markers
    (setq p (if pages (nth i pages) nil))
    (if p
      (progn
        (setq p (cdr p))
        (setq obj (car p) bb (cdr p))
        (setq pt (car (cdr m)))
        (setq res (vl-catch-all-apply
                    (quote vla-Move)
                    (list obj
                          (vlax-3d-point (car (car bb)) (cadr (car bb)) 0.0)
                          (vlax-3d-point (car pt) (cadr pt) 0.0))))
        (setq newBb (PdfLayout_GetExtentsSafeObj obj))
        (if (and newBb (not (vl-catch-all-error-p res))
                 (< (abs (- (car (car newBb)) (car pt))) 1e-6)
                 (< (abs (- (cadr (car newBb)) (cadr pt))) 1e-6))
          (setq nDone (1+ nDone))
          (princ (strcat "\n[警告] 第 " (itoa (1+ i)) " 个底图未移动到目标标记 ("
                         (rtos (car pt) 2 2) "," (rtos (cadr pt) 2 2) ")"))
        )
      )
    )
    (setq i (1+ i))
  )
  (princ (strcat "\n已按 左→右/上→下 排列 " (itoa nDone)
                 " 个新导入的 PDF 底图到竖线标记位置（标记数 " (itoa (length markers)) "）"))
)
(defun PdfLayout_ScanBlockDrawings (filter / doc ms obj name bbox lst)
  (setq doc (vla-get-ActiveDocument (vlax-get-Acad-Object)))
  (setq ms (vla-get-ModelSpace doc))
  (setq filter (if filter (strcase filter) ""))
  (setq lst nil)
  (vlax-for obj ms
    (if (= (vla-get-ObjectName obj) "AcDbBlockReference")
      (progn
        (setq name (vla-get-Name obj))
        (if (or (= filter "") (vl-string-search filter (strcase name)))
          (progn
            (setq bbox (PdfLayout_GetExtentsSafeObj obj))
            (if bbox
              (setq lst (append lst (list (cons obj bbox))))
            )
          )
        )
      )
    )
  )
  (PdfLayout_SortByPosition lst)
)

(defun PdfLayout_InsertSorted (lst x cmp / done out)
  ;; cmp 为命名比较函数（符号），中望不支持把 (quote (lambda ...)) 传给 apply
  (setq done nil out nil)
  (foreach y lst
    (if (and (not done) (apply cmp (list x y)))
      (progn
        (setq out (append out (list x)))
        (setq done T)
      )
    )
    (setq out (append out (list y)))
  )
  (if (not done) (setq out (append out (list x))))
  out
)

(defun PdfLayout_StableSort (lst cmp / out)
  ;; 稳定插入排序：不依赖中望 vl-sort；插入排序本身稳定，并列保持原顺序、不丢元素
  (setq out nil)
  (foreach x lst
    (setq out (PdfLayout_InsertSorted out x cmp))
  )
  out
)

(defun PdfLayout_SortIndexed (lst cmp)
  (PdfLayout_StableSort lst cmp)
)

;; 8 种精确排序比较器：a 排在 b 前返回 T
(defun PdfLayout_CmpPos (a b / c1 c2 y1 y2 x1 x2)
  (setq c1 (PdfLayout_BBoxCenter (cdr a)))
  (setq c2 (PdfLayout_BBoxCenter (cdr b)))
  (setq y1 (cadr c1) y2 (cadr c2) x1 (car c1) x2 (car c2))
  (if (equal y1 y2 1e-6) (< x1 x2) (> y1 y2))
)
(defun PdfLayout_CmpLR (a b / c1 c2 y1 y2 x1 x2)
  (setq c1 (PdfLayout_BBoxCenter (cdr a)))
  (setq c2 (PdfLayout_BBoxCenter (cdr b)))
  (setq x1 (car c1) x2 (car c2) y1 (cadr c1) y2 (cadr c2))
  (if (equal x1 x2 1e-6) (> y1 y2) (< x1 x2))
)
(defun PdfLayout_CmpRL (a b / c1 c2 y1 y2 x1 x2)
  (setq c1 (PdfLayout_BBoxCenter (cdr a)))
  (setq c2 (PdfLayout_BBoxCenter (cdr b)))
  (setq x1 (car c1) x2 (car c2) y1 (cadr c1) y2 (cadr c2))
  (if (equal x1 x2 1e-6) (> y1 y2) (> x1 x2))
)
(defun PdfLayout_CmpBT (a b / c1 c2 y1 y2 x1 x2)
  (setq c1 (PdfLayout_BBoxCenter (cdr a)))
  (setq c2 (PdfLayout_BBoxCenter (cdr b)))
  (setq y1 (cadr c1) y2 (cadr c2) x1 (car c1) x2 (car c2))
  (if (equal y1 y2 1e-6) (< x1 x2) (< y1 y2))
)
(defun PdfLayout_CmpLRBT (a b / c1 c2 x1 x2 y1 y2)
  (setq c1 (PdfLayout_BBoxCenter (cdr a)))
  (setq c2 (PdfLayout_BBoxCenter (cdr b)))
  (setq x1 (car c1) x2 (car c2) y1 (cadr c1) y2 (cadr c2))
  (if (equal x1 x2 1e-6) (< y1 y2) (< x1 x2))
)
(defun PdfLayout_CmpRLBT (a b / c1 c2 x1 x2 y1 y2)
  (setq c1 (PdfLayout_BBoxCenter (cdr a)))
  (setq c2 (PdfLayout_BBoxCenter (cdr b)))
  (setq x1 (car c1) x2 (car c2) y1 (cadr c1) y2 (cadr c2))
  (if (equal x1 x2 1e-6) (< y1 y2) (> x1 x2))
)
(defun PdfLayout_CmpTBR (a b / c1 c2 x1 x2 y1 y2)
  (setq c1 (PdfLayout_BBoxCenter (cdr a)))
  (setq c2 (PdfLayout_BBoxCenter (cdr b)))
  (setq x1 (car c1) x2 (car c2) y1 (cadr c1) y2 (cadr c2))
  (if (equal y1 y2 1e-6) (> x1 x2) (> y1 y2))
)
(defun PdfLayout_CmpBTR (a b / c1 c2 x1 x2 y1 y2)
  (setq c1 (PdfLayout_BBoxCenter (cdr a)))
  (setq c2 (PdfLayout_BBoxCenter (cdr b)))
  (setq x1 (car c1) x2 (car c2) y1 (cadr c1) y2 (cadr c2))
  (if (equal y1 y2 1e-6) (> x1 x2) (< y1 y2))
)
;; 次方向比较器
(defun PdfLayout_CmpXAsc (a b / c1 c2)
  (setq c1 (PdfLayout_BBoxCenter (cdr a)))
  (setq c2 (PdfLayout_BBoxCenter (cdr b)))
  (< (car c1) (car c2))
)
(defun PdfLayout_CmpXDesc (a b / c1 c2)
  (setq c1 (PdfLayout_BBoxCenter (cdr a)))
  (setq c2 (PdfLayout_BBoxCenter (cdr b)))
  (> (car c1) (car c2))
)
(defun PdfLayout_CmpYAsc (a b / c1 c2)
  (setq c1 (PdfLayout_BBoxCenter (cdr a)))
  (setq c2 (PdfLayout_BBoxCenter (cdr b)))
  (< (cadr c1) (cadr c2))
)
(defun PdfLayout_CmpYDesc (a b / c1 c2)
  (setq c1 (PdfLayout_BBoxCenter (cdr a)))
  (setq c2 (PdfLayout_BBoxCenter (cdr b)))
  (> (cadr c1) (cadr c2))
)
;; 其他用途比较器
(defun PdfLayout_CmpYGreater (a b) (> (car a) (car b)))
(defun PdfLayout_CmpLbd (a b / ka kb)
  (setq ka (PdfLayout_NumKey (nth 1 a)))
  (setq kb (PdfLayout_NumKey (nth 1 b)))
  (if (= ka kb) (< (car a) (car b)) (< ka kb))
)
(defun PdfLayout_CmpRowTop (a b / ya yb)
  (setq ya (apply 'max (mapcar '(lambda (q) (cadr (PdfLayout_BBoxCenter (cdr q)))) a)))
  (setq yb (apply 'max (mapcar '(lambda (q) (cadr (PdfLayout_BBoxCenter (cdr q)))) b)))
  (> ya yb)
)
(defun PdfLayout_CmpRowBottom (a b / ya yb)
  ;; 竖线标记按底端 y 从高到低排序（a 排在 b 前返回 T）；
  ;; 用底端而不是中心点分行，竖线长短不一样也不影响同一行识别
  (setq ya (cadr (car (cdr a))))
  (setq yb (cadr (car (cdr b))))
  (> ya yb)
)
(defun PdfLayout_SortMarkersRowMajor (lst / sorted diffs prevK sd tol groups g out grp k)
  ;; 竖线标记按行排序：行内从左往右，行间从上往下。
  ;; 以底端 y 分行；容差按相邻底端差的中低位数自动估算，
  ;; 摆放不整齐、竖线长短不一都能正确分行
  (if (< (length lst) 2)
    lst
    (progn
      (setq sorted (PdfLayout_SortIndexed lst 'PdfLayout_CmpRowBottom))
      ;; 收集相邻底端差（行内小、行间大）
      (setq diffs nil prevK (cadr (car (cdr (car sorted)))))
      (foreach p (cdr sorted)
        (setq k (cadr (car (cdr p))))
        (setq diffs (cons (abs (- prevK k)) diffs))
        (setq prevK k)
      )
      (setq sd (PdfLayout_StableSort diffs '<))
      (setq tol (max 1.0 (* 3.0 (nth (fix (* 0.30 (1- (length sd)))) sd))))
      ;; 按相邻底端差超过容差 分行
      (setq groups nil g (list (car sorted))
            prevK (cadr (car (cdr (car sorted)))))
      (foreach p (cdr sorted)
        (setq k (cadr (car (cdr p))))
        (if (> (abs (- prevK k)) tol)
          (progn
            (setq groups (append groups (list g)))
            (setq g (list p))
          )
          (setq g (append g (list p)))
        )
        (setq prevK k)
      )
      (setq groups (append groups (list g)))
      ;; 每行内从左往右，行与行按从上往下拼接
      (setq out nil)
      (foreach grp groups
        (setq grp (PdfLayout_SortIndexed grp 'PdfLayout_CmpXAsc))
        (setq out (append out grp))
      )
      out
    )
  )
)
(defun PdfLayout_CmpPages (a b / c1 c2 x1 x2 y1 y2)
  (setq c1 (PdfLayout_BBoxCenter (cdr (cdr a))))
  (setq c2 (PdfLayout_BBoxCenter (cdr (cdr b))))
  (setq x1 (car c1) x2 (car c2) y1 (cadr c1) y2 (cadr c2))
  (cond
    ((equal x1 x2 1e-6)
      (if (equal y1 y2 1e-6) (< (car a) (car b)) (> y1 y2))
    )
    (t (< x1 x2))
  )
)
(defun PdfLayout_CmpVpArea (a b) (> (cdr a) (cdr b)))

(defun PdfLayout_SortByPosition (lst) (PdfLayout_SortIndexed lst 'PdfLayout_CmpPos))

(defun PdfLayout_SelectionBBox (ss / i ename obj bb pmin pmax minPt maxPt b)
  (setq i 0 minPt nil maxPt nil)
  (repeat (sslength ss)
    (setq ename (ssname ss i))
    (setq obj (vlax-ename->vla-object ename))
    (setq b (PdfLayout_GetExtentsSafeObj obj))
    (if b
      (progn
        (setq pmin (car b) pmax (cadr b))
        (if minPt
          (progn
            (setq minPt (list (min (car minPt) (car pmin))
                              (min (cadr minPt) (cadr pmin))
                              (min (caddr minPt) (caddr pmin))))
            (setq maxPt (list (max (car maxPt) (car pmax))
                              (max (cadr maxPt) (cadr pmax))
                              (max (caddr maxPt) (caddr pmax))))
          )
          (setq minPt pmin maxPt pmax)
        )
      )
    )
    (setq i (1+ i))
  )
  (if minPt (list minPt maxPt) nil)
)

(defun PdfLayout_SortByPositionLR (lst) (PdfLayout_SortIndexed lst 'PdfLayout_CmpLR))

(defun PdfLayout_SortByPositionRL (lst) (PdfLayout_SortIndexed lst 'PdfLayout_CmpRL))

(defun PdfLayout_SortByPositionBT (lst) (PdfLayout_SortIndexed lst 'PdfLayout_CmpBT))
(defun PdfLayout_SortByPositionLRBT (lst) (PdfLayout_SortIndexed lst 'PdfLayout_CmpLRBT))

(defun PdfLayout_SortByPositionRLBT (lst) (PdfLayout_SortIndexed lst 'PdfLayout_CmpRLBT))

(defun PdfLayout_SortByPositionTBR (lst) (PdfLayout_SortIndexed lst 'PdfLayout_CmpTBR))

(defun PdfLayout_SortByPositionBTR (lst) (PdfLayout_SortIndexed lst 'PdfLayout_CmpBTR))
(defun PdfLayout_SortPairsSmart (pairs order / cmpMain cmpSec axis xs ys xRange yRange tol
                                 sorted groups g gKey out grp c k)
  ;; 用户手动摆放位置不一定整齐，按“容差”分行/分列后再排序
  (setq cmpMain (cond
    ((= order "1") 'PdfLayout_CmpLR)
    ((= order "2") 'PdfLayout_CmpPos)
    ((= order "3") 'PdfLayout_CmpRL)
    ((= order "4") 'PdfLayout_CmpBT)
    ((= order "5") 'PdfLayout_CmpLRBT)
    ((= order "6") 'PdfLayout_CmpRLBT)
    ((= order "7") 'PdfLayout_CmpTBR)
    ((= order "8") 'PdfLayout_CmpBTR)
    (t nil)
  ))
  (if (null cmpMain)
    pairs
    (progn
      (setq cmpSec (cond
        ((member order '("1" "3")) 'PdfLayout_CmpYDesc)
        ((member order '("5" "6")) 'PdfLayout_CmpYAsc)
        ((member order '("2" "4")) 'PdfLayout_CmpXAsc)
        ((member order '("7" "8")) 'PdfLayout_CmpXDesc)
        (t 'PdfLayout_CmpXAsc)
      ))
      (setq axis (if (member order '("1" "3" "5" "6")) "X" "Y"))
      (setq xs (mapcar '(lambda (q) (car (PdfLayout_BBoxCenter (cdr q)))) pairs))
      (setq ys (mapcar '(lambda (q) (cadr (PdfLayout_BBoxCenter (cdr q)))) pairs))
      (setq xRange (- (apply 'max xs) (apply 'min xs)))
      (setq yRange (- (apply 'max ys) (apply 'min ys)))
      (setq tol (max 1.0 (* (if (and *PdfLayout_RowTol* (> *PdfLayout_RowTol* 0)) *PdfLayout_RowTol* 10)
                            0.01 (if (= axis "X") xRange yRange))))
      ;; 先按主方向排序
      (setq sorted (PdfLayout_SortIndexed pairs cmpMain))
      ;; 按容差分成行/列组
      (setq groups nil g nil gKey nil)
      (foreach p sorted
        (setq c (PdfLayout_BBoxCenter (cdr p)))
        (setq k (if (= axis "X") (car c) (cadr c)))
        (if (and gKey (<= (abs (- gKey k)) tol))
          (setq g (append g (list p)))
          (progn
            (if g (setq groups (append groups (list g))))
            (setq g (list p) gKey k)
          )
        )
      )
      (if g (setq groups (append groups (list g))))
      ;; 组内按次方向排序，按组拼接
      (setq out nil)
      (foreach grp groups
        (setq grp (PdfLayout_SortIndexed grp cmpSec))
        (setq out (append out grp))
      )
      out
    )
  )
)

(defun PdfLayout_PickDrawingsOnce (filter / ss i ename obj name bbox lst)
  (princ "\n请一次性框选所有图纸的块参照（可输入 ALL 全选），然后回车（Esc取消）: ")
  (setq ss (ssget))
  (if (not ss)
    (progn
      (princ "\n已取消图纸选择。")
      nil
    )
    (progn
      (setq lst nil i 0)
      (repeat (sslength ss)
        (setq ename (ssname ss i))
        (setq obj (vlax-ename->vla-object ename))
        (if (= (vla-get-ObjectName obj) "AcDbBlockReference")
          (progn
            (setq name (vla-get-Name obj))
            (if (or (not filter) (= filter "")
                    (vl-string-search (strcase filter) (strcase name)))
              (progn
                (setq bbox (PdfLayout_GetExtentsSafeObj obj))
                (if bbox
                  (setq lst (append lst (list (cons obj bbox))))
                )
              )
            )
          )
        )
        (setq i (1+ i))
      )
      (if (= (length lst) 0)
        (progn
          (princ "\n选择集中没有找到符合条件的图纸块。请确认图纸以参考底图或图块形式存在并框选到图纸块；或改用自动识别模式。")
          nil
        )
        (progn
          (princ (strcat "\n识别到 " (itoa (length lst))
                         " 张图纸，按 从左到右、从上到下 排序对应。"))
          (mapcar 'cdr (PdfLayout_SortByPositionLR lst))
        )
      )
    )
  )
)
(defun PdfLayout_PickDrawings (count / i ss bbox lst)
  (setvar "TILEMODE" 1)
  (setq i 1)
  (setq lst nil)
  (while (<= i count)
    (princ (strcat "\n请框选第 " (itoa i) "/" (itoa count)
                   " 张图纸的所有实体后回车（按Esc取消）: "))
    (setq ss (ssget))
    (if (not ss)
      (progn
        (princ "\n已取消图纸选择。")
        (setq lst nil)
        (setq i (1+ count))
      )
      (progn
        (setq bbox (PdfLayout_SelectionBBox ss))
        (if bbox
          (progn
            (setq lst (append lst (list bbox)))
            (setq i (1+ i))
          )
          (princ "\n所选对象没有有效范围，请重新选择。")
        )
      )
    )
  )
  lst
)

;;;-------------------------------------------------------------
;;; 布局操作
;;;-------------------------------------------------------------
(defun PdfLayout_GetLayoutNames (/ doc layouts out)
  (setq doc (vla-get-ActiveDocument (vlax-get-Acad-Object)))
  (setq layouts (vla-get-Layouts doc))
  (setq out nil)
  (vlax-for l layouts
    (if (/= (strcase (vla-get-Name l)) "MODEL")
      (setq out (append out (list (vla-get-Name l))))
    )
  )
  out
)

(defun PdfLayout_GetLayoutObj (name / doc layouts result)
  (setq doc (vla-get-ActiveDocument (vlax-get-Acad-Object)))
  (setq layouts (vla-get-Layouts doc))
  (setq result nil)
  (vlax-for l layouts
    (if (= (strcase (vla-get-Name l)) (strcase name))
      (setq result l)
    )
  )
  result
)

(defun PdfLayout_LayoutExists (name)
  (not (null (PdfLayout_GetLayoutObj name)))
)

(defun PdfLayout_DeleteLayout (name / doc l act other)
  (setq doc (vla-get-ActiveDocument (vlax-get-Acad-Object)))
  (setq l (PdfLayout_GetLayoutObj name))
  (if l
    (progn
      (setq act (vla-get-ActiveLayout doc))
      (if (and act (= (strcase (vla-get-Name act)) (strcase name)))
        (progn
          (setq other nil)
          (vlax-for x (vla-get-Layouts doc)
            (if (and (not other)
                     (/= (strcase (vla-get-Name x)) (strcase name)))
              (setq other x)
            )
          )
          (if other
            (vl-catch-all-apply
              '(lambda () (setvar "CTAB" (vla-get-Name other)))
              nil
            )
          )
        )
      )
      (vl-catch-all-apply 'vla-Delete (list l))
    )
  )
)

(defun PdfLayout_CopyLayout (src dst / doc layouts srcLay newLay srcBlk newBlk
                             objs arr cnt ok)
  (setq ok nil)
  (setq doc (vla-get-ActiveDocument (vlax-get-Acad-Object)))
  (setq layouts (vla-get-Layouts doc))
  (setq srcLay (PdfLayout_GetLayoutObj src))
  (if (and srcLay (not (PdfLayout_LayoutExists dst)))
    (progn
      (setq newLay (vl-catch-all-apply 'vla-Add (list layouts dst)))
      (if (and newLay (not (vl-catch-all-error-p newLay)))
        (progn
          (vl-catch-all-apply 'vla-CopyFrom (list newLay srcLay))
          (setq srcBlk (vla-get-Block srcLay))
          (setq newBlk (vla-get-Block newLay))
          (setq objs nil)
          (vlax-for o srcBlk
            (if (/= (vla-get-ObjectName o) "AcDbViewport")
              (setq objs (append objs (list o)))
            )
          )
          (setq cnt (length objs))
          (if (> cnt 0)
            (progn
              (setq arr (vlax-make-safearray vlax-vbObject (cons 0 (1- cnt))))
              (vlax-safearray-fill arr objs)
              (vl-catch-all-apply 'vla-CopyObjects (list doc arr newBlk))
            )
          )
          (setq ok (PdfLayout_LayoutExists dst))
        )
      )
    )
  )
  ok
)

(defun PdfLayout_GetLayoutViewports (name / layout blk obj bb pmin pmax area vpList)
  (setq layout (PdfLayout_GetLayoutObj name))
  (setq vpList nil)
  (if layout
    (progn
      (setq blk (vla-get-Block layout))
      (vlax-for obj blk
        (if (= (vla-get-ObjectName obj) "AcDbViewport")
          (progn
            (setq bb (PdfLayout_GetExtentsSafeObj obj))
            (if bb
              (progn
                (setq pmin (car bb) pmax (cadr bb))
                (setq area (* (- (car pmax) (car pmin))
                              (- (cadr pmax) (cadr pmin))))
                (setq vpList (append vpList (list (cons obj area))))
              )
            )
          )
        )
      )
    )
  )
  vpList
)

(defun PdfLayout_GetViewportFrame (name / vps vp)
  (setq vps (PdfLayout_GetLayoutViewports name))
  (if vps
    (progn
      (setq vp (car (PdfLayout_StableSort vps 'PdfLayout_CmpVpArea)))
      (PdfLayout_GetExtentsSafeObj (car vp))
    )
  )
)

(defun PdfLayout_DeleteViewportsExcept (name keepObj / layout blk obj toDel)
  (setq layout (PdfLayout_GetLayoutObj name))
  (setq toDel nil)
  (if layout
    (progn
      (setq blk (vla-get-Block layout))
      (vlax-for obj blk
        (if (and (= (vla-get-ObjectName obj) "AcDbViewport")
                 (not (equal obj keepObj)))
          (setq toDel (append toDel (list obj)))
        )
      )
      (foreach o toDel
        (vl-catch-all-apply 'vla-Delete (list o))
      )
    )
  )
)

(defun PdfLayout_CreateViewport (pt1 pt2 / oldCmdEcho oldExpert ename result)
  (setq oldCmdEcho (getvar "CMDECHO"))
  (setq oldExpert (getvar "EXPERT"))
  (setvar "CMDECHO" 0)
  (setvar "EXPERT" 5)
  (command "._MVIEW" pt1 pt2 "")
  (setq ename (entlast))
  (if (and ename (= (cdr (assoc 0 (entget ename))) "VIEWPORT"))
    (setq result ename)
    (setq result nil)
  )
  (setvar "CMDECHO" oldCmdEcho)
  (setvar "EXPERT" oldExpert)
  result
)

(defun PdfLayout_CreateViewportFromMargin (margin / doc layout pw ph vpMin vpMax)
  (setq doc (vla-get-ActiveDocument (vlax-get-Acad-Object)))
  (setq layout (vla-get-ActiveLayout doc))
  (setq pw (vla-get-PaperWidth layout))
  (setq ph (vla-get-PaperHeight layout))
  (setq vpMin (list margin margin 0.0))
  (setq vpMax (list (- pw margin) (- ph margin) 0.0))
  (PdfLayout_CreateViewport vpMin vpMax)
)

(defun PdfLayout_FitViewport (vpObj bbox lockVp
                              / bb pmin pmax pw ph minPt maxPt center w h
                                scale viewH ok oldCmdEcho oldExpert)
  (setq bb (PdfLayout_GetExtentsSafeObj vpObj))
  (if (and bb bbox)
    (progn
      (setq pmin (car bb) pmax (cadr bb))
      (setq pw (* (- (car pmax) (car pmin)) *PdfLayout_ViewInset*))
      (setq ph (* (- (cadr pmax) (cadr pmin)) *PdfLayout_ViewInset*))
      (setq minPt (car bbox) maxPt (cadr bbox))
      (setq center (list (/ (+ (car minPt) (car maxPt)) 2.0)
                         (/ (+ (cadr minPt) (cadr maxPt)) 2.0)
                         0.0))
      (setq w (- (car maxPt) (car minPt)))
      (setq h (- (cadr maxPt) (cadr minPt)))
      (if (and (> pw 0.0) (> ph 0.0) (> w 0.0) (> h 0.0))
        (progn
          (setq scale (min (/ pw w) (/ ph h)))
          (setq viewH (/ ph scale))
          (if *PdfLayout_Debug*
            (princ (strcat "\n[PDF布局调试] 图纸 " (rtos w 2 2) " x " (rtos h 2 2)
                           " | 视口 " (rtos pw 2 2) " x " (rtos ph 2 2)
                           " | 比例 " (rtos scale 2 4)
                           " | 视图高 " (rtos viewH 2 2)))
          )
          (setq oldCmdEcho (getvar "CMDECHO"))
          (setq oldExpert (getvar "EXPERT"))
          (setvar "CMDECHO" 0)
          (setvar "EXPERT" 5)
          ;; 方式一：ActiveX 直接设置视口视图（中望兼容更稳）
          (setq ok
            (not (vl-catch-all-error-p
                   (vl-catch-all-apply
                     '(lambda ()
                       (vla-put-ViewportOn vpObj :vlax-true)
                       (vla-put-ViewCenter vpObj (vlax-3d-point center))
                       (vla-put-ViewHeight vpObj viewH)
                     )
                     nil))))
          ;; 方式二：命令方式兜底
          (if (not ok)
            (progn
              (vl-catch-all-apply 'vla-put-ViewportOn (list vpObj :vlax-true))
              (command "._MSPACE")
              (command "._ZOOM" "_C" center viewH)
              (command "._PSPACE")
              (setq ok T)
            )
          )
          (if lockVp
            (vl-catch-all-apply 'vla-put-DisplayLocked (list vpObj :vlax-true))
            (vl-catch-all-apply 'vla-put-DisplayLocked (list vpObj :vlax-false))
          )
          (setvar "CMDECHO" oldCmdEcho)
          (setvar "EXPERT" oldExpert)
        )
      )
    )
  )
)

(defun PdfLayout_HideViewportFrame (vpObj / doc layers lname layer)
  (setq doc (vla-get-ActiveDocument (vlax-get-Acad-Object)))
  (setq layers (vla-get-Layers doc))
  (setq lname "视口框")
  (setq layer nil)
  (vlax-for l layers
    (if (= (strcase (vla-get-Name l)) (strcase lname))
      (setq layer l)
    )
  )
  (if (not layer)
    (setq layer (vl-catch-all-apply 'vla-Add (list layers lname)))
  )
  (if (and layer (not (vl-catch-all-error-p layer)))
    (progn
      (if vpObj
        (vl-catch-all-apply 'vla-put-Layer (list vpObj lname))
      )
      (vl-catch-all-apply 'vla-put-LayerOn (list layer :vlax-false))
      (if (member "VLA-PUT-PLOTTABLE" (atoms-family 1))        (vl-catch-all-apply 'vla-put-Plottable (list layer :vlax-false))      )
    )
  )
)
(defun PdfLayout_SetupLayout (layoutName bbox margin framePts lockVp
                              / vps vp vpObj ename)
  (command ".-LAYOUT" "_S" layoutName "")
  (setq vps (PdfLayout_GetLayoutViewports layoutName))
  (if framePts
    (progn
      (PdfLayout_DeleteViewportsExcept layoutName nil)
      (setq ename (PdfLayout_CreateViewport (car framePts) (cadr framePts)))
      (if ename
        (progn
          (setq vpObj (vlax-ename->vla-object ename))
          (PdfLayout_FitViewport vpObj bbox lockVp)
        )
      )
    )
    (if vps
      (progn
        (setq vp (car (PdfLayout_StableSort vps 'PdfLayout_CmpVpArea)))
        (setq vpObj (car vp))
        (PdfLayout_DeleteViewportsExcept layoutName vpObj)
        (PdfLayout_FitViewport vpObj bbox lockVp)
      )
      (progn
        (setq ename (PdfLayout_CreateViewportFromMargin margin))
        (if ename
          (progn
          (setq vpObj (vlax-ename->vla-object ename))
          (PdfLayout_FitViewport vpObj bbox lockVp)
        )
        )
      )
    )
  )
)

;;;-------------------------------------------------------------
;;; 主流程
;;;-------------------------------------------------------------
(defun PdfLayout_Execute (/ params mode filter tmpl count rule lettersStr
                            pg gStart margin overwrite lockVp ok msg drawings nDraw
                            names i idx n conflict framePts p1 p2 created undoOn
                            failedNames msgText autoArrange dlgSel markers pdfFile newObjs
                            namesList)
  (setq params *PdfLayout_Params*)
  (setq mode "marker")
  (setq autoArrange (PdfLayout_GetParam params "AutoArrange"))
  (setq dlgSel (PdfLayout_GetParam params "DlgSel"))
  (setq pdfFile (PdfLayout_GetParam params "PdfFile"))
  (setq filter (PdfLayout_GetParam params "Filter"))
  (setq tmpl (PdfLayout_GetParam params "TemplateLayout"))
  (setq count (PdfLayout_GetParam params "Count"))
  (setq rule (PdfLayout_GetParam params "Rule"))
  (setq lettersStr (PdfLayout_GetParam params "Letters"))
  (setq pg (PdfLayout_GetParam params "PerGroup"))
  (setq gStart (PdfLayout_GetParam params "GroupStart"))
  (setq margin (PdfLayout_GetParam params "Margin"))
  (setq overwrite (PdfLayout_GetParam params "Overwrite"))
  (setq lockVp (PdfLayout_GetParam params "LockViewport"))
  (setq namesList (PdfLayout_GetParam params "NamesList"))
  (setq ok T)
  (if (not pg) (setq pg 6))
  (if (<= pg 0) (setq pg 6))
  (if (not gStart) (setq gStart 1))
  (if (<= gStart 0) (setq gStart 1))
  (if (not margin) (setq margin 5))
  (if (< margin 0) (setq margin 0))

  ;; 1. 模板布局校验
  (if (not (PdfLayout_GetLayoutObj tmpl))
    (progn
      (alert "模板布局无效或不存在，操作已取消。")
      (setq ok nil)
    )
  )

  ;; 2. 命名规则校验
  (if ok
    (progn
      (setq msg (PdfLayout_ValidateRule rule lettersStr))
      (if msg
        (progn
          (alert msg)
          (setq ok nil)
        )
      )
    )
  )

  ;; 3. 识别图纸
  (if ok
    (progn
      (if (and pdfFile (/= pdfFile ""))
        (setq newObjs
          (if dlgSel
            (PdfLayout_ImportPdfDialog pdfFile)
            (PdfLayout_ImportPdfFile pdfFile)
          )
        )
      )
      (if autoArrange
        (cond
          (newObjs
            (PdfLayout_ArrangeObjsToMarkers newObjs (PdfLayout_ScanMarkers filter)))
          ((or (not pdfFile) (= pdfFile ""))
            ;; 未选择 PDF：排列模型空间里已有全部底图（对应手动导入后只排序的情况）
            (PdfLayout_ArrangePagesToMarkers (PdfLayout_ScanMarkers filter)))
          ;; 已选择 PDF 但导入失败或弹窗被取消：不排列旧底图，避免打乱
        )
      )
      (setq drawings (PdfLayout_ScanMarkerDrawings filter))
      (if (<= count 0) (setq count (length drawings)))
      (setq nDraw (length drawings))
      (if (= nDraw 0)
        (progn
          (alert "没有识别到任何图纸。请确认竖线标记块名与弹窗中一致、且 PDF 底图已导入；或改用手动模式一次性框选全部。")
          (setq ok nil)
        )
        (progn
          (if (and (or (= mode "auto") (= mode "marker")) (<= count 0))
            (setq count nDraw)
          )
          (if (> count nDraw)
            (progn
              (princ (strcat "\n识别到 " (itoa nDraw)
                             " 张图纸，少于设置的 " (itoa count)
                             " 个，按 " (itoa nDraw) " 个执行。"))
              (setq count nDraw)
            )
          )
        )
      )
    )
  )

  ;; 4. 生成布局名称
  (if ok
    (progn
      (if namesList
        (progn
          ;; 布局名来自Excel分表：按分表顺序截取 count 个
          (setq names nil i 0)
          (while (and (< i count) (< i (length namesList)))
            (setq names (append names (list (nth i namesList))))
            (setq i (1+ i))
          )
        )
        (setq names (PdfLayout_GenNames rule lettersStr pg gStart count))
      )
      (if (not names)
        (progn
          (alert "命名规则无法生成足够数量的不重复名称，请检查规则、字母列表和每组张数。")
          (setq ok nil)
        )
        (progn
          (if (PdfLayout_HasDuplicate names)
            (progn
              (alert "生成的布局名称存在重复，请调整命名规则。")
              (setq ok nil)
            )
            (progn
              (setq conflict nil)
              (foreach n names
                (if (not (PdfLayout_ValidLayoutName n))
                  (setq conflict n)
                )
              )
              (if conflict
                (progn
                  (alert (strcat "布局名称 " conflict
                                 " 包含非法字符(< > / \\ \" : ; ? * | , = 等)。"))
                  (setq ok nil)
                )
              )
            )
          )
          (if (and ok (vl-some '(lambda (n) (= (strcase n) (strcase tmpl))) names))
            (progn
              (alert "生成的名称中包含模板布局名，请调整命名规则或更换模板。")
              (setq ok nil)
            )
          )
          (if ok
            (progn
              (setq conflict nil)
              (foreach n names
                (if (and (PdfLayout_LayoutExists n) (not overwrite))
                  (setq conflict n)
                )
              )
              (if conflict
                (progn
                  (alert (strcat "布局 " conflict
                                 " 已存在。请勾选“覆盖同名布局”或修改命名规则。"))
                  (setq ok nil)
                )
              )
            )
          )
        )
      )
    )
  )

  ;; 5. 执行：复制布局 + 视口对应
  (if ok
    (progn
      (if overwrite
        (foreach n names
          (if (PdfLayout_LayoutExists n)
            (PdfLayout_DeleteLayout n)
          )
        )
      )
      ;; 模板布局视口/图框处理
      (setq framePts (PdfLayout_GetViewportFrame tmpl))
      (if (not framePts)
        (progn
          (command ".-LAYOUT" "_S" tmpl "")
          (setq p1 (getpoint "\n模板布局中没有视口，请点取图框第一角（回车则按纸张边距创建视口）: "))
          (if p1 (setq p2 (getpoint p1 "\n请点取图框对角: ")))
          (if (and p1 p2) (setq framePts (list p1 p2)))
        )
      )
      (setq created nil)
      (setq undoOn (= (logand (getvar "UNDOCTL") 1) 1))
      (setq *PdfLayout_UndoOn* undoOn)
      (if undoOn (command "._UNDO" "_BE"))
      (setq *PdfLayout_Running* T)
      (setq *PdfLayout_CreatedLayouts* nil)
      (setq idx 0)
      (foreach n names
        (princ (strcat "\n  创建 " (itoa (1+ idx)) "/" (itoa (length names))
                       " : " n " ..."))
        (if (PdfLayout_CopyLayout tmpl n)
          (progn
            (setq created (append created (list n)))
            (setq *PdfLayout_CreatedLayouts* created)
            (PdfLayout_SetupLayout n (nth idx drawings) margin framePts lockVp)
            (princ " 成功")
          )
          (progn
            (princ " 失败")
            (setq failedNames (append failedNames (list n)))
          )
        )
        (setq idx (1+ idx))
      )
      (if undoOn (command "._UNDO" "_E"))
      (setq *PdfLayout_Running* nil)
      (setq *PdfLayout_CreatedLayouts* nil)
      (setq *PdfLayout_UndoOn* nil)
      (if created
        (command ".-LAYOUT" "_S" (car created) "")
      )
      (princ (strcat "\n完成：共创建 " (itoa (length created))
                     " 个布局，模型图纸已按顺序对应到各布局视口。"))
      (if failedNames
        (progn
          (princ (strcat " 失败 " (itoa (length failedNames)) " 个:"))
          (foreach f failedNames
            (princ (strcat " " f))
          )
        )
      )
      (setq msgText (strcat "布局生成完成\n\n成功创建 " (itoa (length created))
                            " / " (itoa (length names)) " 个布局"))
      (if failedNames
        (progn
          (setq msgText (strcat msgText "\n失败 " (itoa (length failedNames)) " 个："))
          (foreach f failedNames
            (setq msgText (strcat msgText " " f))
          )
        )
      )
      (alert msgText)
    )
  )
  ok
)

;;;-------------------------------------------------------------
;;; 查找DCL文件
;;;-------------------------------------------------------------
(defun PdfLayout_FileExists (path / f)
  (setq f (open path "r"))
  (if f
    (progn
      (close f)
      T
    )
    nil
  )
)

(defun PdfLayout_WriteDcl (dir / path f)
  (setq path (strcat dir "PdfLayout.dcl"))
  (setq f (open path "w"))
  (if f
    (progn
      (foreach line *PdfLayout_DclLines*
        (princ line f)
        (princ "\n" f)
      )
      (close f)
      T
    )
    nil
  )
)

(defun PdfLayout_FindDcl (/ dir)
  ;; 每次打开弹窗前都重写内置 DCL，防止系统临时目录残留旧版
  ;; DCL（缺少新控件）导致中望CAD报“类型不正确”错误
  (setq dir (getvar "TEMPPREFIX"))
  (if (not (PdfLayout_WriteDcl dir))
    (progn
      (setq dir (getvar "DWGPREFIX"))
      (PdfLayout_WriteDcl dir)
    )
  )
  (setq *PdfLayout_DclWritten* T)
  (strcat dir "PdfLayout.dcl")
)

;;;-------------------------------------------------------------
;;; 对话框
;;;-------------------------------------------------------------
(defun PdfLayout_InitDialog (/ layouts tmp activeName idx)
  (princ "\n[调试] 初始化主对话框")
  (setq layouts (PdfLayout_GetLayoutNames))
  (if layouts
    (progn
      (PdfLayout_SetList "tmpl_layout" layouts)
      (setq activeName (vla-get-Name (vla-get-ActiveLayout
                                      (vla-get-ActiveDocument
                                        (vlax-get-Acad-Object)))))
      (setq tmp (if (member activeName layouts) activeName (car layouts)))
      (setq idx 0)
      (foreach l layouts
        (if (= (strcase l) (strcase tmp))
          (set_tile "tmpl_layout" (itoa idx))
        )
        (setq idx (1+ idx))
      )
    )
  )
  (PdfLayout_SetList "marker_name" (PdfLayout_GetMarkerNameList))
  (set_tile "marker_name" (itoa (PdfLayout_MarkerNameIndex "pdf")))
  (set_tile "count" "0")
  (set_tile "overwrite" "0")
  (if (and *PdfLayout_LastNamesXlsx* (/= *PdfLayout_LastNamesXlsx* ""))
    (set_tile "names_xlsx" *PdfLayout_LastNamesXlsx*)
  )  (if (and *PdfLayout_LayRule* (/= *PdfLayout_LayRule* ""))
    (progn
      (set_tile "rule" *PdfLayout_LayRule*)
      (set_tile "letters" *PdfLayout_LayLetters*)
      (set_tile "per_group" (itoa *PdfLayout_LayPerGroup*))
      (set_tile "g_start" (itoa *PdfLayout_LayGStart*))
    )
  )
  (set_tile "rule" "INV{G2}{L}{N2}")
  (set_tile "letters" "AB")
  (set_tile "per_group" "6")
  (set_tile "g_start" "1")
  (set_tile "margin" "5")
  (PdfLayout_UpdateFoundInfo)
  (PdfLayout_UpdatePreview)
)

(defun PdfLayout_UpdateFoundInfo (/ mnList mn n)
  (setq mnList (PdfLayout_GetMarkerNameList))
  (setq mn (nth (atoi (PdfLayout_GetTileStr "marker_name")) mnList))
  (if (not mn) (setq mn "pdf"))
  (setq n (length (PdfLayout_ScanMarkers mn)))
  (set_tile "found_info"
    (if (= n 0)
      (strcat "未识别到竖线标记“" mn "”，请检查竖线块名")
      (strcat "已识别到 " (itoa n) " 个竖线标记，按 行内左→右、行间上→下 匹配")
    )
  )
)

(defun PdfLayout_UpdatePreview (/ count rule lettersStr pg gStart names i s)
  (setq count (atoi (get_tile "count")))
  (setq rule (get_tile "rule"))
  (setq lettersStr (get_tile "letters"))
  (setq pg (atoi (get_tile "per_group")))
  (if (<= pg 0) (setq pg 1))
  (setq gStart (atoi (get_tile "g_start")))
  (if (<= gStart 0) (setq gStart 1))
  (if (and *PdfLayout_NamesXlsxList* (/= (PdfLayout_GetTileStr "names_xlsx") ""))
    (progn
      (setq names *PdfLayout_NamesXlsxList*)
      (setq s "")
      (setq i 0)
      (while (and (< i (length names)) (< i 40))
        (setq s (strcat s (nth i names) "\n"))
        (setq i (1+ i))
      )
      (if (> (length names) 40)
        (setq s (strcat s "…共 " (itoa (length names)) " 个分表"))
      )
      (set_tile "preview" s)
    )
    (if (<= count 0)
      (set_tile "preview" "复制数量：0 表示按识别到的标记数量")
      (progn
        (setq names (PdfLayout_GenNames rule lettersStr pg gStart count))
        (if names
          (progn
            (setq s "")
            (setq i 0)
            (while (and (< i count) (< i 40))
              (setq s (strcat s (nth i names) "\n"))
              (setq i (1+ i))
            )
            (if (> count 40)
              (setq s (strcat s "…共 " (itoa count) " 个"))
            )
            (set_tile "preview" s)
          )
          (set_tile "preview" "规则无法生成足够的不重复名称，请检查参数")
        )
      )
    )
  )
)

(defun PdfLayout_GetMarkerNameList (/ doc ms obj name names)
  (setq doc (vla-get-ActiveDocument (vlax-get-Acad-Object)))
  (setq ms (vla-get-ModelSpace doc))
  (setq names (list "pdf"))
  (vlax-for obj ms
    (if (= (vla-get-ObjectName obj) "AcDbBlockReference")
      (progn
        (setq name (vla-get-Name obj))
        (if (and name (= (type name) (quote STR))
                 (not (member (strcase name) (mapcar (quote strcase) names))))
          (setq names (append names (list name)))
        )
      )
    )
  )
  names
)

(defun PdfLayout_MarkerNameIndex (name / lst idx)
  (setq lst (PdfLayout_GetMarkerNameList))
  (setq idx 0)
  (while (and (< idx (length lst))
              (/= (strcase (nth idx lst)) (strcase name)))
    (setq idx (1+ idx))
  )
  (if (< idx (length lst)) idx 0)
)

(defun PdfLayout_OnAccept (/ mode filter tmpl count rule lettersStr pg gStart
                            margin overwrite lockVp mnList msg namesXlsx xNames)
  (setq mode "marker")
  (setq mnList (PdfLayout_GetMarkerNameList))
  (setq filter (nth (atoi (PdfLayout_GetTileStr "marker_name")) mnList))
  (if (not filter) (setq filter "pdf"))
  (setq tmpl (nth (atoi (get_tile "tmpl_layout"))
                  (PdfLayout_GetLayoutNames)))
  (setq count (atoi (get_tile "count")))
  (setq rule (get_tile "rule"))
  (setq lettersStr (get_tile "letters"))
  (setq pg (atoi (get_tile "per_group")))
  (setq gStart (atoi (get_tile "g_start")))
  (setq margin (atof (get_tile "margin")))
  (setq overwrite (= (get_tile "overwrite") "1"))
  (setq lockVp (= (get_tile "lock_vp") "1"))
  (setq namesXlsx (PdfLayout_GetTileStr "names_xlsx"))
  (setq xNames nil)
  (if (and namesXlsx (/= namesXlsx ""))
    (progn
      (setq xNames (PdfLayout_GetXlsxSheetNames namesXlsx))
      (if (not xNames)
        (alert "无法读取Excel分表名，请确认文件存在且未被占用。")
        (setq count (length xNames))
      )
    )
  )

  (if (not (PdfLayout_GetLayoutObj tmpl))
    (alert "请选择模板布局（当前图纸需至少有一个布局）")
    (progn
      (setq msg (PdfLayout_ValidateRule rule lettersStr))
      (if msg
        (alert msg)
        (if (and namesXlsx (/= namesXlsx "") (not xNames))
          nil
          (progn
            (setq *PdfLayout_Params*
              (list
                (cons "Mode"           mode)
                (cons "Filter"         filter)
                (cons "AutoArrange"    T)
                (cons "DlgSel"         nil)
                (cons "PdfFile"        "")
                (cons "TemplateLayout" tmpl)
                (cons "Count"          count)
                (cons "Rule"           rule)
                (cons "Letters"        lettersStr)
                (cons "PerGroup"       pg)
                (cons "GroupStart"     gStart)
                (cons "Margin"         margin)
                (cons "Overwrite"      overwrite)
                (cons "LockViewport"   lockVp)
                (cons "NamesList"      xNames)
              )
            )
            (done_dialog 1)
          )
        )
      )
    )
  )
)

(defun c:pdflayout (/ dcl_id dclPath result)
  (vl-load-com)
  (setq dclPath (PdfLayout_FindDcl))
  (if (not dclPath)
    (progn
      (alert "未找到 PdfLayout.dcl 文件，请把 PdfLayout.dcl 与插件放在同一目录后重试。")
    )
    (progn
      (setq dcl_id (load_dialog dclPath))
      (if (minusp dcl_id)
        (progn
          (alert "加载 PdfLayout.dcl 失败，请确认文件完整后重试。")
        )
        (progn
          (if (not (new_dialog "PdfLayout" dcl_id))
            (progn
              (unload_dialog dcl_id)
              (alert "启动对话框失败，请重新运行 PDFLAYOUT。")
            )
            (progn
              (PdfLayout_LoadSettings)
              (PdfLayout_InitDialog)
              (action_tile "rule"      "(PdfLayout_UpdatePreview)")
              (action_tile "letters"   "(PdfLayout_UpdatePreview)")
              (action_tile "per_group" "(PdfLayout_UpdatePreview)")
              (action_tile "g_start"   "(PdfLayout_UpdatePreview)")
              (action_tile "count"     "(PdfLayout_UpdatePreview)")
              (action_tile "marker_name" "(PdfLayout_UpdateFoundInfo)")
              (action_tile "btn_names_xlsx" "(PdfLayout_PickNamesXlsx)")
              (action_tile "btn_arrange"
                "(setq *PdfLayout_ArrangeOnly* T)
                 (setq *PdfLayout_ArrangeOnlyName*
                   (nth (atoi (get_tile \"marker_name\")) (PdfLayout_GetMarkerNameList)))
                 (done_dialog 2)")
              (action_tile "accept"    "(PdfLayout_OnAccept)")
              (action_tile "cancel"    "(done_dialog 0)")
              (setq result (start_dialog))
              (unload_dialog dcl_id)
              (if (= result 1)
                (PdfLayout_Execute)
                (if (= result 2)
                  (PdfLayout_DoArrangeOnly)
                )
              )
            )
          )
        )
      )
    )
  )
  (princ)
)

(defun PdfLayout_DoArrangeOnly (/ mn markers undoOn)
  ;; 只做自动排序：把模型空间里已导入的 PDF 底图按 行内左→右、行间上→下
  ;; 排到竖线标记上（不创建布局）；用于手动 PDFATTACH 导入后的排序
  (vl-load-com)
  (setq mn (if *PdfLayout_ArrangeOnlyName* *PdfLayout_ArrangeOnlyName* "pdf"))
  (setq markers (PdfLayout_ScanMarkers mn))
  (if (not markers)
    (alert (strcat "未识别到竖线标记“" mn "”，请检查竖线块名"))
    (progn
      (setq undoOn (= (logand (getvar "UNDOCTL") 1) 1))
      (if undoOn (command "._UNDO" "_BE"))
      (PdfLayout_ArrangePagesToMarkers markers)
      (if undoOn (command "._UNDO" "_E"))
    )
  )
  (setq *PdfLayout_ArrangeOnly* nil)
  (setq *PdfLayout_ArrangeOnlyName* nil)
  (princ)
)

;;;-------------------------------------------------------------
;;; 自检命令：PDFLAYOUTTEST（验证命名规则引擎，无需图纸）
;;;-------------------------------------------------------------
;;;-------------------------------------------------------------
;;; 多行文字按顺序命名
;;;-------------------------------------------------------------
(defun PdfLayout_SelectMTexts (/ ss i ename obj lst)
  (princ "\n请框选要命名的多行文字区域（可输入 ALL 全选），然后回车（Esc取消）: ")
  (setq ss (ssget))
  (if (not ss)
    nil
    (progn
      (setq lst nil i 0)
      (repeat (sslength ss)
        (setq ename (ssname ss i))
        (setq obj (vlax-ename->vla-object ename))
        (if (= (vla-get-ObjectName obj) "AcDbMText")
          (setq lst (append lst (list obj)))
        )
        (setq i (1+ i))
      )
      lst
    )
  )
)

(defun PdfLayout_MTextStableCenter (o / pt rot bb c dx dy)
  (setq bb (PdfLayout_GetExtentsSafeObj o))
  (if bb
    (progn
      (setq pt (vl-catch-all-apply 'vla-get-InsertionPoint (list o)))
      (if (and (not (vl-catch-all-error-p pt)) pt)
        (progn
          (setq pt (vl-catch-all-apply 'vlax-safearray->list
                     (list (vlax-variant-value pt))))
          (if (and pt (not (vl-catch-all-error-p pt)))
            (progn
              (setq rot (vl-catch-all-apply 'vla-get-Rotation (list o)))
              (if (vl-catch-all-error-p rot) (setq rot 0.0))
              (setq c (PdfLayout_BBoxCenter bb))
              (setq dx (- (car c) (car pt)))
              (setq dy (- (cadr c) (cadr pt)))
              (list (+ (car pt) (+ (* dx (cos rot)) (* dy (sin rot))))
                    (+ (cadr pt) (- (* dy (cos rot)) (* dx (sin rot))))
                    0.0)
            )
            (PdfLayout_BBoxCenter bb)
          )
        )
        (PdfLayout_BBoxCenter bb)
      )
    )
    nil
  )
)

(defun PdfLayout_PairBBoxes (objs / out bbox pt)
  (setq out nil)
  (foreach o objs
    (setq bbox nil)
    (if (= (vla-get-ObjectName o) "AcDbMText")
      (progn
        (setq pt (PdfLayout_MTextStableCenter o))
        (if pt
          (setq bbox (list pt pt))
        )
      )
      (setq bbox (PdfLayout_GetExtentsSafeObj o))
    )
    (if bbox
      (setq out (append out (list (cons o bbox))))
    )
  )
  out
)

(defun PdfLayout_NameAtPrefix (prefix num digits / s)
  (setq s (itoa num))
  (if (> digits (strlen s))
    (repeat (- digits (strlen s))
      (setq s (strcat "0" s))
    )
  )
  (strcat prefix s)
)

(defun PdfLayout_ReadNameFile (path / f line names comma first)
  (setq names nil)
  (setq f (open path "r"))
  (if f
    (progn
      (setq first T)
      (while (setq line (read-line f))
        (if first
          (progn
            (if (and (>= (strlen line) 3)
                     (= (ascii (substr line 1 1)) 239))
              (setq line (substr line 4))
            )
            (setq first nil)
          )
        )
        (setq line (vl-string-trim " " line))
        (if (/= line "")
          (progn
            (setq comma (vl-string-search "," line))
            (if comma
              (setq line (vl-string-trim " \"" (substr line 1 comma)))
            )
            (setq line (vl-string-trim " \"" line))
            (if (/= line "")
              (setq names (append names (list line)))
            )
          )
        )
      )
      (close f)
    )
  )
  names
)

(defun PdfLayout_NumKey (s / out i c)
  (setq out "" i 1)
  (while (<= i (strlen s))
    (setq c (substr s i 1))
    (if (and (>= c "0") (<= c "9"))
      (setq out (strcat out c))
    )
    (setq i (1+ i))
  )
  (if (= out "") 0 (atoi out))
)

(defun PdfLayout_JoinLabels (lca lcb / out)
  (setq out "")
  (if (/= lca "") (setq out lca))
  (if (/= lcb "")
    (setq out (if (= out "") lcb (strcat out "/" lcb)))
  )
  out
)

(defun PdfLayout_ReadLbdFile (path / f line first fields comma lbd lca lcb idx rows isFirst)
  (setq rows nil idx 0 isFirst T)
  (setq f (open path "r"))
  (if f
    (progn
      (while (setq line (read-line f))
        (if isFirst
          (progn
            (if (and (>= (strlen line) 3)
                     (= (ascii (substr line 1 1)) 239))
              (setq line (substr line 4))
            )
            (setq isFirst nil)
          )
        )
        (setq line (vl-string-trim " \t" line))
        (if (/= line "")
          (progn
            (setq fields nil)
            (while (/= line "")
              (setq comma (vl-string-search "," line))
              (if comma
                (progn
                  (setq fields (append fields (list (vl-string-trim " \"" (substr line 1 comma)))))
                  (setq line (substr line (+ comma 2)))
                )
                (progn
                  (setq fields (append fields (list (vl-string-trim " \"" line))))
                  (setq line "")
                )
              )
            )
            (setq lbd (nth 0 fields) lca (nth 1 fields) lcb (nth 2 fields))
            ;; 第一行若无数字（如表头“LBD编号”），视为表头跳过
            (if (and lbd (/= lbd "")
                     (not (and (= idx 0) (= (PdfLayout_NumKey lbd) 0))))
              (setq rows (append rows (list (list idx (if lbd lbd "") (if lca lca "") (if lcb lcb "")))))
            )
            (setq idx (1+ idx))
          )
        )
      )
      (close f)
    )
  )
  ;; 按 LBD 编号排序（提取数字），编号相同按文件顺序
  (PdfLayout_StableSort rows 'PdfLayout_CmpLbd)
)

(defun PdfLayout_ReadLbdXlsx (path layoutName / xl wbs wb shs sh ur vals arr rows r)
  (setq rows nil)
  (setq xl (vl-catch-all-apply 'vlax-create-object (list "Excel.Application")))
  (if (and xl (not (vl-catch-all-error-p xl)))
    (progn
      (vl-catch-all-apply 'vlax-put-property (list xl 'Visible 0))
      (vl-catch-all-apply 'vlax-put-property (list xl 'DisplayAlerts 0))
      (setq wbs (vl-catch-all-apply 'vlax-get-property (list xl 'Workbooks)))
      (setq wb (vl-catch-all-apply 'vlax-invoke-method (list wbs 'Open path 0 1)))
      (if (and wb (not (vl-catch-all-error-p wb)))
        (progn
          (setq shs (vl-catch-all-apply 'vlax-get-property (list wb 'Sheets)))
          (setq sh nil)
          (if (and shs (not (vl-catch-all-error-p shs)))
            (vlax-for s shs
              (if (= (strcase (vlax-get-property s 'Name)) (strcase layoutName))
                (setq sh s)
              )
            )
          )
          (if sh
            (progn
              (setq ur (vlax-get-property sh 'UsedRange))
              (setq vals (vlax-get-property ur 'Value))
              (setq arr (vlax-variant-value vals))
              (setq rows (vlax-safearray->list arr))
              (setq rows (mapcar '(lambda (r) (mapcar 'PdfLayout_CellStr r)) rows))
            )
            (alert (strcat "标签文件中未找到与当前布局同名的分表：\n" layoutName))
          )
          (vl-catch-all-apply 'vlax-invoke-method (list wb 'Close 0))
        )
        (alert (strcat "无法打开 Excel 文件（请确认文件未被独占占用）：\n" path))
      )
      (vl-catch-all-apply 'vlax-invoke-method (list xl 'Quit))
    )
    (alert "无法启动 Excel，请确认本机已安装 Office/Excel。")
  )
  rows
)

(defun PdfLayout_CommonPrefix (names / p i c ok)
  (setq p "" i 1 ok T)
  (if names
    (progn
      (while (and ok (<= i (strlen (car names))))
        (setq c (substr (car names) i 1))
        (setq ok T)
        (foreach n names
          (if (or (< (strlen n) i) (/= (substr n i 1) c))
            (setq ok nil)
          )
        )
        (if ok (setq p (strcat p c)))
        (setq i (1+ i))
      )
    )
  )
  p
)

(defun PdfLayout_CharKind (c / n)
  (setq n (ascii c))
  (cond
    ((and (>= n 48) (<= n 57)) "D")
    ((or (and (>= n 65) (<= n 90)) (and (>= n 97) (<= n 122))) "L")
    (t "O")
  )
)

(defun PdfLayout_RunShape (s / out i c kind)
  ;; 把字符串按 数字/字母/其他 切成连续段，返回 ((类型 文本) ...)
  (setq out nil i 1)
  (while (<= i (strlen s))
    (setq c (substr s i 1))
    (setq kind (PdfLayout_CharKind c))
    (if (and out (= (caar out) kind))
      (setq out (cons (list kind (strcat (cadar out) c)) (cdr out)))
      (setq out (cons (list kind c) out))
    )
    (setq i (1+ i))
  )
  (reverse out)
)

(defun PdfLayout_StrMember (s lst)
  (vl-some '(lambda (x) (= (strcase x) (strcase s))) lst)
)

(defun PdfLayout_DetectRuleFromNames (names / prefix rems shapes tpl same r kind txt
                                      rule letters seenL digitRun counts j lastD
                                      base cnt maxC gStart fv gen)
  ;; 从一组名称自动识别命名规律，返回 (规则 字母列表 每组张数 编号起始) 或 nil
  (setq names (vl-remove-if '(lambda (s) (or (null s) (= s ""))) names))
  (if (< (length names) 2)
    nil
    (progn
      (setq prefix (PdfLayout_CommonPrefix names))
      ;; 前缀末尾的数字属于变化的编号，去掉，避免吃掉编号
      (while (and (> (strlen prefix) 0)
                  (= (PdfLayout_CharKind (substr prefix (strlen prefix))) "D"))
        (setq prefix (substr prefix 1 (1- (strlen prefix))))
      )
      (setq rems (mapcar '(lambda (n) (substr n (1+ (strlen prefix)))) names))
      (setq shapes (mapcar 'PdfLayout_RunShape rems))
      (setq tpl (car shapes) same T)
      (foreach sh (cdr shapes)
        (if (or (/= (length sh) (length tpl))
                (not (apply 'and (mapcar '(lambda (a b)
                                            (and (= (car a) (car b))
                                                 (= (strlen (cadr a)) (strlen (cadr b)))))
                                          sh tpl))))
          (setq same nil)
        )
      )
      (if (not same)
        nil
        (progn
          ;; 字母列表：从所有名称中收集字母段，不只看第一个名称
          (setq letters "" seenL nil)
          (foreach n names
            (foreach r (PdfLayout_RunShape (substr n (1+ (strlen prefix))))
              (if (and (= (car r) "L") (not (member (cadr r) seenL)))
                (setq seenL (append seenL (list (cadr r))))
              )
            )
          )
          (if seenL (setq letters (apply 'strcat seenL)))
          (setq rule prefix digitRun 0)
          (foreach r tpl
            (setq kind (car r) txt (cadr r))
            (cond
              ((= kind "D")
                (setq digitRun (1+ digitRun))
                (if (= digitRun 1)
                  (setq rule (strcat rule "{G" (itoa (strlen txt)) "}"))
                  (setq rule (strcat rule "{N" (itoa (strlen txt)) "}"))
                )
              )
              ((= kind "L")
                (setq rule (strcat rule "{L}"))
              )
              (t
                (setq rule (strcat rule txt))
              )
            )
          )
          (if seenL (setq letters (apply 'strcat seenL)))
          ;; 每组张数：按“除最后一个数字段外的基准”分组，取最大组数
          (setq counts nil)
          (foreach n names
            (setq sh (PdfLayout_RunShape (substr n (1+ (strlen prefix)))))
            (setq lastD -1 j 0)
            (foreach r sh
              (if (= (car r) "D") (setq lastD j))
              (setq j (1+ j))
            )
            (setq base "")
            (setq j 0)
            (foreach r sh
              (if (/= j lastD) (setq base (strcat base (cadr r))))
              (setq j (1+ j))
            )
            (setq base (strcat prefix base))
            (setq cnt (if (assoc base counts) (cdr (assoc base counts)) 0))
            (setq counts (subst (cons base (1+ cnt)) (assoc base counts) counts))
          )
          (setq maxC 1)
          (foreach c counts
            (if (> (cdr c) maxC) (setq maxC (cdr c)))
          )
          (setq perGroup maxC)
          ;; 编号起始：第一个数字段的最小值
          (setq gStart nil)
          (foreach n names
            (setq sh (PdfLayout_RunShape (substr n (1+ (strlen prefix)))))
            (setq fv nil)
            (foreach r sh
              (if (and (null fv) (= (car r) "D"))
                (setq fv (atoi (cadr r)))
              )
            )
            (if (and fv (or (null gStart) (< fv gStart)))
              (setq gStart fv)
            )
          )
          (if (null gStart) (setq gStart 1))
          ;; 验证：用识别出的规则重新生成，与原名一致才算识别成功
          (setq gen (PdfLayout_GenNames rule letters perGroup gStart (length names)))
          (if (and gen (= (length gen) (length names))
                   (not (vl-some '(lambda (x) (not (PdfLayout_StrMember x names))) gen))
                   (not (vl-some '(lambda (x) (not (PdfLayout_StrMember x gen))) names)))
            (list rule letters perGroup gStart)
            nil
          )
        )
      )
    )
  )
)
(defun PdfLayout_GetXlsxSheetNames (path / xl wbs wb shs names i sh)
  ;; 读取 Excel 工作簿的所有分表名（按表顺序），用于“布局名来自Excel分表”
  (setq names nil)
  (setq xl (vl-catch-all-apply 'vlax-create-object (list "Excel.Application")))
  (if (and xl (not (vl-catch-all-error-p xl)))
    (progn
      (vl-catch-all-apply 'vlax-put-property (list xl 'Visible 0))
      (vl-catch-all-apply 'vlax-put-property (list xl 'DisplayAlerts 0))
      (setq wbs (vl-catch-all-apply 'vlax-get-property (list xl 'Workbooks)))
      (setq wb (vl-catch-all-apply 'vlax-invoke-method (list wbs 'Open path 0 1)))
      (if (and wb (not (vl-catch-all-error-p wb)))
        (progn
          (setq shs (vl-catch-all-apply 'vlax-get-property (list wb 'Sheets)))
          (if (and shs (not (vl-catch-all-error-p shs)))
            (progn
              (setq i 1)
              (while (<= i (vlax-get-property shs 'Count))
                (setq sh (vl-catch-all-apply 'vlax-get-property (list shs 'Item i)))
                (if (not (vl-catch-all-error-p sh))
                  (setq names (append names (list (vlax-get-property sh 'Name))))
                )
                (setq i (1+ i))
              )
            )
          )
          (vl-catch-all-apply 'vlax-invoke-method (list wb 'Close 0))
        )
      )
      (vl-catch-all-apply 'vlax-invoke-method (list xl 'Quit))
    )
  )
  names
)

(defun PdfLayout_CellStr (v / s)
  (if (null v)
    ""
    (progn
      ;; ZWCAD 的单元格值是 VARIANT，先解包成普通值再转字符串
      (setq s (vl-catch-all-apply 'vlax-variant-value (list v)))
      (if (not (vl-catch-all-error-p s))
        (setq v s)
      )
      (if (null v)
        ""
        (progn
          (setq s (vl-catch-all-apply 'vl-princ-to-string (list v)))
          (if (vl-catch-all-error-p s) "" s)
        )
      )
    )
  )
)

(defun PdfLayout_GroupLbdRows (rows / out cur lbd lab idx)
  (setq out nil cur nil idx 0)
  (foreach r rows
    (setq lbd (nth 0 r) lab (nth 2 r))
    (if (and lbd (vl-string-search "LBD" (strcase lbd)) (> (PdfLayout_NumKey lbd) 0))
      (if (and cur (= (strcase (nth 1 cur)) (strcase lbd)))
        (if (and lab (/= lab ""))
          (setq cur (append cur (list lab)))
        )
        (progn
          (if cur (setq out (append out (list cur))))
          (setq cur (list idx lbd))
          (setq idx (1+ idx))
          (if (and lab (/= lab ""))
            (setq cur (append cur (list lab)))
          )
        )
      )
      (if (and cur lab (/= lab ""))
        (setq cur (append cur (list lab)))
      )
    )
  )
  (if cur (setq out (append out (list cur))))
  ;; 按 LBD 编号排序（提取数字），编号相同按原顺序
  (PdfLayout_StableSort out 'PdfLayout_CmpLbd)
)

(defun PdfLayout_JoinLabelsList (labels / out)
  (setq out "")
  (foreach s labels
    (if (and s (/= s ""))
      (setq out (if (= out "") s (strcat out "/" s)))
    )
  )
  out
)

(defun PdfLayout_ReadLbdNames (path / ext rows layoutName)
  (setq ext (strcase (vl-filename-extension path)))
  (setq rows nil)
  (if (or (= ext ".XLSX") (= ext ".XLS"))
    (progn
      (setq layoutName (vla-get-Name (vla-get-ActiveLayout
                                       (vla-get-ActiveDocument
                                         (vlax-get-Acad-Object)))))
      (setq rows (PdfLayout_ReadLbdXlsx path layoutName))
      (setq rows (PdfLayout_GroupLbdRows rows))
    )
    (setq rows (PdfLayout_ReadLbdFile path))
  )
  (setq *PdfLayout_LbdRows* rows)
  (setq *PdfLayout_PreviewLbds* (mapcar '(lambda (r) (nth 1 r)) rows))
  (setq *PdfLayout_PreviewNames* (mapcar '(lambda (r) (PdfLayout_JoinLabelsList (cddr r))) rows))
  (if (not rows)
    (alert (strcat "无法读取标签文件或文件为空：\n" path))
  )
)

(defun PdfLayout_SortPairsByOrder (pairs order)
  (cond
    ((= order "1") (PdfLayout_SortByPositionLR pairs))
    ((= order "2") (PdfLayout_SortByPosition pairs))
    ((= order "3") (PdfLayout_SortByPositionRL pairs))
    ((= order "4") (PdfLayout_SortByPositionBT pairs))
    ((= order "5") (PdfLayout_SortByPositionLRBT pairs))
    ((= order "6") (PdfLayout_SortByPositionRLBT pairs))
    ((= order "7") (PdfLayout_SortByPositionTBR pairs))
    ((= order "8") (PdfLayout_SortByPositionBTR pairs))
    (t pairs)
  )
)

(defun PdfLayout_BuildSchemeGrid (pairs order / sorted idxMap i p ys ymax ymin
                                  tol byY cur curY rows item rowX line out idx
                                  rowY)
  (while (> (length pairs) 200)
    (setq pairs (reverse (cdr (reverse pairs))))
  )
  (setq sorted (PdfLayout_SortPairsByOrder pairs order))
  (setq idxMap nil i 1)
  (foreach p sorted
    (setq idxMap (cons (cons p i) idxMap))
    (setq i (1+ i))
  )
  (setq ys (mapcar '(lambda (q) (cadr (PdfLayout_BBoxCenter (cdr q)))) pairs))
  (setq ymax (apply 'max ys) ymin (apply 'min ys))
  (setq tol (* 0.05 (max 1.0 (- ymax ymin))))
  (setq byY (PdfLayout_StableSort
              (mapcar '(lambda (q) (cons (cadr (PdfLayout_BBoxCenter (cdr q))) q)) pairs)
              'PdfLayout_CmpYGreater))
  (setq rows nil cur nil curY nil)
  (foreach item byY
    (if (and curY (> (- curY (car item)) tol))
      (progn
        (setq rows (append rows (list cur)))
        (setq cur nil)
      )
    )
    (setq cur (append cur (list (cdr item))))
    (setq curY (car item))
  )
  (if cur (setq rows (append rows (list cur))))
  ;; 行按最高点 Y 从大到小排序（上到下），保证显示顺序稳定
  (setq rows (PdfLayout_StableSort rows 'PdfLayout_CmpRowTop))
  ;; 示意图固定按物理位置从上到下显示，数字表示第几个被命名
  (setq out nil)
  (foreach row rows
    (setq rowX
      (PdfLayout_StableSort row
        (if (member order '("1" "2" "4" "5"))
          'PdfLayout_CmpXAsc
          'PdfLayout_CmpXDesc
        )
      )
    )
    (setq line "")
    (foreach q rowX
      (setq idx (cdr (assoc q idxMap)))
      (if (= line "")
        (setq line (itoa idx))
        (setq line (strcat line "  " (if (< idx 10) (strcat " " (itoa idx)) (itoa idx))))
      )
    )
    (setq out (append out (list line)))
  )
  out
)

(defun PdfLayout_RenamePreviewEnableTiles (/ fileMode)
(setq fileMode (= *PdfLayout_PreviewSrc* "3"))
  (mode_tile "prefix" (if fileMode 1 0))
  (mode_tile "start" (if fileMode 1 0))
  (mode_tile "digits" (if fileMode 1 0))
  (mode_tile "file_path" (if fileMode 0 1))
  (mode_tile "btn_file" (if fileMode 0 1))
  (mode_tile "bg_color" (if (= *PdfLayout_PreviewBgMode* "1") 0 1))
  (mode_tile "bg_scale" (if (= *PdfLayout_PreviewBgMode* "1") 0 1))
)

(defun PdfLayout_RenamePreviewFillProfiles (/ items i)
  (setq items (list "默认(当前记忆)"))
  (foreach pf *PdfLayout_Profiles*
    (if (eq (type (car pf)) 'STR)
      (setq items (append items (list (car pf))))
    )
  )
  (PdfLayout_SetList "prof_list" items)
  (setq i 0)
  (foreach pf *PdfLayout_Profiles*
    (setq i (1+ i))
    (if (= (strcase (car pf)) (strcase *PdfLayout_CurrentProfile*))
      (set_tile "prof_list" (itoa i))
    )
  )
  (set_tile "prof_name" (if (eq (type *PdfLayout_CurrentProfile*) 'STR)
                          *PdfLayout_CurrentProfile* ""))
)

(defun PdfLayout_RenamePreviewSelectProfile (idx / pf)
  (if (> idx 0)
    (progn
      (setq pf (if *PdfLayout_Profiles* (nth (1- idx) *PdfLayout_Profiles*) nil))
      (if pf
        (progn
          (PdfLayout_ApplyProfile (cdr pf))
          (setq *PdfLayout_CurrentProfile* (car pf))
          (PdfLayout_RenamePreviewInit)
          (PdfLayout_RenamePreviewUpdate)
        )
      )
    )
  )
)

(defun PdfLayout_RenamePreviewSaveProfile (/ name)
  (setq name (PdfLayout_GetTileStr "prof_name"))
  (if (= name "")
    (alert "请先输入方案名。")
    (progn
      (PdfLayout_SaveProfile name)
      (PdfLayout_RenamePreviewFillProfiles)
      (princ (strcat "\n方案已保存: " name))
    )
  )
)

(defun PdfLayout_RenamePreviewDeleteProfile (/ idx sel name)
  (setq idx (PdfLayout_GetTileInt "prof_list" -1))
  (if (> idx 0)
    (progn
      (setq sel (if *PdfLayout_Profiles* (nth (1- idx) *PdfLayout_Profiles*) nil))
      (if sel
        (progn
          (setq name (car sel))
          (setq *PdfLayout_Profiles*
            (vl-remove-if
              '(lambda (x) (= (strcase (car x)) (strcase name)))
              *PdfLayout_Profiles*))
          (if (= (strcase *PdfLayout_CurrentProfile*) (strcase name))
            (setq *PdfLayout_CurrentProfile* "")
          )
          (PdfLayout_SaveSettings)
          (PdfLayout_RenamePreviewFillProfiles)
          (set_tile "prof_list" "0")
          (set_tile "prof_name" "")
          (princ (strcat "\n方案已删除: " name))
        )
        (alert "请先在方案列表中选择要删除的方案。")
      )
    )
    (alert "请先在方案列表中选择要删除的方案。")
  )
)
(defun PdfLayout_SetList (key items / s)
  (start_list key)
  (foreach s items
    (if (eq (type s) 'STR)
      (add_list s)
    )
  )
  (end_list)
)

(defun PdfLayout_GetTileStr (key / v)
  (setq v (get_tile key))
  (if (eq (type v) 'STR) v "")
)

(defun PdfLayout_GetTileInt (key dflt / v)
  (setq v (PdfLayout_GetTileStr key))
  (if (= v "") dflt (atoi v))
)

(defun PdfLayout_GetTileReal (key dflt / v)
  (setq v (PdfLayout_GetTileStr key))
  (if (= v "") dflt (atof v))
)

(defun PdfLayout_RenamePreviewUpdate (/ gridLines nameLines i p name sortedPairs)
  (PdfLayout_RenamePreviewEnableTiles)
  (setq gridLines (vl-catch-all-apply 'PdfLayout_BuildSchemeGrid
                    (list *PdfLayout_PreviewPairs* *PdfLayout_PreviewOrder*)))
  (if (vl-catch-all-error-p gridLines)
    (setq gridLines (list "（无法生成示意图）"))
  )
  (PdfLayout_SetList "scheme_grid" gridLines)
  (setq nameLines nil i 0)
  (setq sortedPairs (if (= *PdfLayout_PreviewSrc* "3")
                      (PdfLayout_SortPairsSmart *PdfLayout_PreviewPairs* *PdfLayout_PreviewOrder*)
                      (PdfLayout_SortPairsByOrder *PdfLayout_PreviewPairs* *PdfLayout_PreviewOrder*)))
  (foreach p sortedPairs
    (if (< i 30)
      (progn
        (setq name (if *PdfLayout_PreviewNames*
                      (nth i *PdfLayout_PreviewNames*)
                      (PdfLayout_NameAtPrefix *PdfLayout_PreviewPrefix*
                                              (+ *PdfLayout_PreviewStart* i)
                                              *PdfLayout_PreviewDigits*)))
        (if (= *PdfLayout_PreviewSrc* "3")
          (if (and *PdfLayout_PreviewLbds* (nth i *PdfLayout_PreviewLbds*))
            (setq name (strcat (nth i *PdfLayout_PreviewLbds*) "  " name))
          )
        )
        (setq nameLines (append nameLines (list (strcat (itoa (1+ i)) ": " name))))
      )
    )
    (setq i (1+ i))
  )
  (PdfLayout_SetList "name_list" nameLines)
  (set_tile "info_text"
    (strcat "共 " (itoa (length *PdfLayout_PreviewPairs*)) " 个多行文字"
            (if (= *PdfLayout_PreviewSrc* "2")
              (if *PdfLayout_PreviewNames*
                (strcat "，名称来自文件 " (itoa (length *PdfLayout_PreviewNames*)) " 个")
                "，请选择名称文件")
              (if (= *PdfLayout_PreviewSrc* "3")
                (if *PdfLayout_PreviewNames*
                  (strcat "，LBD标签 " (itoa (length *PdfLayout_PreviewNames*))
                          " 行（已按编号排序，按 文字/标签 较少者执行）")
                  "，请选择LBD标签文件")
                ""))))
)

(defun PdfLayout_RenamePreviewReadFile (/ fpath)
  (setq fpath (PdfLayout_GetTileStr "file_path"))
  (if (/= fpath "")
    (progn
      (setq *PdfLayout_PreviewFilePath* fpath)
      (if (= *PdfLayout_PreviewSrc* "3")
        (PdfLayout_ReadLbdNames fpath)
        (progn
          (setq *PdfLayout_PreviewNames* (PdfLayout_ReadNameFile fpath))
          (if (not *PdfLayout_PreviewNames*)
            (alert (strcat "无法读取文件或文件为空：\n" fpath))
          )
        )
      )
    )
  )
  (PdfLayout_RenamePreviewUpdate)
)

(defun PdfLayout_RenamePreviewPickFile (/ fpath)
  (setq fpath (getfiled "选择标签文件(Excel/CSV)" "" "xlsx;xls;csv;txt" 4))
  (if fpath
    (progn
      (setq *PdfLayout_PreviewFilePath* fpath)
      (set_tile "file_path" fpath)
      (if (= *PdfLayout_PreviewSrc* "3")
        (PdfLayout_ReadLbdNames fpath)
        (progn
          (setq *PdfLayout_PreviewNames* (PdfLayout_ReadNameFile fpath))
          (if (not *PdfLayout_PreviewNames*)
            (alert (strcat "无法读取文件或文件为空：\n" fpath))
          )
        )
      )
    )
  )
  (PdfLayout_RenamePreviewUpdate)
)

(defun PdfLayout_RenamePreviewAccept ()
  (if (= (PdfLayout_GetTileStr "bgon") "1")
    (setq *PdfLayout_PreviewBgMode* "1")
    (if (= (PdfLayout_GetTileStr "bgoff") "1")
      (setq *PdfLayout_PreviewBgMode* "2")
      (setq *PdfLayout_PreviewBgMode* "0")
    )
  )
  (setq *PdfLayout_PreviewBgColor* (PdfLayout_GetTileInt "bg_color" 7))
  (if (or (< *PdfLayout_PreviewBgColor* 1) (> *PdfLayout_PreviewBgColor* 255))
    (setq *PdfLayout_PreviewBgColor* 7)
  )
  (setq *PdfLayout_PreviewBgScale* (PdfLayout_GetTileReal "bg_scale" 1.5))
  (if (< *PdfLayout_PreviewBgScale* 1)
    (setq *PdfLayout_PreviewBgScale* 1.5)
  )
  (setq *PdfLayout_RowTol* (max 1 (min 50 (PdfLayout_GetTileInt "row_tol" 10))))
  (if (= *PdfLayout_PreviewSrc* "3")
    (if (not *PdfLayout_PreviewNames*)
      (alert (if (= *PdfLayout_PreviewSrc* "3")
               "请先选择并读取 LBD 标签文件。"
               "请先选择并读取 CSV 名称文件。"))
      (progn
        (PdfLayout_SaveSettings)
        (setq *PdfLayout_PreviewResult* 1)
        (done_dialog 1)
      )
    )
    (progn
      (if (or (not *PdfLayout_PreviewPrefix*) (= *PdfLayout_PreviewPrefix* ""))
        (setq *PdfLayout_PreviewPrefix* "STR")
      )
      (if (or (not *PdfLayout_PreviewStart*) (< *PdfLayout_PreviewStart* 1))
        (setq *PdfLayout_PreviewStart* 1)
      )
      (if (or (not *PdfLayout_PreviewDigits*) (< *PdfLayout_PreviewDigits* 0))
        (setq *PdfLayout_PreviewDigits* 2)
      )
      (PdfLayout_SaveSettings)
      (setq *PdfLayout_PreviewResult* 1)
      (done_dialog 1)
    )
  )
)

(defun PdfLayout_RenamePreviewInit ()
  (if (member *PdfLayout_PreviewOrder* '("1" "2" "3" "4" "5" "6" "7" "8"))
    (set_tile (strcat "ord" *PdfLayout_PreviewOrder*) "1")
  )
  (set_tile (if (= *PdfLayout_PreviewSrc* "3") "srcfile2" "srcauto") "1")
  (set_tile "prefix" (if *PdfLayout_PreviewPrefix* *PdfLayout_PreviewPrefix* "STR"))
  (set_tile "start" (itoa (if *PdfLayout_PreviewStart* *PdfLayout_PreviewStart* 1)))
  (set_tile "digits" (itoa (if *PdfLayout_PreviewDigits* *PdfLayout_PreviewDigits* 2)))
  (if (and *PdfLayout_PreviewFilePath* (/= *PdfLayout_PreviewFilePath* ""))
    (set_tile "file_path" *PdfLayout_PreviewFilePath*)
  )
  (set_tile (if (= *PdfLayout_PreviewBgMode* "0") "bgkeep"
              (if (= *PdfLayout_PreviewBgMode* "2") "bgoff" "bgon")) "1")
  (set_tile "bg_color" (itoa *PdfLayout_PreviewBgColor*))
  (set_tile "bg_scale" (rtos *PdfLayout_PreviewBgScale* 2 2))
  (set_tile "row_tol" (itoa *PdfLayout_RowTol*))
  (PdfLayout_RenamePreviewFillProfiles)
)

(defun PdfLayout_ShowRenamePreview (/ dclPath dclId result nd pfCur)
  (setq dclPath (PdfLayout_FindDcl))
  (princ "\n[调试] 打开方案弹窗")
  (if (not dclPath)
    (progn
      (princ "\n[调试] 未找到 PdfLayout.dcl（请把 dcl 与 lsp 放同一目录）")
      "0"
    )
    (progn
      (setq dclId (load_dialog dclPath))
      (if (< dclId 0)
        (progn
          (princ "\n[调试] DCL 文件加载失败")
          "0"
        )
        (progn
          (setq nd (vl-catch-all-apply 'new_dialog (list "PdfRenamePreview" dclId)))
          (if (and nd (not (vl-catch-all-error-p nd)))
            (progn
              ;; 打开弹窗时仅在“方案来源与记忆来源一致”时才套用当前方案，
              ;; 避免自动命名方案把它的排序方式带进 CSV 工作流
              (if (and *PdfLayout_CurrentProfile* (/= *PdfLayout_CurrentProfile* "")
                       *PdfLayout_Profiles*)
                (progn
                  (setq pfCur nil)
                  (foreach pp *PdfLayout_Profiles*
                    (if (= (strcase (car pp)) (strcase *PdfLayout_CurrentProfile*))
                      (setq pfCur (cdr pp))
                    )
                  )
                  (if (and pfCur
                           (= (PdfLayout_OrDefault (PdfLayout_ProfileGet pfCur "Src") "1")
                              *PdfLayout_PreviewSrc*))
                    (PdfLayout_ApplyProfile pfCur)
                  )
                )
              )
              (PdfLayout_RenamePreviewInit)
              (PdfLayout_RenamePreviewUpdate)
              (action_tile "srcauto"  "(setq *PdfLayout_PreviewSrc* \"1\") (PdfLayout_RenamePreviewUpdate)")
              ;; 名称来源与排序方式互相独立：切换来源不改排序方式
              (action_tile "srcfile2" "(setq *PdfLayout_PreviewSrc* \"3\") (PdfLayout_RenamePreviewUpdate)")
              (action_tile "btn_file"  "(PdfLayout_RenamePreviewPickFile)")
              (action_tile "file_path" "(setq *PdfLayout_PreviewFilePath* (PdfLayout_GetTileStr \"file_path\")) (PdfLayout_RenamePreviewReadFile)")
              (action_tile "prefix" "(setq *PdfLayout_PreviewPrefix* (PdfLayout_GetTileStr \"prefix\")) (PdfLayout_RenamePreviewUpdate)")
              (action_tile "start"  "(setq *PdfLayout_PreviewStart* (max 1 (PdfLayout_GetTileInt \"start\" 1))) (PdfLayout_RenamePreviewUpdate)")
              (action_tile "digits" "(setq *PdfLayout_PreviewDigits* (max 0 (PdfLayout_GetTileInt \"digits\" 2))) (PdfLayout_RenamePreviewUpdate)")
              (action_tile "bgkeep" "(setq *PdfLayout_PreviewBgMode* \"0\") (PdfLayout_RenamePreviewUpdate)")
              (action_tile "bgon" "(setq *PdfLayout_PreviewBgMode* \"1\") (PdfLayout_RenamePreviewUpdate)")
              (action_tile "bgoff" "(setq *PdfLayout_PreviewBgMode* \"2\") (PdfLayout_RenamePreviewUpdate)")
              (action_tile "bg_color" "(setq *PdfLayout_PreviewBgColor* (PdfLayout_GetTileInt \"bg_color\" 7)) (PdfLayout_RenamePreviewUpdate)")
              (action_tile "bg_scale" "(setq *PdfLayout_PreviewBgScale* (PdfLayout_GetTileReal \"bg_scale\" 1.5)) (PdfLayout_RenamePreviewUpdate)")
              (action_tile "prof_list" "(PdfLayout_RenamePreviewSelectProfile (PdfLayout_GetTileInt \"prof_list\" -1))")
              (action_tile "btn_saveprof" "(PdfLayout_RenamePreviewSaveProfile)")
              (action_tile "btn_delprof" "(PdfLayout_RenamePreviewDeleteProfile)")
              (action_tile "ord1" "(setq *PdfLayout_PreviewOrder* \"1\") (PdfLayout_RenamePreviewUpdate)")
              (action_tile "ord2" "(setq *PdfLayout_PreviewOrder* \"2\") (PdfLayout_RenamePreviewUpdate)")
              (action_tile "ord3" "(setq *PdfLayout_PreviewOrder* \"3\") (PdfLayout_RenamePreviewUpdate)")
              (action_tile "ord4" "(setq *PdfLayout_PreviewOrder* \"4\") (PdfLayout_RenamePreviewUpdate)")
              (action_tile "ord5" "(setq *PdfLayout_PreviewOrder* \"5\") (PdfLayout_RenamePreviewUpdate)")
              (action_tile "ord6" "(setq *PdfLayout_PreviewOrder* \"6\") (PdfLayout_RenamePreviewUpdate)")
              (action_tile "ord7" "(setq *PdfLayout_PreviewOrder* \"7\") (PdfLayout_RenamePreviewUpdate)")
              (action_tile "ord8" "(setq *PdfLayout_PreviewOrder* \"8\") (PdfLayout_RenamePreviewUpdate)")
              (action_tile "row_tol" "(setq *PdfLayout_RowTol* (max 1 (min 50 (PdfLayout_GetTileInt \"row_tol\" 10)))) (PdfLayout_RenamePreviewUpdate)")
              (action_tile "accept" "(PdfLayout_RenamePreviewAccept)")
              (action_tile "cancel" "(setq *PdfLayout_PreviewResult* 0) (done_dialog 0)")
              (setq *PdfLayout_PreviewResult* 0)
              (setq result (start_dialog))
              (unload_dialog dclId)
              (princ (strcat "\n[调试] 方案弹窗 result=" (itoa result)
                             " 确认=" (itoa *PdfLayout_PreviewResult*)))
              (if (= *PdfLayout_PreviewResult* 1) "1" "0")
            )
            (progn
              (princ "\n[调试] 弹窗打开失败（DCL 语法或内容问题）")
              (unload_dialog dclId)
              "0"
            )
          )
        )
      )
    )
  )
)
(defun PdfLayout_SettingsPathLsp (/ dir)
  ;; LSP 目录取不到时（中望CAD），把 PdfLayout.ini 固定放在系统临时目录，
  ;; 这样换图纸、换目录后记忆和方案仍然存在
  (setq dir (if (and *PdfLayout_LspDir* (/= *PdfLayout_LspDir* ""))
              *PdfLayout_LspDir*
              (getvar "TEMPPREFIX")))
  (strcat dir "PdfLayout.ini")
)

(defun PdfLayout_LoadSettings (/ f line pos k v first)
  (princ "\n[调试] 读取记忆设置")
  (setq *PdfLayout_PreviewPrefix* "STR")
  (setq *PdfLayout_PreviewStart* 1)
  (setq *PdfLayout_PreviewDigits* 2)
  (setq *PdfLayout_PreviewOrder* "1")
  (setq *PdfLayout_PreviewSrc* "1")
  (setq *PdfLayout_PreviewFilePath* "")
  (setq *PdfLayout_PreviewBgMode* "0")
  (setq *PdfLayout_PreviewBgColor* 7)
  (setq *PdfLayout_PreviewBgScale* 1.5)
  (setq *PdfLayout_IniPairs* nil)
  (setq *PdfLayout_LbdRows* nil)
  (setq *PdfLayout_PreviewLbds* nil)
  (setq f (open (PdfLayout_SettingsPathLsp) "r"))
  (if (not f)
    (setq f (open (strcat (getvar "TEMPPREFIX") "PdfLayout.ini") "r"))
  )
  (if f
    (progn
      (setq first T)
      (while (setq line (read-line f))
        (if first
          (progn
            (if (and (>= (strlen line) 3)
                     (= (ascii (substr line 1 1)) 239))
              (setq line (substr line 4))
            )
            (setq first nil)
          )
        )
        (setq pos (vl-string-search "=" line))
        (if pos
          (progn
            (setq k (vl-string-trim " " (substr line 1 pos)))
            ;; vl-string-search 返回 0 起始下标，substr 为 1 起始，
            ;; 值从 "=" 后一个字符开始，需 +2；旧版 ini 可能残留多余 "="，一并清掉
            (setq v (vl-string-trim " " (substr line (+ pos 2))))
            (while (= (substr v 1 1) "=")
              (setq v (substr v 2))
            )
            (setq *PdfLayout_IniPairs* (cons (cons k v) *PdfLayout_IniPairs*))
            (cond
              ((= k "Prefix") (setq *PdfLayout_PreviewPrefix* v))
              ((= k "Start") (setq *PdfLayout_PreviewStart* (atoi v)))
              ((= k "Digits") (setq *PdfLayout_PreviewDigits* (atoi v)))
              ((= k "Order") (setq *PdfLayout_PreviewOrder* v))
              ((= k "Src") (setq *PdfLayout_PreviewSrc* v))
              ((= k "FilePath") (setq *PdfLayout_PreviewFilePath* v))
              ((= k "BgMode") (setq *PdfLayout_PreviewBgMode* v))
              ((= k "BgColor") (setq *PdfLayout_PreviewBgColor* (atoi v)))
              ((= k "BgScale") (setq *PdfLayout_PreviewBgScale* (atof v)))
              ((= k "RowTol") (setq *PdfLayout_RowTol* (atoi v)))
              ((= k "LayRule") (setq *PdfLayout_LayRule* v))
              ((= k "LayLetters") (setq *PdfLayout_LayLetters* v))
              ((= k "LayPerGroup") (setq *PdfLayout_LayPerGroup* (atoi v)))
              ((= k "LayGStart") (setq *PdfLayout_LayGStart* (atoi v)))
              ((= k "LayXlsx") (setq *PdfLayout_LastNamesXlsx* v))
            )
          )
        )
      )
      (close f)
    )
  )
  (setq *PdfLayout_CurrentProfile* (PdfLayout_OrDefault (PdfLayout_IniGet "LastProfile") ""))
  (PdfLayout_LoadProfiles)
  (if (or (not *PdfLayout_PreviewStart*) (< *PdfLayout_PreviewStart* 1))
    (setq *PdfLayout_PreviewStart* 1)
  )
  (if (or (not *PdfLayout_PreviewDigits*) (< *PdfLayout_PreviewDigits* 0))
    (setq *PdfLayout_PreviewDigits* 2)
  )
  (if (not (member *PdfLayout_PreviewOrder* '("1" "2" "3" "4" "5" "6" "7" "8")))
    (setq *PdfLayout_PreviewOrder* "1")
  )
  (if (not (member *PdfLayout_PreviewSrc* '("1" "3")))
    (setq *PdfLayout_PreviewSrc* "1")
  )
  (if (not (member *PdfLayout_PreviewBgMode* '("0" "1" "2")))
    (setq *PdfLayout_PreviewBgMode* "0")
  )
  (if (not *PdfLayout_PreviewFilePath*) (setq *PdfLayout_PreviewFilePath* ""))
  (if (not *PdfLayout_PreviewBgMode*) (setq *PdfLayout_PreviewBgMode* "0"))
  (if (or (not *PdfLayout_PreviewBgColor*)
          (< *PdfLayout_PreviewBgColor* 1) (> *PdfLayout_PreviewBgColor* 255))
    (setq *PdfLayout_PreviewBgColor* 7)
  )
  (if (or (not *PdfLayout_PreviewBgScale*) (< *PdfLayout_PreviewBgScale* 1))
    (setq *PdfLayout_PreviewBgScale* 1.5)
  )
  (if (or (not *PdfLayout_RowTol*) (< *PdfLayout_RowTol* 1) (> *PdfLayout_RowTol* 50))
    (setq *PdfLayout_RowTol* 10)
  )
)

(defun PdfLayout_SaveSettings (/ f i pf pfname pfdata)
  (setq f (open (PdfLayout_SettingsPathLsp) "w"))
  (if (not f)
    (setq f (open (strcat (getvar "TEMPPREFIX") "PdfLayout.ini") "w"))
  )
  (if f
    (progn
      (princ (strcat "Prefix=" *PdfLayout_PreviewPrefix*) f)
      (princ "\n" f)
      (princ (strcat "Start=" (itoa *PdfLayout_PreviewStart*)) f)
      (princ "\n" f)
      (princ (strcat "Digits=" (itoa *PdfLayout_PreviewDigits*)) f)
      (princ "\n" f)
      (princ (strcat "Order=" *PdfLayout_PreviewOrder*) f)
      (princ "\n" f)
      (princ (strcat "Src=" *PdfLayout_PreviewSrc*) f)
      (princ "\n" f)
      (if *PdfLayout_PreviewFilePath*
        (princ (strcat "FilePath=" *PdfLayout_PreviewFilePath*) f)
      )
      (princ "\n" f)
      (princ (strcat "BgMode=" *PdfLayout_PreviewBgMode*) f)
      (princ "\n" f)
      (princ (strcat "BgColor=" (itoa *PdfLayout_PreviewBgColor*)) f)
      (princ "\n" f)
      (princ (strcat "BgScale=" (rtos *PdfLayout_PreviewBgScale* 2 2)) f)
      (princ "\n" f)
      (princ (strcat "RowTol=" (itoa *PdfLayout_RowTol*)) f)
(princ (strcat "LayRule=" *PdfLayout_LayRule*) f)
(princ "\n" f)
(princ (strcat "LayLetters=" *PdfLayout_LayLetters*) f)
(princ "\n" f)
(princ (strcat "LayPerGroup=" (itoa *PdfLayout_LayPerGroup*)) f)
(princ "\n" f)
(princ (strcat "LayGStart=" (itoa *PdfLayout_LayGStart*)) f)
(princ "\n" f)
(if *PdfLayout_LastNamesXlsx*
  (princ (strcat "LayXlsx=" *PdfLayout_LastNamesXlsx*) f)
)
(princ "\n" f)
      (princ "\n" f)
      (princ (strcat "LastProfile=" *PdfLayout_CurrentProfile*) f)
      (princ "\n" f)
      (princ (strcat "ProfileCount=" (itoa (length *PdfLayout_Profiles*))) f)
      (princ "\n" f)
      (setq i 1)
      (foreach pf *PdfLayout_Profiles*
        (setq pfname (car pf))
        (setq pfdata (cdr pf))
        (princ (strcat "Profile" (itoa i) "Name=" pfname) f)
        (princ "\n" f)
        (princ (strcat "Profile" (itoa i) "Prefix=" (PdfLayout_OrDefault (PdfLayout_ProfileGet pfdata "Prefix") "")) f)
        (princ "\n" f)
        (princ (strcat "Profile" (itoa i) "Start=" (itoa (PdfLayout_OrDefault (PdfLayout_ProfileGet pfdata "Start") 1))) f)
        (princ "\n" f)
        (princ (strcat "Profile" (itoa i) "Digits=" (itoa (PdfLayout_OrDefault (PdfLayout_ProfileGet pfdata "Digits") 2))) f)
        (princ "\n" f)
        (princ (strcat "Profile" (itoa i) "Order=" (PdfLayout_OrDefault (PdfLayout_ProfileGet pfdata "Order") "1")) f)
        (princ "\n" f)
        (princ (strcat "Profile" (itoa i) "Src=" (PdfLayout_OrDefault (PdfLayout_ProfileGet pfdata "Src") "1")) f)
        (princ "\n" f)
        (princ (strcat "Profile" (itoa i) "FilePath=" (PdfLayout_OrDefault (PdfLayout_ProfileGet pfdata "FilePath") "")) f)
        (princ "\n" f)
        (princ (strcat "Profile" (itoa i) "BgMode=" (PdfLayout_OrDefault (PdfLayout_ProfileGet pfdata "BgMode") "0")) f)
        (princ "\n" f)
        (princ (strcat "Profile" (itoa i) "BgColor=" (itoa (PdfLayout_OrDefault (PdfLayout_ProfileGet pfdata "BgColor") 7))) f)
        (princ "\n" f)
        (princ (strcat "Profile" (itoa i) "BgScale=" (rtos (PdfLayout_OrDefault (PdfLayout_ProfileGet pfdata "BgScale") 1.5) 2 2)) f)
        (princ "\n" f)
        (setq i (1+ i))
      )
      (close f)
    )
  )
)
(defun PdfLayout_IniGet (key / p)
  (setq p (assoc key *PdfLayout_IniPairs*))
  (if p (cdr p) nil)
)

(defun PdfLayout_ProfileGet (prof key / p)
  (setq p (assoc key prof))
  (if p (cdr p) nil)
)

;; 中望CAD(LISPSYS=1)的 or 函数有兼容性问题：会返回 T 而不是实际值，
;; 因此不能用 (or 取值 默认值) 的写法，统一改用本函数取“非 nil 值”。
(defun PdfLayout_OrDefault (val dflt / v)
  (setq v val)
  (if (null v) (setq v dflt))
  v
)

(defun PdfLayout_ProfileSet (prof key val / p)
  (if (assoc key prof)
    (subst (cons key val) (assoc key prof) prof)
    (append prof (list (cons key val)))
  )
)

(defun PdfLayout_ApplyProfile (prof)
  (setq *PdfLayout_PreviewPrefix* (PdfLayout_OrDefault (PdfLayout_ProfileGet prof "Prefix") "STR"))
  (setq *PdfLayout_PreviewStart* (PdfLayout_OrDefault (PdfLayout_ProfileGet prof "Start") 1))
  (setq *PdfLayout_PreviewDigits* (PdfLayout_OrDefault (PdfLayout_ProfileGet prof "Digits") 2))
  (setq *PdfLayout_PreviewOrder* (PdfLayout_OrDefault (PdfLayout_ProfileGet prof "Order") "1"))
  (setq *PdfLayout_PreviewSrc* (PdfLayout_OrDefault (PdfLayout_ProfileGet prof "Src") "1"))
  (if (not (member *PdfLayout_PreviewSrc* '("1" "3")))
    (setq *PdfLayout_PreviewSrc* "1")
  )
  (setq *PdfLayout_PreviewFilePath* (PdfLayout_OrDefault (PdfLayout_ProfileGet prof "FilePath") ""))
  (setq *PdfLayout_PreviewBgMode* (PdfLayout_OrDefault (PdfLayout_ProfileGet prof "BgMode") "0"))
  (setq *PdfLayout_PreviewBgColor* (PdfLayout_OrDefault (PdfLayout_ProfileGet prof "BgColor") 7))
  (setq *PdfLayout_PreviewBgScale* (PdfLayout_OrDefault (PdfLayout_ProfileGet prof "BgScale") 1.5))
)

(defun PdfLayout_LoadProfiles (/ i cnt name prof)
  (setq *PdfLayout_Profiles* nil)
  (setq i 1)
  (setq cnt (atoi (PdfLayout_OrDefault (PdfLayout_IniGet "ProfileCount") "0")))
  (while (<= i cnt)
    (setq name (PdfLayout_IniGet (strcat "Profile" (itoa i) "Name")))
    (if name
      (progn
        (setq prof nil)
        (setq prof (PdfLayout_ProfileSet prof "Prefix" (PdfLayout_IniGet (strcat "Profile" (itoa i) "Prefix"))))
        (setq prof (PdfLayout_ProfileSet prof "Start" (atoi (PdfLayout_OrDefault (PdfLayout_IniGet (strcat "Profile" (itoa i) "Start")) "1"))))
        (setq prof (PdfLayout_ProfileSet prof "Digits" (atoi (PdfLayout_OrDefault (PdfLayout_IniGet (strcat "Profile" (itoa i) "Digits")) "2"))))
        (setq prof (PdfLayout_ProfileSet prof "Order" (PdfLayout_OrDefault (PdfLayout_IniGet (strcat "Profile" (itoa i) "Order")) "1")))
        (setq prof (PdfLayout_ProfileSet prof "Src" (PdfLayout_OrDefault (PdfLayout_IniGet (strcat "Profile" (itoa i) "Src")) "1")))
        (setq prof (PdfLayout_ProfileSet prof "FilePath" (PdfLayout_OrDefault (PdfLayout_IniGet (strcat "Profile" (itoa i) "FilePath")) "")))
        (setq prof (PdfLayout_ProfileSet prof "BgMode" (PdfLayout_OrDefault (PdfLayout_IniGet (strcat "Profile" (itoa i) "BgMode")) "0")))
        (setq prof (PdfLayout_ProfileSet prof "BgColor" (atoi (PdfLayout_OrDefault (PdfLayout_IniGet (strcat "Profile" (itoa i) "BgColor")) "7"))))
        (setq prof (PdfLayout_ProfileSet prof "BgScale" (atof (PdfLayout_OrDefault (PdfLayout_IniGet (strcat "Profile" (itoa i) "BgScale")) "1.5"))))
        (setq *PdfLayout_Profiles* (append *PdfLayout_Profiles* (list (cons name prof))))
      )
    )
    (setq i (1+ i))
  )
)

(defun PdfLayout_SaveProfile (name / prof)
  (setq prof nil)
  (setq prof (PdfLayout_ProfileSet prof "Prefix" *PdfLayout_PreviewPrefix*))
  (setq prof (PdfLayout_ProfileSet prof "Start" *PdfLayout_PreviewStart*))
  (setq prof (PdfLayout_ProfileSet prof "Digits" *PdfLayout_PreviewDigits*))
  (setq prof (PdfLayout_ProfileSet prof "Order" *PdfLayout_PreviewOrder*))
  (setq prof (PdfLayout_ProfileSet prof "Src" *PdfLayout_PreviewSrc*))
  (setq prof (PdfLayout_ProfileSet prof "FilePath" *PdfLayout_PreviewFilePath*))
  (setq prof (PdfLayout_ProfileSet prof "BgMode" *PdfLayout_PreviewBgMode*))
  (setq prof (PdfLayout_ProfileSet prof "BgColor" *PdfLayout_PreviewBgColor*))
  (setq prof (PdfLayout_ProfileSet prof "BgScale" *PdfLayout_PreviewBgScale*))
  (setq *PdfLayout_Profiles*
    (vl-remove-if
      '(lambda (x) (= (strcase (car x)) (strcase name)))
      *PdfLayout_Profiles*))
  (setq *PdfLayout_Profiles* (append *PdfLayout_Profiles* (list (cons name prof))))
  (setq *PdfLayout_CurrentProfile* name)
  (PdfLayout_SaveSettings)
)
(defun c:pdfrename (/ lst n pairs sorted i done name order ctr)
  (vl-load-com)
  (princ "\n[调试] 进入 PDFRENAME")
  (setq lst (PdfLayout_SelectMTexts))
  (if (not lst)
    (princ "\n未选择到多行文字，操作已取消。")
    (progn
      (setq n (length lst))
      (princ (strcat "\n选中 " (itoa n) " 个多行文字"))
      (setq pairs (PdfLayout_PairBBoxes lst))
      (setq *PdfLayout_PreviewPairs* pairs)
      (setq *PdfLayout_PreviewNames* nil)
      (PdfLayout_LoadSettings)
      (setq order (PdfLayout_ShowRenamePreview))
      (if (= order "1")
        (progn
          (setq sorted (if (= *PdfLayout_PreviewSrc* "3")
                         (PdfLayout_SortPairsSmart pairs *PdfLayout_PreviewOrder*)
                         (PdfLayout_SortPairsByOrder pairs *PdfLayout_PreviewOrder*)))
          (if *PdfLayout_Debug*
            (princ (strcat "\n[调试] 排序方式=" *PdfLayout_PreviewOrder* " 文字数=" (itoa (length sorted))))
          )
          (setq done 0 i 0)
          (if (= (logand (getvar "UNDOCTL") 1) 1)
            (command "._UNDO" "_BE")
          )
          (foreach pair sorted
            (setq name (if *PdfLayout_PreviewNames*
                          (nth i *PdfLayout_PreviewNames*)
                          (PdfLayout_NameAtPrefix *PdfLayout_PreviewPrefix*
                                                  (+ *PdfLayout_PreviewStart* i)
                                                  *PdfLayout_PreviewDigits*)))
            (if name
              (vl-catch-all-apply 'vla-put-TextString (list (car pair) name))
            )
            (if *PdfLayout_Debug*
              (progn
                (setq ctr (PdfLayout_BBoxCenter (cdr pair)))
                (princ (strcat "\n[调试] 第" (itoa (1+ i)) "个 中心("
                               (rtos (car ctr) 2 2) "," (rtos (cadr ctr) 2 2)
                               ") -> " name))
              )
            )
            (if (= *PdfLayout_PreviewBgMode* "1")
              (progn
                (vl-catch-all-apply 'vla-put-BackgroundFill (list (car pair) :vlax-true))
                (vl-catch-all-apply 'vla-put-BackgroundFillColor (list (car pair) *PdfLayout_PreviewBgColor*))
                (vl-catch-all-apply 'vla-put-BackgroundScaleFactor (list (car pair) *PdfLayout_PreviewBgScale*))
              )
            )
            (if (= *PdfLayout_PreviewBgMode* "2")
              (vl-catch-all-apply 'vla-put-BackgroundFill (list (car pair) :vlax-false))
            )
            (setq i (1+ i))
            (setq done (1+ done))
          )
          (if (= (logand (getvar "UNDOCTL") 1) 1)
            (command "._UNDO" "_E")
          )
          (princ (strcat "\n完成：已按顺序命名 " (itoa done) " 个多行文字。"))
          (alert (strcat "多行文字命名完成\n\n已按顺序命名 " (itoa done) " 个。"
                         (if *PdfLayout_PreviewNames* "（名称来自文件）" "")))
        )
        (princ "\n已取消命名。")
      )
    )
  )
  (princ)
)
(defun c:pdflayoutdebug ()
  (setq *PdfLayout_Debug* (not *PdfLayout_Debug*))
  (princ (strcat "\nPDF布局调试输出: " (if *PdfLayout_Debug* "开" "关")))
  (princ)
)
(defun c:pdfdiag (/ oldFd fpath)
  ;; 诊断：查看 ZWCAD 的 PDFATTACH 命令行提示顺序（配合修复自动导入全部页）
  (vl-load-com)
  (setq oldFd (getvar "FILEDIA"))
  (setq *PdfLayout_SavedFd* oldFd)
  (setvar "FILEDIA" 0)
  (setq fpath (getfiled "选择用于测试的 PDF（观察提示后按 Esc 取消）" "" "pdf" 4))
  (if fpath
    (progn
      (princ "\nPDFATTACH 诊断开始：请观察命令行提示，看完按 Esc 取消。")
      (vl-catch-all-apply
        '(lambda () (command "._PDFATTACH" fpath))
      )
      (princ "\n诊断结束（若命令还挂起，请按 Esc）。")
    )
  )
  (setq *PdfLayout_SavedFd* nil)
  (setvar "FILEDIA" oldFd)
  (princ)
)
(defun c:pdflayouttest (/ cases passed failed case rule lettersStr pg gStart
                        expect got i allOk)
  (setq cases
    (list
      (list "INV{G2}{L}{N2}" "AB" 6 1
            (list "INV01A01" "INV01A02" "INV01A03" "INV01A04" "INV01A05" "INV01A06"
                  "INV01B01" "INV01B02" "INV01B03" "INV01B04" "INV01B05" "INV01B06"
                  "INV02A01" "INV02A02"))
      (list "图{N2}" "AB" 6 1
            (list "图01" "图02" "图03" "图04" "图05" "图06" "图07" "图08"))
      (list "A-{N3}" "AB" 6 1
            (list "A-001" "A-002" "A-003" "A-004" "A-005"))
      (list "{G2}{L}" "A-Z" 1 1
            (list "01A" "01B" "01C" "01D" "01E"))
      (list "DWG{G1}-{N1}" "AB" 3 5
            (list "DWG5-1" "DWG5-2" "DWG5-3" "DWG6-1" "DWG6-2"))
    )
  )
  (setq passed 0 failed 0)
  (princ "\n==== MAP文件工具箱 自检 ====")
  (foreach case cases
    (setq rule (nth 0 case))
    (setq lettersStr (nth 1 case))
    (setq pg (nth 2 case))
    (setq gStart (nth 3 case))
    (setq expect (nth 4 case))
    (setq got (PdfLayout_GenNames rule lettersStr pg gStart (length expect)))
    (if (and got (= (length got) (length expect)))
      (progn
        (setq i 0 allOk T)
        (while (< i (length expect))
          (if (/= (nth i got) (nth i expect))
            (setq allOk nil)
          )
          (setq i (1+ i))
        )
        (if allOk
          (progn
            (princ (strcat "\n[通过] " rule " + 字母" lettersStr " + 每组" (itoa pg) "张"))
            (setq passed (1+ passed))
          )
          (progn
            (princ (strcat "\n[失败] " rule "  期望: "))
            (foreach n expect (princ (strcat n " ")))
            (princ "  实际: ")
            (foreach n got (princ (strcat n " ")))
            (setq failed (1+ failed))
          )
        )
      )
      (progn
        (princ (strcat "\n[失败] " rule " 无法生成足够名称"))
        (setq failed (1+ failed))
      )
    )
  )
  (setq got (PdfLayout_ParseLetters "A-F"))
  (if (= (length got) 6)
    (progn
      (princ "\n[通过] 字母范围 A-F → 6 个字母")
      (setq passed (1+ passed))
    )
    (progn
      (princ (strcat "\n[失败] 字母范围 A-F 期望6个，实际 " (itoa (length got))))
      (setq failed (1+ failed))
    )
  )
  (princ (strcat "\n---- 结果: 通过 " (itoa passed) " 项，失败 " (itoa failed) " 项 ----"))
  (princ "\n==== 自检结束 ====")
  (princ)
)
;;;-------------------------------------------------------------
;;; PDF底图 LBD 识别与标签填写（需 pdf_extract.py + pypdf）
;;;-------------------------------------------------------------
(setq *PdfLayout_PyLines* (list
"# -*- coding: utf-8 -*-"
"# MAP文件工具箱 - PDF 文字与坐标提取（供 LBD 识别使用）"
"# 输出格式（制表符分隔，UTF-8）:"
"#   P\\t页号\\t页标题文本(前150字)"
"#   L\\t页号\\tfx\\tfy\\t文字片段   （fx/fy 为页内相对位置 0~1，原点左下）"
"# 用法: pdf_extract.py <pdf> <out.txt> [pageStart] [pageEnd]"
"import sys"
""
"def main():"
"    if len(sys.argv) < 3:"
"        print(\"usage: pdf_extract.py <pdf> <out.txt> [pageStart] [pageEnd]\")"
"        sys.exit(1)"
"    pdf, out = sys.argv[1], sys.argv[2]"
"    try:"
"        from pypdf import PdfReader"
"    except ImportError:"
"        try:"
"            from PyPDF2 import PdfReader"
"        except ImportError:"
"            print(\"ERR:pypdf missing, run: python -m pip install pypdf\")"
"            sys.exit(2)"
"    try:"
"        reader = PdfReader(pdf)"
"        n = len(reader.pages)"
"    except Exception as e:"
"        print(\"ERR:open pdf failed: %s\" % e)"
"        sys.exit(3)"
"    p0 = int(sys.argv[3]) if len(sys.argv) > 3 else 1"
"    p1 = int(sys.argv[4]) if len(sys.argv) > 4 else n"
"    if p0 < 1: p0 = 1"
"    if p1 > n: p1 = n"
"    lines = []"
"    for idx in range(p0 - 1, p1):"
"        page = reader.pages[idx]"
"        try:"
"            cb = page.cropbox"
"            x0, y0 = float(cb.left), float(cb.bottom)"
"            pw = float(cb.right) - x0"
"            ph = float(cb.top) - y0"
"        except Exception:"
"            x0, y0, pw, ph = 0.0, 0.0, 1.0, 1.0"
"        if pw <= 0: pw = 1.0"
"        if ph <= 0: ph = 1.0"
"        items = []"
"        all_text = []"
"        def visit_text(text, cm, tm, font, size):"
"            if text:"
"                all_text.append(text)"
"                try:"
"                    dx = cm[0]*tm[4] + cm[2]*tm[5] + cm[4]"
"                    dy = cm[1]*tm[4] + cm[3]*tm[5] + cm[5]"
"                except Exception:"
"                    dx, dy = tm[4], tm[5]"
"                items.append([text, dx, dy])"
"        try:"
"            page.extract_text(visitor_text=visit_text)"
"        except Exception:"
"            items = []"
"        title = \"\".join(all_text[:100])"
"        lines.append(\"P\\t%d\\t%.2f\\t%.2f\\t%s\" % (idx + 1, pw, ph, title[:150].replace(\"\\t\", \" \").replace(\"\\n\", \" \")))"
"        for it in items:"
"            if \"LBD\" not in it[0].upper():"
"                continue"
"            dx, dy = it[1], it[2]"
"            if dx < x0 or dy < y0 or dx > x0 + pw or dy > y0 + ph:"
"                continue"
"            fx = (dx - x0) / pw"
"            fy = (dy - y0) / ph"
"            lines.append(\"L\\t%d\\t%.6f\\t%.6f\\t%s\" % (idx + 1, fx, fy, it[0].replace(\"\\t\", \" \").replace(\"\\n\", \" \")))"
"        print(\"page %d/%d\" % (idx + 1, n), flush=True)"
"    try:"
"        with open(out, \"w\", encoding=\"utf-8\") as f:"
"            f.write(\"\\n\".join(lines))"
"    except Exception as e:"
"        print(\"ERR:write out failed: %s\" % e)"
"        sys.exit(4)"
"    print(\"DONE %d\" % (p1 - p0 + 1))"
""
"main()"
))

(defun PdfLayout_WritePyScript (/ f)
  ;; 把内嵌的 PDF 提取脚本写到临时目录（中望取不到LSP目录时的兜底）
  (setq f (open (strcat (getvar "TEMPPREFIX") "pdf_extract.py") "w"))
  (if f
    (progn
      (foreach ln *PdfLayout_PyLines*
        (write-line ln f)
      )
      (close f)
    )
  )
)

(defun PdfLayout_SplitTab (s / out pos)
  (setq out nil)
  (while (setq pos (vl-string-search (chr 9) s))
    (setq out (append out (list (substr s 1 pos))))
    (setq s (substr s (+ pos 2)))
  )
  (append out (list s))
)
(defun PdfLayout_LbdNumFromText (s / pos i c num)
  ;; 从文字里提取 LBD 编号，如 "INV01A01-LBD-14" -> 14；找不到返回 nil
  (setq pos (vl-string-search "LBD" (strcase s)))
  (if pos
    (progn
      (setq i (+ pos 3) num "")
      (while (and (<= i (strlen s)) (= (strlen num) 0))
        (setq c (substr s i 1))
        (if (= (PdfLayout_CharKind c) "D")
          (progn
            (setq num c)
            (setq i (1+ i))
            (while (and (<= i (strlen s))
                        (= (PdfLayout_CharKind (substr s i 1)) "D"))
              (setq num (strcat num (substr s i 1)))
              (setq i (1+ i))
            )
          )
          (setq i (1+ i))
        )
      )
      (if (> (strlen num) 0) (atoi num) nil)
    )
    nil
  )
)
(defun PdfLayout_ReadExtractFile (path / f line parts pages items)
  ;; 读取 pdf_extract.py 的输出：P 行=页信息，L 行=LBD片段
  ;; 返回 (pages items)；pages=((页号 . 标题)...)，items=((页号 fx fy 文字)...)
  (setq f (open path "r"))
  (setq pages nil items nil)
  (if f
    (progn
      (while (setq line (read-line f))
        (setq parts (PdfLayout_SplitTab line))
        (if (> (length parts) 1)
          (cond
            ((= (car parts) "P")
              (setq pages (append pages (list (list (atoi (nth 1 parts))
                                                    (atof (nth 2 parts))
                                                    (atof (nth 3 parts))
                                                    (if (nth 4 parts) (nth 4 parts) "")))))
            )
            ((= (car parts) "L")
              (setq items (append items (list (list (atoi (nth 1 parts))
                                                    (atof (nth 2 parts))
                                                    (atof (nth 3 parts))
                                                    (if (nth 4 parts) (nth 4 parts) "")))))
            )
          )
        )
      )
      (close f)
    )
  )
  (list pages items)
)
(defun PdfLayout_EnsureLayer (lname / doc layers l)
  (setq doc (vla-get-ActiveDocument (vlax-get-Acad-Object)))
  (setq layers (vla-get-Layers doc))
  (setq l (vl-catch-all-apply 'vla-Item (list layers lname)))
  (if (vl-catch-all-error-p l)
    (setq l (vl-catch-all-apply 'vla-Add (list layers lname)))
  )
  l
)
(defun PdfLayout_ReadAllLbdLabels (path / xl wbs wb shs out i sh sheet ur vals arr
                                   rows map lbd lab cur labels kv)
  ;; 一次读取 Excel 所有分表：返回 ((分表名 . ((LBD编号 . "标签A/标签B") ...)) ...)
  (setq out nil)
  (setq xl (vl-catch-all-apply 'vlax-create-object (list "Excel.Application")))
  (if (and xl (not (vl-catch-all-error-p xl)))
    (progn
      (vl-catch-all-apply 'vlax-put-property (list xl 'Visible 0))
      (vl-catch-all-apply 'vlax-put-property (list xl 'DisplayAlerts 0))
      (setq wbs (vl-catch-all-apply 'vlax-get-property (list xl 'Workbooks)))
      (setq wb (vl-catch-all-apply 'vlax-invoke-method (list wbs 'Open path 0 1)))
      (if (and wb (not (vl-catch-all-error-p wb)))
        (progn
          (setq shs (vl-catch-all-apply 'vlax-get-property (list wb 'Sheets)))
          (if (and shs (not (vl-catch-all-error-p shs)))
            (progn
              (setq i 1)
              (while (<= i (vlax-get-property shs 'Count))
                (setq sh (vl-catch-all-apply 'vlax-get-property (list shs 'Item i)))
                (if (not (vl-catch-all-error-p sh))
                  (progn
                    (setq sheet (vlax-get-property sh 'Name))
                    (setq ur (vl-catch-all-apply 'vlax-get-property (list sh 'UsedRange)))
                    (setq map nil)
                    (if (and ur (not (vl-catch-all-error-p ur)))
                      (progn
                        (setq vals (vl-catch-all-apply 'vlax-get-property (list ur 'Value)))
                        (if (not (vl-catch-all-error-p vals))
                          (progn
                            (setq arr (vlax-variant-value vals))
                            (setq rows (vlax-safearray->list arr))
                            (setq rows (mapcar '(lambda (r) (mapcar 'PdfLayout_CellStr r)) rows))
                            (foreach r rows
                              (setq lbd (nth 0 r) lab (nth 2 r))
                              (if (and lbd (/= lbd "") (PdfLayout_LbdNumFromText lbd))
                                (progn
                                  (setq n0 (PdfLayout_LbdNumFromText lbd))
                                  (setq cur (assoc n0 map))
                                  (if cur
                                    (setq map (subst (cons n0 (append (cdr cur) (list lab))) cur map))
                                    (setq map (append map (list (cons n0 (list lab)))))
                                  )
                                )
                              )
                            )
                            (setq labels nil)
                            (foreach kv map
                              (setq labels (append labels (list (cons (car kv)
                                                                       (PdfLayout_JoinLabelsList (cdr kv))))))
                            )
                            (setq out (append out (list (cons sheet labels))))
                          )
                        )
                      )
                    )
                  )
                )
                (setq i (1+ i))
              )
            )
          )
          (vl-catch-all-apply 'vlax-invoke-method (list wb 'Close 0))
        )
      )
      (vl-catch-all-apply 'vlax-invoke-method (list xl 'Quit))
    )
  )
  out
)
(defun PdfLayout_GetPdfUnderlays (/ doc ms out obj)
  (setq doc (vla-get-ActiveDocument (vlax-get-Acad-Object)))
  (setq ms (vla-get-ModelSpace doc))
  (setq out nil)
  (vlax-for obj ms
    (if (= (strcase (vla-get-ObjectName obj)) "ACDBPDFREFERENCE")
      (setq out (append out (list obj)))
    )
  )
  out
)
(defun c:pdflbd (/ pdfPath xlsxPath script outPath res pages items sheetMap underlays
                 ms nPage i u bb pmin pmax bw bh pItems cx cy done it num cur dOld dNew
                 sheetName sheetLabels labels mx my ptIns mObj nFill nMiss wait lay
                 pw ph pTitle shName orderWarn pg)
  (vl-load-com)
  (setq nFill 0 nMiss 0 orderWarn 0)
  (setq pdfPath (getfiled "选择PDF底图对应的原始PDF文件" "" "pdf" 4))
  (if (not pdfPath)
    (princ "\n已取消。")
    (progn
      (setq xlsxPath (getfiled "选择标签Excel(分表名=布局名)" "" "xlsx;xls" 4))
      (if (not xlsxPath)
        (princ "\n已取消。")
        (progn
          (princ "\n正在提取PDF文字与坐标(页数多需几分钟，请耐心等待)…")
          (PdfLayout_WritePyScript)
          (setq script (strcat (getvar "TEMPPREFIX") "pdf_extract.py"))
          (setq outPath (strcat (getvar "TEMPPREFIX") "pdflbd_extract.txt"))
          (if (findfile outPath) (vl-file-delete outPath))
          (vl-catch-all-apply 'startapp
            (list (strcat "python \"" script "\" \"" pdfPath "\" \"" outPath "\"")))
          (setq wait 0)
          (while (and (< wait 1800) (not (findfile outPath)))
            (command "._DELAY" 500)
            (setq wait (1+ wait))
          )
          (if (not (findfile outPath))
            (alert "PDF文字提取失败：请确认已安装Python并运行过 python -m pip install pypdf。")
            (progn
              (setq res (PdfLayout_ReadExtractFile outPath))
              (setq pages (car res) items (cadr res))
              (princ (strcat "\n已提取 " (itoa (length pages)) " 页，识别到 "
                             (itoa (length items)) " 个LBD片段。"))
              (princ "\n正在读取标签Excel分表…")
              (setq sheetMap (PdfLayout_ReadAllLbdLabels xlsxPath))
              (setq underlays (PdfLayout_GetPdfUnderlays))
              (setq ms (vla-get-ModelSpace (vla-get-ActiveDocument (vlax-get-Acad-Object))))
              (if (/= (length underlays) (length pages))
                (princ (strcat "\n注意: 模型空间底图数(" (itoa (length underlays))
                               ")与PDF页数(" (itoa (length pages)) ")不一致，按顺序对应前"
                               (itoa (min (length underlays) (length pages))) "页。"))
              )
              (setq i 0)
              (foreach u underlays
                (setq pgnum (1+ i))
                (setq bb (PdfLayout_GetExtentsSafeObj u))
                (if bb
                  (progn
                    (setq pmin (car bb) pmax (cadr bb))
                    (setq bw (- (car pmax) (car pmin)))
                    (setq bh (- (cadr pmax) (cadr pmin)))
                    (setq pw 1.0 ph 1.0 pTitle "")
                    (foreach pg pages
                      (if (= (car pg) pgnum)
                        (setq pw (cadr pg) ph (caddr pg) pTitle (cadddr pg))
                      )
                    )
                    ;; 底图比例与PDF页不一致时提示（可能旋转/裁剪）
                    (if (and (> pw 0.0) (> ph 0.0) (> bw 0.0) (> bh 0.0))
                      (if (or (> (/ bw bh) (* 1.15 (/ pw ph)))
                              (< (/ bw bh) (* 0.85 (/ pw ph))))
                        (princ (strcat "\n注意: 第" (itoa pgnum)
                                       "页底图比例与PDF不一致，可能旋转/裁剪，标签位置可能不准。"))
                      )
                    )
                    ;; 页序校验：该页标题应包含对应分表名
                    (if (and sheetMap (nth (1- pgnum) sheetMap))
                      (progn
                        (setq shName (car (nth (1- pgnum) sheetMap)))
                        (if (and pTitle shName
                                 (not (vl-string-search (strcase shName) (strcase pTitle))))
                          (setq orderWarn (1+ orderWarn))
                        )
                      )
                    )                    (setq pItems nil)
                    (foreach it items
                      (if (= (nth 0 it) pgnum)
                        (setq pItems (append pItems (list it)))
                      )
                    )
                    ;; 每个编号取离页中心最近的片段（避免填到明细表/图框里的重复）
                    (setq cx 0.5 cy 0.5 done nil)
                    (foreach it pItems
                      (setq num (PdfLayout_LbdNumFromText (nth 3 it)))
                      (if num
                        (progn
                          (setq cur (assoc num done))
                          (if cur
                            (progn
                              (setq dOld (distance (list (cadr cur) (caddr cur)) (list cx cy)))
                              (setq dNew (distance (list (nth 1 it) (nth 2 it)) (list cx cy)))
                              (if (< dNew dOld)
                                (setq done (subst (list num (nth 1 it) (nth 2 it)) cur done))
                              )
                            )
                            (setq done (append done (list (list num (nth 1 it) (nth 2 it)))))
                          )
                        )
                      )
                    )
                    (setq sheetLabels (if sheetMap (cdr (nth (1- pgnum) sheetMap)) nil))
                    (foreach d done
                      (setq num (car d) fx (cadr d) fy (caddr d))
                      (setq labels (if sheetLabels (cdr (assoc num sheetLabels)) nil))
                      (if labels
                        (progn
                          (setq mx (+ (car pmin) (* fx bw)))
                          (setq my (+ (cadr pmin) (* fy bh)))
                          (setq ptIns (list (+ mx 2.0) (- my 1.5) 0.0))
                          (setq mObj (vl-catch-all-apply 'vla-AddMText
                                       (list ms (vlax-3d-point ptIns) 100.0 labels)))
                          (if (and mObj (not (vl-catch-all-error-p mObj)))
                            (progn
                              (vl-catch-all-apply 'vla-put-Height (list mObj 1.5))
                              (setq lay (PdfLayout_EnsureLayer "LBD标签"))
                              (if (and lay (not (vl-catch-all-error-p lay)))
                                (vl-catch-all-apply 'vla-put-Layer (list mObj "LBD标签"))
                              )
                              (setq nFill (1+ nFill))
                              (princ (strcat "\n第" (itoa pgnum) "页 LBD-" (itoa num)
                                             " -> " labels))
                            )
                          )
                        )
                        (setq nMiss (1+ nMiss))
                      )
                    )
                  )
                )
                (setq i (1+ i))
              )
              (princ (strcat "\n完成：填写 " (itoa nFill) " 个，未找到标签 " (itoa nMiss) " 个。"))
              (if (> orderWarn 0)
                (princ (strcat "\n警告: 有 " (itoa orderWarn)
                               " 页的分表名与PDF页内容对不上，页序可能错位，请核对。"))
              )            )
          )
        )
      )
    )
  )
  (princ)
)

;;;-------------------------------------------------------------
;;; 加载提示
;;;-------------------------------------------------------------
(setvar "FILEDIA" 1)
(princ "\n=====================================")
  (princ "\n  MAP文件工具箱 v2.16 已加载")
(princ "\n  命令: PDFLAYOUT    (对话框版)")
(princ "\n  命令: PDFLAYOUTTEST (命名引擎自检)")
(princ "\n  命令: PDFLAYOUTDEBUG (视口适配调试)")
(princ "\n  命令: PDFRENAME (多行文字按顺序命名，支持CSV导入)")
(princ "\n  命令: PDFLBD      (识别底图LBD并填写标签)")
(princ "\n  流程: 识别模型空间图纸 → 复制模板布局")
(princ "\n        → 按规则自动改名 → 视口自动对应")
(princ "\n=====================================")
(princ)
