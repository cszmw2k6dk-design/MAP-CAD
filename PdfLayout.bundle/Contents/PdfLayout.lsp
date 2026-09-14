;;;=============================================================
;;; MAP工具箱 PdfLayout.lsp  v2.22
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

;;;@CUIX-BEGIN
;;;-------------------------------------------------------------
;;; PDF 工具栏 CUIX 绝对路径（ZWCAD 取不到 LSP 目录，这里手动指定；
;;; 换安装目录时改这个即可。留空则自动在图纸/上级目录搜索）
;;;-------------------------------------------------------------
(setq *PdfLayout_CuixPath* "")
;;;@CUIX-END

;;;-------------------------------------------------------------
;;; 全局状态与错误处理
;;;-------------------------------------------------------------
(setq *PdfLayout_ViewInset* 0.95)   ; 视口内边缩进系数，避免图纸贴边
(setq *PdfLayout_Running* nil)
(setq *PdfLayout_UndoOn* nil)
(setq *PdfLayout_CreatedLayouts* nil)
(setq *PdfLayout_OldError* *error*)
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
(setq *PdfLayout_LbdTextHeight* 0.05)
(setq *PdfLayout_ExcludeRect* nil)
(setq *PdfLayout_OrderPreviewEnts* nil)
(setq *PdfLayout_GridRows* 4)
(setq *PdfLayout_GridCols* 5)
(setq *PdfLayout_GridRowSp* 10.0)
(setq *PdfLayout_GridColSp* 20.0)
(setq *PdfLayout_GridStart* nil)
(setq *PdfLayout_GridP1* nil)
(setq *PdfLayout_GridP2* nil)
(setq *PdfLayout_GridExtX* 0.0)
(setq *PdfLayout_GridExtY* 0.0)
(setq *PdfLayout_GridH* 1.7)
(setq *PdfLayout_GridHRatio* 0.4)
(setq *PdfLayout_GridGeom* "1")
(setq *PdfLayout_GridRot* 0)
(setq *PdfLayout_GridBg* "fill")
(setq *PdfLayout_GridBgColor* 1)
(setq *PdfLayout_GridBgRGB* 255)
(setq *PdfLayout_GridTxtColor* 7)
(setq *PdfLayout_GridTxtRGB* 16777215)
(setq *PdfLayout_GridTxtTrue* T)
(setq *PdfLayout_GridBgScale* 1.0)
(setq *PdfLayout_GridSrc* "auto")
(setq *PdfLayout_GridPrefix* "CIR")
(setq *PdfLayout_GridStartN* 1)
(setq *PdfLayout_GridDigits* 2)
(setq *PdfLayout_GridNames* nil)
(setq *PdfLayout_GridXlsx* "")
(setq *PdfLayout_GridSheets* nil)
(setq *PdfLayout_GridSheetNames* nil)
(setq *PdfLayout_GridSheetFull* nil)
(setq *PdfLayout_GridSheetSel* "")
(setq *PdfLayout_GridPairs* nil)
(setq *PdfLayout_GridSelPairs* nil)
;; PDFRENAME 多批框选：按框选先后分批保存，编号时一批一批编，不跨批交叉
(setq *PdfLayout_GridSelBatches* nil)
(setq *PdfLayout_GridResult* 0)
(setq *PdfLayout_GridProfiles* nil)
(setq *PdfLayout_GridProfile* "")
(setq *PdfLayout_GridHMode* "auto")
(setq *PdfLayout_GridMT* 0.0)
(setq *PdfLayout_GridMB* 0.0)
(setq *PdfLayout_GridML* 0.0)
(setq *PdfLayout_GridMR* 0.0)
(setq *PdfLayout_GridFirstX* 0.0)
(setq *PdfLayout_GridFirstY* 0.0)
(setq *PdfLayout_GridColDir* 1)
(setq *PdfLayout_GridRowDir* -1)
(setq *PdfLayout_HubAction* "NONE")
(setq *PdfLayout_DlgPdf* "")
(setq *PdfLayout_DlgXlsx* "")
(setq *PdfLayout_DlgPage* "0")
(setq *PdfLayout_DlgH* 0.05)
(setq *PdfLayout_DlgWhere* "M")
(setq *PdfLayout_DlgMode* "auto")
(setq *PdfLayout_DlgOrder* "2")
(setq *PdfLayout_DlgExcl* nil)
(setq *PdfLayout_LbdSheet* nil)
(setq *PdfLayout_LbdSelPairs* nil)
(setq *PdfLayout_LbdSelNames* nil)
(setq *PdfLayout_LbdSelMatches* nil)
(setq *PdfLayout_LbdManualLabels* nil)
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
(setq *PdfLayout_SavedOsmode* nil)
(setq *PdfLayout_SavedRegen* nil)
(setq *PdfLayout_DclLines* (list
"// PdfLayout.dcl"
"// MAP工具箱 v2.22 - 对话框定义"
""
"PdfLayout : dialog {"
"  label = \"MAP工具箱 v2.22\";"
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
"    : text { label = \"从Excel分表名命名布局;数量=识别到的PDF底图数\"; width = 55; }"
"    : row {"
"      : edit_box {"
"        label = \"将创建(按识别到的PDF底图):\";"
"        key = \"count\";"
"        edit_width = 6;"
"        value = \"0\";"
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
"    label = \"布局名预览(来自Excel分表):\";"
"    : list_box {"
"      key = \"preview\";"
"      height = 9;"
"    }"
"  }"
"  ok_cancel;"
"}"
)))



(setq *PdfLayout_DclLines* (append *PdfLayout_DclLines* (list
"PdfGrid : dialog {"
"  label = \"PDF网格批量生成(PDFGRID)\" ;"
"  : row {"
"    : column {"
"  : boxed_column {"
"    label = \"方案预设\";"
"    : row {"
"      : popup_list { label = \"方案:\"; key = \"g_prof\"; edit_width = 18; }"
"      : edit_box { label = \"方案名:\"; key = \"g_profname\"; edit_width = 10; }"
"    }"
"    : row {"
"      : button { label = \"保存为方案\"; key = \"g_saveprof\"; width = 12; }"
"      : button { label = \"删除方案\"; key = \"g_delprof\"; width = 12; }"
"    }"
"  }"
"  : boxed_column {"
"    label = \"网格\";"
"    : row {"
"      : edit_box { label = \"行数:\"; key = \"g_rows\"; edit_width = 5; value = \"4\"; }"
"      : edit_box { label = \"列数:\"; key = \"g_cols\"; edit_width = 5; value = \"5\"; }"
"    }"
"    : row {"
"      : edit_box { label = \"行距:\"; key = \"g_rowsp\"; edit_width = 8; value = \"10\"; }"
"      : edit_box { label = \"列距:\"; key = \"g_colsp\"; edit_width = 8; value = \"20\"; }"
"    }"
"    : row {"
"      : edit_box { label = \"上边距:\"; key = \"g_mt\"; edit_width = 6; value = \"0\"; }"
"      : edit_box { label = \"下边距:\"; key = \"g_mb\"; edit_width = 6; value = \"0\"; }"
"      : edit_box { label = \"左边距:\"; key = \"g_ml\"; edit_width = 6; value = \"0\"; }"
"      : edit_box { label = \"右边距:\"; key = \"g_mr\"; edit_width = 6; value = \"0\"; }"
"    }"
"    : row {"
"      : popup_list { label = \"边距:\"; key = \"g_mmode\"; edit_width = 10; }"
"    }"
"    : row {"
"      : edit_box { label = \"字高比例(自动模式):\"; key = \"g_hratio\"; edit_width = 6; value = \"0.4\"; }"
"      : text { label = \"(字高=min(行距,列距)x比例)\" ; }"
"    : radio_row {"
"      label = \"字高:\";"
"      : radio_button { label = \"按比例自动\"; key = \"g_hauto\"; value = \"1\"; }"
"      : radio_button { label = \"直接输入\"; key = \"g_hmanual\"; }"
"    }"
"    }"
"    : text { label = \"起点/范围: 0, 0（命令时点取/框选；文字按几何中心对齐，边距自范围边起算）\"; key = \"g_start\"; }"
"  }"
"  : boxed_column {"
"    label = \"文字\";"
"    : row {"
"      : edit_box { label = \"字高:\"; key = \"g_h\"; edit_width = 8; value = \"1.7\"; }"
"      : popup_list { label = \"旋转:\"; key = \"g_rot\"; edit_width = 10; }"
"    }"
"    : radio_row {"
"      label = \"背景:\";"
"      : radio_button { label = \"无\"; key = \"g_bgnone\"; }"
"      : radio_button { label = \"填充\"; key = \"g_bgon\"; value = \"1\"; }"
"    }"
"    : row {"
"    : row {"
"      : popup_list { label = \"背景色:\"; key = \"g_bgcolor\"; edit_width = 12; }"
"      : edit_box { label = \"自定义:\"; key = \"g_bgaci\"; edit_width = 4; value = \"1\"; }"
"      : edit_box { label = \"背景遮挡因子(1~5):\"; key = \"g_bgscale\"; edit_width = 5; value = \"1\"; }"
"    }"
"    : row {"
"      : popup_list { label = \"文字色:\"; key = \"g_txtcolor\"; edit_width = 12; }"
"      : edit_box { label = \"自定义:\"; key = \"g_txtaci\"; edit_width = 4; value = \"7\"; }"
"    }"
"    }"
"  }"
"  : boxed_radio_column {"
"    label = \"命名来源\";"
"    : radio_button { label = \"自动命名(前缀+编号)\"; key = \"g_srcauto\"; value = \"1\"; }"

"    : radio_button { label = \"从Excel导入(按分表)\"; key = \"g_srcxlsx\"; }"
"  }"
"  : boxed_column {"
"    label = \"自动命名(前缀+编号):\";"
"    : row {"
"      : edit_box { label = \"前缀:\"; key = \"g_prefix\"; edit_width = 8; value = \"CIR\"; }"
"      : edit_box { label = \"起始:\"; key = \"g_startn\"; edit_width = 5; value = \"1\"; }"
"      : edit_box { label = \"位数(0=不补零):\"; key = \"g_digits\"; edit_width = 4; value = \"2\"; }"
"    }"
"  }"

"  : boxed_column {"
"    label = \"从Excel导入(分表名=布局名):\";"
"    : row {"
"      : edit_box { label = \"Excel:\"; key = \"g_filexlsx\"; edit_width = 20; }"
"      : button { label = \"选择...\"; key = \"g_btnxlsx\"; width = 10; }"
"    }"
"    : row {"
"      : popup_list { label = \"分表:\"; key = \"g_xlsxsheet\"; edit_width = 30; }"
"      : button { label = \"重读\"; key = \"g_btnxlsxre\"; width = 10; }"
"    }"
"  }"
"  : boxed_radio_column {"
"    label = \"排序方式\";"
"    : radio_button { label = \"1 列优先: 左→右列、列内上→下\"; key = \"ord1\"; value = \"1\"; }"
"    : radio_button { label = \"2 行优先: 上→下行、行内左→右\"; key = \"ord2\"; }"
"    : radio_button { label = \"3 列优先: 右→左列、列内上→下\"; key = \"ord3\"; }"
"    : radio_button { label = \"4 行优先: 下→上行、行内左→右\"; key = \"ord4\"; }"
"    : radio_button { label = \"5 列优先: 左→右列、列内下→上\"; key = \"ord5\"; }"
"    : radio_button { label = \"6 列优先: 右→左列、列内下→上\"; key = \"ord6\"; }"
"    : radio_button { label = \"7 行优先: 上→下行、行内右→左\"; key = \"ord7\"; }"
"    : radio_button { label = \"8 行优先: 下→上行、行内右→左\"; key = \"ord8\"; }"
"  }"
"    }"
"    : column {"
"  : boxed_column {"
"    label = \"预览(左=顺序 右=名称):\";"
"    : row {"
"      : list_box { key = \"g_grid\"; height = 8; width = 26; }"
"      : list_box { key = \"g_names\"; height = 8; width = 22; }"
"    }"
"  }"
"    }"
"  }"
"  : text { key = \"g_info\"; label = \" \"; width = 60; }"
"  : button { label = \"继续框选下一个区域（累加选择）\"; key = \"g_addsel\"; }"
"  ok_cancel;"
"}"
)))
(setq *PdfLayout_DclLines* (append *PdfLayout_DclLines* (list
"PdfHub : dialog {"
"  label = \"MAP工具箱\";"
"  : boxed_column {"
"    label = \"功能\";"
"    : button { label = \"① PDF底图 LBD 识别填标签\"; key = \"hub_lbd\"; }"
"    : button { label = \"② 图纸识别 / 布局管理\"; key = \"hub_layout\"; }"
"    : button { label = \"③ 批量生成网格文字\"; key = \"hub_grid\"; }"
"    : button { label = \"④ 自动改名\"; key = \"hub_rename\"; }"
"    : button { label = \"⑤ 快速复制\"; key = \"hub_quickcopy\"; }"
"    : button { label = \"⑥ 刷内容\"; key = \"hub_brush\"; }"
"  }"
"  : boxed_column {"
"    label = \"维护\";"
"    : row {"
"      : button { label = \"默认字高\"; key = \"hub_lbdh\"; }"
"    }"
"  }"
"  : text { key = \"hub_info\"; label = \"提示: 命令行仍可直接输入原命令\"; width = 60; }"
"  ok_cancel;"
"}"
)))
(setq *PdfLayout_DclLines* (append *PdfLayout_DclLines* (list
"PdfLbd : dialog {"
"  label = \"PDF底图 LBD 识别\";"
"  : boxed_column {"
"    label = \"文件\";"
"    : row {"
"      : edit_box { label = \"PDF底图原始PDF:\"; key = \"lbd_pdf\"; edit_width = 34; }"
"      : button { label = \"选择...\"; key = \"btn_pdf\"; width = 10; }"
"    }"
"    : row {"
"      : edit_box { label = \"标签Excel(分表名=布局名,可选):\"; key = \"lbd_xlsx\"; edit_width = 34; }"
"      : button { label = \"选择...\"; key = \"btn_xlsx\"; width = 10; }"
"    }"
"  }"
"  : boxed_column {"
"    label = \"识别选项\";"
"    : edit_box { label = \"只识别第几页(0=全部):\"; key = \"lbd_page\"; edit_width = 5; value = \"0\"; }"
"    : radio_row {"
"      label = \"标签写入位置:\";"
"      : radio_button { label = \"M模型空间\"; key = \"lbd_m\"; value = \"1\"; }"
"      : radio_button { label = \"L当前布局\"; key = \"lbd_l\"; }"
"      : radio_button { label = \"B两者\"; key = \"lbd_b\"; }"
"    }"
"    : edit_box { label = \"标签字高(模型单位):\"; key = \"lbd_h\"; edit_width = 6; value = \"0.05\"; }"
"    : toggle { label = \"框选排除干扰区域(右下角细节图等)\"; key = \"lbd_excl\"; value = \"0\"; }"
"  }"
"  ok_cancel;"
"}"
)))


(setq *PdfLayout_DclLines* (append *PdfLayout_DclLines* (list
"PdfLbdManual : dialog {"
"  label = \"PDFLBD 手动导入(按Excel LBD号)\" ;"
"  : boxed_column {"
"    label = \"标签Excel\";"
"    : row {"
"      : edit_box { label = \"Excel(分表名=布局名):\"; key = \"lm_xlsx\"; edit_width = 30; }"
"      : button { label = \"选择...\"; key = \"lm_btnxlsx\"; width = 10; }"
"      : button { label = \"重读\"; key = \"lm_btnxlsxre\"; width = 10; }"
"    }"
"  }"
"  : boxed_column {"
"    label = \"填写顺序\";"
"    : row {"
"      : popup_list { label = \"排列顺序:\"; key = \"lm_order\"; edit_width = 28; }"
"      : edit_box { label = \"分行容差%:\"; key = \"lm_rowtol\"; edit_width = 5; value = \"10\"; }"
"    }"
"  }"
"  : boxed_column {"
"    label = \"预览(左=按顺序排序后的文字, 右=按Excel LBD号升序的标签):\";"
"    : row {"
"      : list_box { key = \"lm_grid\"; height = 10; width = 30; }"
"      : list_box { key = \"lm_names\"; height = 10; width = 26; }"
"    }"
"    : text { key = \"lm_info\"; label = \" \"; width = 60; }"
"  }"
"    : button { label = \"手动摆放(逐张挑点)...\"; key = \"lm_place\"; width = 14; }"
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
  ;; 出错/中断时恢复被手动摆放临时关闭的对象捕捉与自动重生成，避免图形看起来“卡住不刷新”
  (if *PdfLayout_SavedOsmode*
    (progn
      (vl-catch-all-apply 'setvar (list "OSMODE" *PdfLayout_SavedOsmode*))
      (setq *PdfLayout_SavedOsmode* nil)
    )
  )
  (if *PdfLayout_SavedRegen*
    (progn
      (vl-catch-all-apply 'setvar (list "REGENMODE" *PdfLayout_SavedRegen*))
      (setq *PdfLayout_SavedRegen* nil)
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
  (if (= (type obj) 'ENAME) (setq obj (vl-catch-all-apply 'vlax-ename->vla-object (list obj))))
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
  ;; 按底端 y 精确分行（竖线块摆放齐平，不做容差合并），一行的竖线块全部识别完再开启下一行
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
;; 尝试2：只给路径，让 ZWCAD 用默认值（确认不会挂起）
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
          ;; 直接使用 Excel 分表名作为布局名
          (princ (strcat "\n已读取 " (itoa (length *PdfLayout_NamesXlsxList*)) " 个分表名作为布局名。"))
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
  (setq out nil)
  (foreach m markers
    (setq pt (PdfLayout_BBoxCenter (cdr m)))
    (setq u (PdfLayout_MatchMarkerUnderlay pt))
    (setq bb (if u (PdfLayout_GetExtentsSafeObj u) (cdr m)))
    (if bb
      (setq out (append out (list bb)))
    )
  )
  out
)
(defun PdfLayout_CmpCreationOrder (a b / ia ib)
  ;; 按底图创建/导入顺序排（对 PDFATTACH 一次导入的一批页 ≈ 页码顺序），纯数字比较，不读实体，防崩
  (setq ia (car a) ib (car b))
  (< ia ib)
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
  (setq pages (PdfLayout_StableSort pages 'PdfLayout_CmpCreationOrder))
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
  (setq pages (PdfLayout_StableSort pages (quote PdfLayout_CmpCreationOrder)))
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
(defun PdfLayout_SortMarkersRowMajor (lst / sorted rows g out grp k prevK)
  ;; 竖线标记按行排序：同一行内从左往右，行与行从上往下，
  ;; 一行的竖线块全部识别完再开启下一行。
  ;; 按底端 y 精确分行（摆放齐平，不做容差合并），
  ;; 仅浮点误差范围（1e-6）内视为同一行
  (if (< (length lst) 2)
    lst
    (progn
      (setq sorted (PdfLayout_SortIndexed lst 'PdfLayout_CmpRowBottom))
      ;; 按底端 y 从高到低分行：底端差超过浮点误差即换行
      (setq rows nil g (list (car sorted))
            prevK (cadr (car (cdr (car sorted)))))
      (foreach p (cdr sorted)
        (setq k (cadr (car (cdr p))))
        (if (> (abs (- prevK k)) 1e-6)
          (progn
            (setq rows (append rows (list g)))
            (setq g (list p))
          )
          (setq g (append g (list p)))
        )
        (setq prevK k)
      )
      (setq rows (append rows (list g)))
      ;; 每行内从左往右，行与行按从上往下拼接
      (setq out nil)
      (foreach grp rows
        (setq grp (PdfLayout_SortIndexed grp 'PdfLayout_CmpXAsc))
        (setq out (append out grp))
      )
      out
    )
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
      (setq tol (max 0.25 (* (if (and *PdfLayout_RowTol* (> *PdfLayout_RowTol* 0)) *PdfLayout_RowTol* 10)
                            0.001 (if (= axis "X") xRange yRange))))
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
  (if (or (not tmpl) (not (PdfLayout_GetLayoutObj tmpl)))
    (progn
      (alert "模板布局无效或不存在，操作已取消。")
      (setq ok nil)
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
                             " 个竖线标记，少于要创建的 " (itoa count)
                             " 个布局，按 " (itoa nDraw) " 个执行。"))
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
        (progn
          (alert "请选择“布局名来自Excel分表”的标签文件，Excel 分表名将作为布局名。")
          (setq ok nil)
        )
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
  (set_tile "count" (itoa (length (PdfLayout_GetPdfUnderlays))))
  (mode_tile "count" 1)
  (set_tile "overwrite" "0")
  (if (and *PdfLayout_LastNamesXlsx* (/= *PdfLayout_LastNamesXlsx* ""))
    (set_tile "names_xlsx" *PdfLayout_LastNamesXlsx*)
  )
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

(defun PdfLayout_UpdatePreview (/ count names i s)
  ;; 预览：按识别到的 PDF 底图数，列出本次实际会用的布局名
  (setq count (atoi (get_tile "count")))
  (if (and *PdfLayout_NamesXlsxList* (/= (PdfLayout_GetTileStr "names_xlsx") ""))
    (progn
      (setq names *PdfLayout_NamesXlsxList*)
      (setq s "")
      (setq i 0)
      (while (and (< i (length names)) (< i 40)
                  (or (<= count 0) (< i count)))
        (setq s (strcat s (nth i names) "\n"))
        (setq i (1+ i))
      )
      (if (< i (length names))
        (setq s (strcat s "…共 " (itoa (length names)) " 个分表名，本次只取前 "
                        (itoa count) " 个"))
      )
      (set_tile "preview" s)
    )
    (set_tile "preview" "请先选择“布局名来自Excel分表”的标签文件（数量按识别到的 PDF 底图数）")
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
                            margin overwrite lockVp mnList msg namesXlsx xNames
                            nUnder nSheet i nm padded)
  (setq mode "marker")
  (setq mnList (PdfLayout_GetMarkerNameList))
  (setq filter (nth (atoi (PdfLayout_GetTileStr "marker_name")) mnList))
  (if (not filter) (setq filter "pdf"))
  (setq tmpl (nth (atoi (get_tile "tmpl_layout"))
                  (PdfLayout_GetLayoutNames)))
  (setq margin (if (= (PdfLayout_GetTileStr "margin") "") 5 (atof (PdfLayout_GetTileStr "margin"))))
  (setq overwrite (= (get_tile "overwrite") "1"))
  (setq lockVp (= (PdfLayout_GetTileStr "lock_vp") "1"))
  (setq namesXlsx (PdfLayout_GetTileStr "names_xlsx"))
  (setq xNames nil)
  ;; 数量以「识别到的 PDF 底图数」为准；Excel 分表名只作布局名来源，不再覆盖数量
  (setq nUnder (length (PdfLayout_GetPdfUnderlays)))
  (setq count nUnder)
  (if (and namesXlsx (/= namesXlsx ""))
    (progn
      (setq xNames (PdfLayout_GetXlsxSheetNames namesXlsx))
      (if (not xNames)
        (alert "无法读取Excel分表名，请确认文件存在且未被占用。")
        (progn
          (setq nSheet (length xNames))
          (cond
            ((and (> count 0) (> nSheet count))
              (alert (strcat "Excel 分表名 " (itoa nSheet) " 个，识别到的 PDF 底图 "
                             (itoa count) " 个。\n将按底图数创建 " (itoa count)
                             " 个布局，名称取分表名前 " (itoa count) " 个。")))
            ((and (> count 0) (< nSheet count))
              ;; 分表名不够：循环使用分表名并加序号后缀，布局数仍按底图数
              (setq padded nil i 0)
              (while (< i count)
                (setq nm (nth (rem i nSheet) xNames))
                (if (>= (/ i nSheet) 1)
                  (setq nm (strcat nm "_" (itoa (1+ (/ i nSheet)))))
                )
                (setq padded (append padded (list nm)))
                (setq i (1+ i))
              )
              (setq xNames padded)
              (alert (strcat "Excel 分表名 " (itoa nSheet) " 个，识别到的 PDF 底图 "
                             (itoa count) " 个。\n将按底图数创建 " (itoa count)
                             " 个布局：分表名不够，多出的按「分表名_序号」补齐（如 "
                             (nth nSheet xNames) "）。")))
          )
        )
      )
    )
  )

  (if (or (not tmpl) (not (PdfLayout_GetLayoutObj tmpl)))
    (alert "请选择模板布局（当前图纸需至少有一个布局）")
    (progn
      (if (or (not namesXlsx) (= namesXlsx ""))
        (alert "请选择“布局名来自Excel分表”的标签文件，Excel 分表名将作为布局名。")
        (if (not xNames)
          nil
          (if (<= count 0)
            (alert "模型空间里没有识别到 PDF 底图，无法确定要创建的布局数量。")
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
;;; 多行文字按顺序命名
;;;-------------------------------------------------------------
(defun PdfLayout_NameAtPrefix (prefix num digits / s)
  (setq s (itoa num))
  (if (> digits (strlen s))
    (repeat (- digits (strlen s))
      (setq s (strcat "0" s))
    )
  )
  (strcat prefix s)
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
(defun PdfLayout_ExcelCleanup (xl hadExcel objs / wbs cnt quitNow)
  ;; 释放 Excel 读取后遗留的 COM 引用，并退出不再需要的后台 Excel 实例，
  ;; 避免“读取表格后 Excel 一直挂在后台”。
  (while objs
    (if (car objs)
      (vl-catch-all-apply 'vlax-release-object (list (car objs)))
    )
    (setq objs (cdr objs))
  )
  ;; 是否退出该 Excel：本次新建（原来没会议）必须退出；或该实例已无任何打开的工作簿
  ;; （上次遗留的空后台）一并退出；若用户自己开着工作簿（Count>=1）则绝不退出。
  (setq quitNow (not hadExcel))
  (if (not quitNow)
    (progn
      (setq wbs (vl-catch-all-apply 'vlax-get-property (list xl 'Workbooks)))
      (if (and wbs (not (vl-catch-all-error-p wbs)))
        (progn
          (setq cnt (vl-catch-all-apply 'vlax-get-property (list wbs 'Count)))
          (if (and (not (vl-catch-all-error-p cnt)) (numberp cnt) (= cnt 0))
            (setq quitNow T)
          )
        )
      )
    )
  )
  (if quitNow
    (vl-catch-all-apply 'vlax-invoke-method (list xl 'Quit))
  )
  (if (and wbs (not (vl-catch-all-error-p wbs)))
    (vl-catch-all-apply 'vlax-release-object (list wbs))
  )
  (if xl
    (vl-catch-all-apply 'vlax-release-object (list xl))
  )
  (setq xl nil)
)

(defun PdfLayout_GetXlsxSheetNames (path / xl wbs wb shs names i sh hadExcel)
  ;; 读取 Excel 工作簿的所有分表名（按表顺序），用于“布局名来自Excel分表”
  (setq names nil)
  (setq hadExcel (vl-catch-all-apply 'vlax-get-object (list "Excel.Application")))
  (setq hadExcel (and hadExcel (not (vl-catch-all-error-p hadExcel))))
  (setq xl (vl-catch-all-apply 'vlax-create-object (list "Excel.Application")))
  (if (and xl (not (vl-catch-all-error-p xl)))
    (progn
      (vl-catch-all-apply 'vlax-put-property (list xl 'Visible 0))
      (vl-catch-all-apply 'vlax-put-property (list xl 'DisplayAlerts 0))
      (vl-catch-all-apply 'vlax-put-property (list xl 'AskToUpdateLinks 0))
      (vl-catch-all-apply 'vlax-put-property (list xl 'AutomationSecurity 3))
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
      ;; 释放 Excel 的 COM 引用并退出不再需要的后台实例，避免读取表格后 Excel 挂在后台
      (PdfLayout_ExcelCleanup xl hadExcel (list shs sh ur wb wbs))
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

(defun PdfLayout_JoinLabelsList (labels / out)
  (setq out "")
  (foreach s labels
    (if (and s (/= s ""))
      (setq out (if (= out "") s (strcat out "/" s)))
    )
  )
  out
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

(defun PdfLayout_BuildSchemeGrid (pairs order sorted / idxMap i p ys ymax ymin
                                  tol byY cur curY rows item rowX line out idx
                                  rowY)
  (while (> (length pairs) 2000)
    (setq pairs (reverse (cdr (reverse pairs))))
  )
  ;; 调用方给了顺序（如 PDFRENAME 按框选批次排序）就用它，否则按位置自动排
  (if (not sorted) (setq sorted (PdfLayout_SortPairsSmart pairs order)))
  (setq idxMap nil i 1)
  (foreach p sorted
    (setq idxMap (cons (cons p i) idxMap))
    (setq i (1+ i))
  )
  (setq ys (mapcar '(lambda (q) (cadr (PdfLayout_BBoxCenter (cdr q)))) pairs))
  (setq ymax (apply 'max ys) ymin (apply 'min ys))
  (setq tol (max 0.25 (* 0.001 (if (and *PdfLayout_RowTol* (> *PdfLayout_RowTol* 0)) *PdfLayout_RowTol* 10) (- ymax ymin))))
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
    (setq rowX (PdfLayout_StableSort row 'PdfLayout_CmpXAsc))
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

(defun PdfLayout_SetList (key items / s)
  (start_list key)
  (foreach s items
    (if (eq (type s) 'STR)
      (add_list s)
    )
  )
  (end_list)
)

(defun PdfLayout_EllipsisMid (s n / head tail)
  ;; 预览用：文字过长时中间用省略号代替，保留头尾（尾部通常是最能区分的编号）
  (if (or (not s) (<= n 6) (<= (strlen s) n))
    s
    (progn
      (setq head (- n 6))
      (setq tail 3)
      (strcat (substr s 1 head) "..." (substr s (- (strlen s) (1- tail))))
    )
  )
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


(defun PdfLayout_OrderDesc (ord / out)
  (setq out (cond
    ((= ord "1") "1 列优先: 左→右列、列内上→下")
    ((= ord "2") "2 行优先: 上→下行、行内左→右")
    ((= ord "3") "3 列优先: 右→左列、列内上→下")
    ((= ord "4") "4 行优先: 下→上行、行内左→右")
    ((= ord "5") "5 列优先: 左→右列、列内下→上")
    ((= ord "6") "6 列优先: 右→左列、列内下→上")
    ((= ord "7") "7 行优先: 上→下行、行内右→左")
    ((= ord "8") "8 行优先: 下→上行、行内右→左")
    (t "1")
  ))
  out
)
(defun PdfLayout_OrderPreviewClear ()
  (foreach e *PdfLayout_OrderPreviewEnts*
    (vl-catch-all-apply 'vla-Delete (list (vlax-ename->vla-object e)))
  )
  (setq *PdfLayout_OrderPreviewEnts* nil)
)

(defun PdfLayout_OrderPreviewShow (/ doc sorted i obj owner lay hgt pt ins m)
  (PdfLayout_OrderPreviewClear)
  (setq doc (vla-get-ActiveDocument (vlax-get-Acad-Object)))
  (setq sorted (PdfLayout_SortPairsSmart *PdfLayout_PreviewPairs* *PdfLayout_PreviewOrder*))
  (setq i 1)
  (foreach pair sorted
    (setq obj (car pair))
    (setq owner (vl-catch-all-apply
                  '(lambda () (vlax-ename->vla-object
                                (cdr (assoc 330 (entget (vlax-vla-object->ename obj))))))
                  nil))
    (setq hgt (vl-catch-all-apply 'vla-get-Height (list obj)))
    (if (or (not hgt) (vl-catch-all-error-p hgt) (<= hgt 0.0))
      (setq hgt 0.05)
    )
    (setq pt (PdfLayout_BBoxCenter (cdr pair)))
    (setq ins (list (+ (car pt) (* hgt 0.4)) (- (cadr pt) (* hgt 0.4)) 0.0))
    (if (and owner (not (vl-catch-all-error-p owner)))
      (progn
        (setq m (vl-catch-all-apply 'vla-AddMText
                  (list owner (vlax-3d-point ins) (* hgt 6.0) (itoa i))))
        (if (and m (not (vl-catch-all-error-p m)))
          (progn
            (vl-catch-all-apply 'vla-put-Height (list m (* hgt 0.7)))
            (vl-catch-all-apply 'vla-put-Color (list m 1))
            (setq lay (PdfLayout_EnsureLayer "PDF布局_顺序预览"))
            (if (and lay (not (vl-catch-all-error-p lay)))
              (vl-catch-all-apply 'vla-put-Layer (list m "PDF布局_顺序预览"))
            )
            (setq *PdfLayout_OrderPreviewEnts*
                  (append *PdfLayout_OrderPreviewEnts*
                          (list (vlax-vla-object->ename m))))
          )
        )
      )
    )
    (setq i (1+ i))
  )
  (vl-catch-all-apply 'vla-Regen (list doc acAllViewports))
)

(defun PdfLayout_OrderPreviewRefresh ()
  (if (= (PdfLayout_GetTileStr "ord_prev") "1")
    (PdfLayout_OrderPreviewShow)
    (PdfLayout_OrderPreviewClear)
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
(setq *PdfLayout_LbdTextHeight* 0.05)
(setq *PdfLayout_ExcludeRect* nil)
  (setq *PdfLayout_OrderPreviewEnts* nil)
(setq *PdfLayout_GridRows* 4)
  (setq *PdfLayout_GridCols* 5)
  (setq *PdfLayout_GridRowSp* 10.0)
  (setq *PdfLayout_GridColSp* 20.0)
  (setq *PdfLayout_GridH* 1.7)
  (setq *PdfLayout_GridHRatio* 0.4)
  (setq *PdfLayout_GridGeom* "1")
  (setq *PdfLayout_GridRot* 0)
  (setq *PdfLayout_GridBg* "fill")
  (setq *PdfLayout_GridBgColor* 1)
  (setq *PdfLayout_GridBgRGB* 255)
  (setq *PdfLayout_GridTxtColor* 7)
  (setq *PdfLayout_GridTxtRGB* 16777215)
  (setq *PdfLayout_GridTxtTrue* T)
  (setq *PdfLayout_GridBgScale* 1.0)
  (setq *PdfLayout_GridPrefix* "CIR")
  (setq *PdfLayout_GridStartN* 1)
  (setq *PdfLayout_GridDigits* 2)
  (setq *PdfLayout_GridSrc* "auto")
    (setq *PdfLayout_GridNames* nil)
  (setq *PdfLayout_GridXlsx* "")
  (setq *PdfLayout_GridSheets* nil)
  (setq *PdfLayout_GridSheetNames* nil)
  (setq *PdfLayout_GridSheetFull* nil)
  (setq *PdfLayout_GridSheetSel* "")
  (setq *PdfLayout_GridStart* nil)
  (setq *PdfLayout_GridP1* nil)
  (setq *PdfLayout_GridP2* nil)
  (setq *PdfLayout_GridExtX* 0.0)
  (setq *PdfLayout_GridExtY* 0.0)
  (setq *PdfLayout_GridHMode* "auto")
  (setq *PdfLayout_GridMT* 0.0)
  (setq *PdfLayout_GridMB* 0.0)
  (setq *PdfLayout_GridML* 0.0)
  (setq *PdfLayout_GridMR* 0.0)
  (setq *PdfLayout_GridFirstX* 0.0)
  (setq *PdfLayout_GridFirstY* 0.0)
  (setq *PdfLayout_GridColDir* 1)
  (setq *PdfLayout_GridRowDir* -1)
  (setq *PdfLayout_LbdRows* nil)
  (setq *PdfLayout_BrushMode* "1")
  (setq *PdfLayout_BrushPure* nil)
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
              ((= k "LbdTextHeight") (setq *PdfLayout_LbdTextHeight* (atof v)))
              ((= k "RowTol") (setq *PdfLayout_RowTol* (atoi v)))
              ((= k "GridRows") (setq *PdfLayout_GridRows* (atoi v)))
              ((= k "GridCols") (setq *PdfLayout_GridCols* (atoi v)))
              ((= k "GridRowSp") (setq *PdfLayout_GridRowSp* (atof v)))
              ((= k "GridColSp") (setq *PdfLayout_GridColSp* (atof v)))
              ((= k "GridH") (setq *PdfLayout_GridH* (atof v)))
              ((= k "GridHRatio") (setq *PdfLayout_GridHRatio* (atof v))
                                  ;; 旧默认 0.3 / 0.5 -> 现默认 0.4：老配置里存的旧默认值自动改为 0.4
                                  (if (or (equal *PdfLayout_GridHRatio* 0.3 1e-6)
                                          (equal *PdfLayout_GridHRatio* 0.5 1e-6))
                                    (setq *PdfLayout_GridHRatio* 0.4)))
              ((= k "GridGeom") (setq *PdfLayout_GridGeom* v))
              ((= k "GridHMode") (setq *PdfLayout_GridHMode* v))
              ((= k "GridMT") (setq *PdfLayout_GridMT* (atof v)))
              ((= k "GridMB") (setq *PdfLayout_GridMB* (atof v)))
              ((= k "GridML") (setq *PdfLayout_GridML* (atof v)))
              ((= k "GridMR") (setq *PdfLayout_GridMR* (atof v)))
              ((= k "GridColDir") (setq *PdfLayout_GridColDir* (atoi v)))
              ((= k "GridRowDir") (setq *PdfLayout_GridRowDir* (atoi v)))
              ((= k "GridRot") (setq *PdfLayout_GridRot* (atoi v)))
              ((= k "GridBg") (setq *PdfLayout_GridBg* v))
              ((= k "GridBgColor") (setq *PdfLayout_GridBgColor* (atoi v)))
              ((= k "GridTxtColor") (setq *PdfLayout_GridTxtColor* (atoi v)) (setq *PdfLayout_GridTxtTrue* nil))
              ((= k "GridTxtTrue") (setq *PdfLayout_GridTxtTrue* (= v "1")))
              ((= k "GridTxtRGB") (setq *PdfLayout_GridTxtRGB* (atoi v)))
              ((= k "GridBgScale") (setq *PdfLayout_GridBgScale* (atof v))
                                  (if (> *PdfLayout_GridBgScale* 50)
                                    (setq *PdfLayout_GridBgScale* (/ *PdfLayout_GridBgScale* 100.0))))
              ((= k "GridPrefix") (setq *PdfLayout_GridPrefix* v))
              ((= k "GridStartN") (setq *PdfLayout_GridStartN* (atoi v)))
              ((= k "GridDigits") (setq *PdfLayout_GridDigits* (atoi v)))
              ((= k "GridSrc") (setq *PdfLayout_GridSrc* v))
              ((= k "GridXlsx") (setq *PdfLayout_GridXlsx* v))
              ((= k "GridSheet") (setq *PdfLayout_GridSheetSel* v))

              ((= k "LayRule") (setq *PdfLayout_LayRule* v))
              ((= k "LayLetters") (setq *PdfLayout_LayLetters* v))
              ((= k "LayPerGroup") (setq *PdfLayout_LayPerGroup* (atoi v)))
              ((= k "LayGStart") (setq *PdfLayout_LayGStart* (atoi v)))
              ((= k "LayXlsx") (setq *PdfLayout_LastNamesXlsx* v))
              ((= k "LbdXlsx") (setq *PdfLayout_DlgXlsx* v))
              ((= k "LbdPdf") (setq *PdfLayout_DlgPdf* v))
              ((= k "LbdPage") (setq *PdfLayout_DlgPage* (if (and v (/= v "")) v "0")))
              ((= k "LbdWhere") (setq *PdfLayout_DlgWhere* (if (and v (/= v "")) v "M")))
              ((= k "LbdExcl") (setq *PdfLayout_DlgExcl* (= v "1")))
              ((= k "LbdOrder") (setq *PdfLayout_DlgOrder* (if (and v (/= v "")) v "2")))
              ((= k "LbdSheet") (setq *PdfLayout_LbdSheet* v))
              ((= k "BrushMode") (setq *PdfLayout_BrushMode* (if (= v "2") "2" "1")))
              ((= k "BrushPure") (setq *PdfLayout_BrushPure* (= v "1")))
            )
          )
        )
      )
      (close f)
    )
  )
  (setq *PdfLayout_CurrentProfile* (PdfLayout_OrDefault (PdfLayout_IniGet "LastProfile") ""))
  (PdfLayout_LoadProfiles)
  (PdfLayout_GridLoadProfiles)
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
(if *PdfLayout_DlgXlsx*
  (princ (strcat "LbdXlsx=" *PdfLayout_DlgXlsx*) f)
)
(princ "\n" f)
(if *PdfLayout_DlgPdf* (princ (strcat "LbdPdf=" *PdfLayout_DlgPdf*) f))
(princ "\n" f)
(princ (strcat "LbdPage=" (if *PdfLayout_DlgPage* *PdfLayout_DlgPage* "0")) f)
(princ "\n" f)
(princ (strcat "LbdWhere=" (if *PdfLayout_DlgWhere* *PdfLayout_DlgWhere* "M")) f)
(princ "\n" f)
(princ (strcat "LbdExcl=" (if *PdfLayout_DlgExcl* "1" "0")) f)
(princ "\n" f)
(princ (strcat "LbdOrder=" (if *PdfLayout_DlgOrder* *PdfLayout_DlgOrder* "2")) f)
(princ "\n" f)
(if *PdfLayout_LbdSheet* (princ (strcat "LbdSheet=" *PdfLayout_LbdSheet*) f))
(princ "\n" f)
(princ (strcat "LbdTextHeight=" (rtos *PdfLayout_LbdTextHeight* 2 4)) f)
(princ (strcat "BrushMode=" *PdfLayout_BrushMode*) f)
(princ "\n" f)
(princ (strcat "BrushPure=" (if *PdfLayout_BrushPure* "1" "0")) f)
(princ "\n" f)
(princ "\n" f)
      (princ "\n" f)
      (princ (strcat "GridRows=" (itoa *PdfLayout_GridRows*)) f)
      (princ "\n" f)
      (princ (strcat "GridCols=" (itoa *PdfLayout_GridCols*)) f)
      (princ "\n" f)
      (princ (strcat "GridRowSp=" (rtos *PdfLayout_GridRowSp* 2 2)) f)
      (princ "\n" f)
      (princ (strcat "GridColSp=" (rtos *PdfLayout_GridColSp* 2 2)) f)
      (princ "\n" f)
      (princ (strcat "GridH=" (rtos *PdfLayout_GridH* 2 2)) f)
      (princ "\n" f)
      (princ (strcat "GridHRatio=" (rtos *PdfLayout_GridHRatio* 2 2)) f)
      (princ "\n" f)
      (princ (strcat "GridGeom=" *PdfLayout_GridGeom*) f)
      (princ "\n" f)
      (princ (strcat "GridHMode=" *PdfLayout_GridHMode*) f)
      (princ "\n" f)
      (princ (strcat "GridMT=" (rtos *PdfLayout_GridMT* 2 2)) f)
      (princ "\n" f)
      (princ (strcat "GridMB=" (rtos *PdfLayout_GridMB* 2 2)) f)
      (princ "\n" f)
      (princ (strcat "GridML=" (rtos *PdfLayout_GridML* 2 2)) f)
      (princ "\n" f)
      (princ (strcat "GridMR=" (rtos *PdfLayout_GridMR* 2 2)) f)
      (princ "\n" f)
      (princ (strcat "GridColDir=" (itoa *PdfLayout_GridColDir*)) f)
      (princ "\n" f)
      (princ (strcat "GridRowDir=" (itoa *PdfLayout_GridRowDir*)) f)
      (princ "\n" f)
      (princ (strcat "GridRot=" (itoa *PdfLayout_GridRot*)) f)
      (princ "\n" f)
      (princ (strcat "GridBg=" *PdfLayout_GridBg*) f)
      (princ "\n" f)
      (princ (strcat "GridBgColor=" (itoa *PdfLayout_GridBgColor*)) f)
      (princ "\n" f)
      (princ (strcat "GridTxtColor=" (itoa *PdfLayout_GridTxtColor*)) f)
      (princ "\n" f)
      (princ (strcat "GridTxtTrue=" (if *PdfLayout_GridTxtTrue* "1" "0")) f)
      (princ "\n" f)
      (princ (strcat "GridTxtRGB=" (itoa *PdfLayout_GridTxtRGB*)) f)
      (princ "\n" f)
      (princ (strcat "GridBgScale=" (rtos *PdfLayout_GridBgScale* 2 2)) f)
      (princ "\n" f)
      (princ "\n" f)
      (if *PdfLayout_GridPrefix*
        (princ (strcat "GridPrefix=" *PdfLayout_GridPrefix*) f)
      )
      (princ "\n" f)
      (princ (strcat "GridStartN=" (itoa *PdfLayout_GridStartN*)) f)
      (princ "\n" f)
      (princ (strcat "GridDigits=" (itoa *PdfLayout_GridDigits*)) f)
      (princ (strcat "GridSrc=" *PdfLayout_GridSrc*) f)
      (princ "\n" f)
      (if *PdfLayout_GridXlsx*
        (princ (strcat "GridXlsx=" *PdfLayout_GridXlsx*) f)
      )
      (princ "\n" f)
      (if *PdfLayout_GridSheetSel*
        (princ (strcat "GridSheet=" *PdfLayout_GridSheetSel*) f)
      )
      (princ "\n" f)
      (princ "\n" f)
      (princ (strcat "GridProfileCount=" (itoa (length *PdfLayout_GridProfiles*))) f)
      (princ "\n" f)
      (setq i 1)
      (foreach pf *PdfLayout_GridProfiles*
        (setq pfname (car pf))
        (setq pfdata (cdr pf))
        (princ (strcat "GridProfile" (itoa i) "Name=" pfname) f)
        (princ "\n" f)
        (princ (strcat "GridProfile" (itoa i) "Rows=" (itoa (PdfLayout_OrDefault (PdfLayout_ProfileGet pfdata "Rows") 4))) f)
        (princ "\n" f)
        (princ (strcat "GridProfile" (itoa i) "Cols=" (itoa (PdfLayout_OrDefault (PdfLayout_ProfileGet pfdata "Cols") 5))) f)
        (princ "\n" f)
        (princ (strcat "GridProfile" (itoa i) "RowSp=" (rtos (PdfLayout_OrDefault (PdfLayout_ProfileGet pfdata "RowSp") 10.0) 2 2)) f)
        (princ "\n" f)
        (princ (strcat "GridProfile" (itoa i) "ColSp=" (rtos (PdfLayout_OrDefault (PdfLayout_ProfileGet pfdata "ColSp") 20.0) 2 2)) f)
        (princ "\n" f)
        (princ (strcat "GridProfile" (itoa i) "H=" (rtos (PdfLayout_OrDefault (PdfLayout_ProfileGet pfdata "H") 0.5) 2 2)) f)
        (princ "\n" f)
        (princ (strcat "GridProfile" (itoa i) "HRatio=" (rtos (PdfLayout_OrDefault (PdfLayout_ProfileGet pfdata "HRatio") 0.4) 2 2)) f)
        (princ "\n" f)
        (princ (strcat "GridProfile" (itoa i) "Geom=" (PdfLayout_OrDefault (PdfLayout_ProfileGet pfdata "Geom") "1")) f)
        (princ "\n" f)
        (princ (strcat "GridProfile" (itoa i) "HMode=" (PdfLayout_OrDefault (PdfLayout_ProfileGet pfdata "HMode") "auto")) f)
        (princ "\n" f)
        (princ (strcat "GridProfile" (itoa i) "MT=" (rtos (PdfLayout_OrDefault (PdfLayout_ProfileGet pfdata "MT") 0.0) 2 2)) f)
        (princ "\n" f)
        (princ (strcat "GridProfile" (itoa i) "MB=" (rtos (PdfLayout_OrDefault (PdfLayout_ProfileGet pfdata "MB") 0.0) 2 2)) f)
        (princ "\n" f)
        (princ (strcat "GridProfile" (itoa i) "ML=" (rtos (PdfLayout_OrDefault (PdfLayout_ProfileGet pfdata "ML") 0.0) 2 2)) f)
        (princ "\n" f)
        (princ (strcat "GridProfile" (itoa i) "MR=" (rtos (PdfLayout_OrDefault (PdfLayout_ProfileGet pfdata "MR") 0.0) 2 2)) f)
        (princ "\n" f)
        (princ (strcat "GridProfile" (itoa i) "ColDir=" (itoa (PdfLayout_OrDefault (PdfLayout_ProfileGet pfdata "ColDir") 1))) f)
        (princ "\n" f)
        (princ (strcat "GridProfile" (itoa i) "RowDir=" (itoa (PdfLayout_OrDefault (PdfLayout_ProfileGet pfdata "RowDir") -1))) f)
        (princ "\n" f)
        (princ (strcat "GridProfile" (itoa i) "Rot=" (itoa (PdfLayout_OrDefault (PdfLayout_ProfileGet pfdata "Rot") 0))) f)
        (princ "\n" f)
        (princ (strcat "GridProfile" (itoa i) "Bg=" (PdfLayout_OrDefault (PdfLayout_ProfileGet pfdata "Bg") "fill")) f)
        (princ "\n" f)
        (princ (strcat "GridProfile" (itoa i) "BgColor=" (itoa (PdfLayout_OrDefault (PdfLayout_ProfileGet pfdata "BgColor") 1))) f)
        (princ "\n" f)
        (princ (strcat "GridProfile" (itoa i) "TxtColor=" (itoa (PdfLayout_OrDefault (PdfLayout_ProfileGet pfdata "TxtColor") 7))) f)
        (princ "\n" f)
        (princ (strcat "GridProfile" (itoa i) "TxtTrue=" (PdfLayout_OrDefault (PdfLayout_ProfileGet pfdata "TxtTrue") "0")) f)
        (princ "\n" f)
        (princ (strcat "GridProfile" (itoa i) "TxtRGB=" (itoa (PdfLayout_OrDefault (PdfLayout_ProfileGet pfdata "TxtRGB") 0))) f)
        (princ "\n" f)
        (princ (strcat "GridProfile" (itoa i) "BgScale=" (rtos (PdfLayout_OrDefault (PdfLayout_ProfileGet pfdata "BgScale") 1.0) 2 2)) f)
        (princ "\n" f)
        (princ "\n" f)
        (princ (strcat "GridProfile" (itoa i) "Prefix=" (PdfLayout_OrDefault (PdfLayout_ProfileGet pfdata "Prefix") "CIR")) f)
        (princ "\n" f)
        (princ (strcat "GridProfile" (itoa i) "StartN=" (itoa (PdfLayout_OrDefault (PdfLayout_ProfileGet pfdata "StartN") 1))) f)
        (princ "\n" f)
        (princ (strcat "GridProfile" (itoa i) "Digits=" (itoa (PdfLayout_OrDefault (PdfLayout_ProfileGet pfdata "Digits") 2))) f)
        (princ "\n" f)
        (princ (strcat "GridProfile" (itoa i) "Order=" (PdfLayout_OrDefault (PdfLayout_ProfileGet pfdata "Order") "1")) f)
        (princ "\n" f)
        (setq i (1+ i))
      )
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
;;;-------------------------------------------------------------
;;;-------------------------------------------------------------
(defun PdfLayout_ModelToPaper (vp modelPt / ent ed vpc vc vh bb pmin pmax ph scale)
  ;; 用视口实体 DXF 数据换算：10=纸张中心 12=视图中心(模型点) 40=视图高度
  ;; 避免 ZWCAD 缺少 vla-get-ViewHeight / ViewCenter 接口的问题
  (setq ent (vlax-vla-object->ename vp))
  (setq ed (entget ent))
  (setq vpc (cdr (assoc 10 ed)))
  (setq vc (cdr (assoc 12 ed)))
  (setq vh (cdr (assoc 40 ed)))
  (setq bb (PdfLayout_GetExtentsSafeObj vp))
  (if (and vpc vc vh bb (> vh 0.0))
    (progn
      (setq pmin (car bb) pmax (cadr bb))
      (setq ph (- (cadr pmax) (cadr pmin)))
      (if (> ph 0.0)
        (progn
          (setq scale (/ ph vh))
          (list (+ (car vpc) (* (- (car modelPt) (car vc)) scale))
                (+ (cadr vpc) (* (- (cadr modelPt) (cadr vc)) scale))
                0.0)
        )
        nil
      )
    )
    nil
  )
)
(defun PdfLayout_LayoutBiggestVp (layout / blk obj bb best vp area)
  (setq blk (vla-get-Block layout))
  (setq best nil vp nil)
  (vlax-for obj blk
    (if (= (vla-get-ObjectName obj) "AcDbViewport")
      (progn
        (setq bb (PdfLayout_GetExtentsSafeObj obj))
        (if bb
          (progn
            (setq area (* (- (car (cadr bb)) (car (car bb)))
                          (- (cadr (cadr bb)) (cadr (car bb)))))
            (if (or (not best) (> area best))
              (setq best area vp obj)
            )
          )
        )
      )
    )
  )
  vp
)
(defun PdfLayout_PaperToModel (vp paperPt / ent ed vpc vc vh bb ph scale)
  ;; 纸张坐标 -> 模型坐标（视口 DXF 换算，兼容 ZWCAD）
  (setq ent (vlax-vla-object->ename vp))
  (setq ed (entget ent))
  (setq vpc (cdr (assoc 10 ed)))
  (setq vc (cdr (assoc 12 ed)))
  (setq vh (cdr (assoc 40 ed)))
  (setq bb (PdfLayout_GetExtentsSafeObj vp))
  (if (and vpc vc vh bb (> vh 0.0))
    (progn
      (setq ph (- (cadr (cadr bb)) (cadr (car bb))))
      (if (> ph 0.0)
        (progn
          (setq scale (/ ph vh))
          (list (+ (car vc) (/ (- (car paperPt) (car vpc)) scale))
                (+ (cadr vc) (/ (- (cadr paperPt) (cadr vpc)) scale))
                0.0)
        )
        nil
      )
    )
    nil
  )
)
(defun PdfLayout_PtInRect (pt rect)
  ;; 点是否在矩形内（rect = (xmin ymin xmax ymax)）
  (and rect
       (<= (car rect) (car pt) (caddr rect))
       (<= (cadr rect) (cadr pt) (cadddr rect)))
)
(defun PdfLayout_MTextRedWhite (obj / ename ed)
  ;; 红底白字 + 背景贴合文字：用 DXF 直接设置，兼容 ZWCAD（无 BackgroundFillColor 接口）
  (setq ename (if (= (type obj) 'VLA-OBJECT)
                (vlax-vla-object->ename obj)
                obj))
  (setq ed (entget ename))
  (if (assoc 45 ed) (setq ed (subst (cons 45 1) (assoc 45 ed) ed)) (setq ed (append ed (list (cons 45 1)))))
  (if (assoc 63 ed) (setq ed (subst (cons 63 1) (assoc 63 ed) ed)) (setq ed (append ed (list (cons 63 1)))))
  (if (assoc 421 ed) (setq ed (vl-remove (assoc 421 ed) ed)))
  (if (assoc 90 ed) (setq ed (subst (cons 90 1.0) (assoc 90 ed) ed)) (setq ed (append ed (list (cons 90 1.0)))))
  (entmod ed)
)
(defun PdfLayout_LbdNumFromText (s / pos i c seg nums stripped ok)
  ;; 从文字里提取 LBD 层级编号：
  ;;   "INV01A01-LBD-14.1.2" -> (14 1 2)、"LBD-14" -> (14)、"14" -> (14)
  ;;   "14.1.2" -> (14 1 2)、"1.0" -> (1)；找不到或纯数字格式不合法返回 nil
  (if (null s) (setq s ""))
  (setq s (vl-string-trim " " s))
  (setq pos (vl-string-search "LBD" (strcase s)))
  (if pos
    (progn
      ;; ---- 带 LBD 前缀：从 LBD 后取数字段(可带 "." 分隔) ----
      (setq i (+ pos 3) seg "" nums nil)
      (while (and (<= i (strlen s)) (/= (PdfLayout_CharKind (substr s i 1)) "D"))
        (setq i (1+ i))
      )
      (while (and (<= i (strlen s)))
        (setq c (substr s i 1))
        (if (= (PdfLayout_CharKind c) "D")
          (progn
            (setq seg (strcat seg c))
            (setq i (1+ i))
          )
          (if (and (= c ".") (/= seg "") (< i (strlen s))
                   (= (PdfLayout_CharKind (substr s (1+ i) 1)) "D"))
            (progn
              (setq nums (append nums (list (atoi seg))))
              (setq seg "")
              (setq i (1+ i))
            )
            (setq i (+ (strlen s) 1))
          )
        )
      )
      (if (/= seg "") (setq nums (append nums (list (atoi seg)))))
      (if nums nums nil)
    )
    (progn
      ;; ---- 无 LBD 前缀：整串须为纯数字/点(如 "123"、"14.1.2")，并去除 Excel 数字常带的尾部 ".0" ----
      (setq stripped s)
      (while (and (> (strlen stripped) 2)
                  (= (substr stripped (- (strlen stripped) 1) 2) ".0"))
        (setq stripped (substr stripped 1 (- (strlen stripped) 2)))
      )
      (setq nums nil seg "" i 1 ok T)
      (while (and ok (<= i (strlen stripped)))
        (setq c (substr stripped i 1))
        (cond
          ((= (PdfLayout_CharKind c) "D")
            (setq seg (strcat seg c))
          )
          ((and (= c ".") (/= seg "") (< i (strlen stripped))
                (= (PdfLayout_CharKind (substr stripped (1+ i) 1)) "D"))
            (setq nums (append nums (list (atoi seg))))
            (setq seg "")
          )
          (t (setq ok nil))
        )
        (setq i (1+ i))
      )
      (if ok
        (progn
          (if (/= seg "") (setq nums (append nums (list (atoi seg)))))
          (if nums nums nil)
        )
        nil
      )
    )
  )
)
(defun PdfLayout_LbdNumToStr (k / out)
  ;; (14 1 2) -> "14.1.2"；(14) -> "14"
  (setq out "")
  (foreach n k
    (setq out (if (= out "") (itoa n) (strcat out "." (itoa n))))
  )
  out
)
(defun PdfLayout_CmpLbdNumAsc (a b / la lb n i)
  ;; 层级数字比较：逐段比大小，段相同且前段一致则短者小，如 (14) < (14 1)
  (setq la (car a) lb (car b) n (min (length la) (length lb)) i 0)
  (while (and (< i n) (= (nth i la) (nth i lb)))
    (setq i (1+ i))
  )
  (if (< i n)
    (< (nth i la) (nth i lb))
    (< (length la) (length lb))
  )
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
(defun PdfLayout_HdrHit (cell keys / u)
  ;; 表头单元格是否含任一关键字(不区分大小写)，命中返回下标，否则 nil
  (if (null cell)
    nil
    (progn
      (setq u (strcase cell))
      (vl-some '(lambda (k) (vl-string-search (strcase k) u)) keys)
    )
  )
)
(defun PdfLayout_ScanHdr (row keys / i)
  ;; 行中第一个命中关键字的列下标，找不到返回 nil
  (setq i 0)
  (while (and (< i (length row)) (not (PdfLayout_HdrHit (nth i row) keys)))
    (setq i (1+ i))
  )
  (if (< i (length row)) i nil)
)
(defun PdfLayout_RowHasLbdNum (row / i h)
  ;; 行里是否含 LBD 编号(任一格可解析为编号)
  (setq i 0 h nil)
  (while (and (null h) (< i (length row)))
    (if (PdfLayout_LbdNumFromText (nth i row)) (setq h T))
    (setq i (1+ i))
  )
  h
)

(defun PdfLayout_LbdIsCode (s / i c n ok)
  ;; 是否为纯大写字母/数字代码，如 "LEW"/"LCD" 返回 T；"Lynx"/"Item Code" 返回 nil
  (if (null s)
    nil
    (progn
      (setq s (vl-string-trim " " s))
      (setq n (strlen s) i 1 ok T)
      (if (= n 0) (setq ok nil))
      (while (and ok (<= i n))
        (setq c (substr s i 1))
        (cond
          ((and (>= (ascii c) 65) (<= (ascii c) 90)) (setq i (1+ i)))
          ((and (>= (ascii c) 48) (<= (ascii c) 57)) (setq i (1+ i)))
          (t (setq ok nil))
        )
      )
      ok
    )
  )
)

(defun PdfLayout_LbdFindCol (row / h)
  ;; 表头识别 LBD 编号列：优先含 LBD，其次 编号/编码
  (setq h (PdfLayout_ScanHdr row '("LBD")))
  (if h h (PdfLayout_ScanHdr row '("编号" "编码" "編號" "編碼")))
)
(defun PdfLayout_LbdFindLabelCol (row idxL / h i)
  ;; 表头识别标签列：关键词优先；找不到则取 LBD 列之后第一个非空列(idxL 未知时不猜)
  (setq h (PdfLayout_ScanHdr row '("标签" "標籤" "名称" "名稱" "标注" "標註" "内容" "內容" "item" "code" "text" "描述")))
  (if h
    h
    (if (and idxL (>= idxL 0))
      (progn
        (setq i (1+ idxL))
        (while (and (< i (length row)) (= (nth i row) ""))
          (setq i (1+ i))
        )
        (if (< i (length row)) i nil)
      )
      nil
    )
  )
)

(defun PdfLayout_ReadAllLbdLabels (path / xl wbs wb shs out i sh sheet ur vals arr shCount rng hadExcel curLbd
                                   rows map lbd lab cur labels kv headRow idxL idxT dataRows)
  ;; 一次读取 Excel 所有分表：返回 ((分表名 . ((LBD编号 . "标签A/标签B") ...)) ...)
  (setq out nil)
  (setq hadExcel (vl-catch-all-apply 'vlax-get-object (list "Excel.Application")))
  (setq hadExcel (and hadExcel (not (vl-catch-all-error-p hadExcel))))
  (setq xl (vl-catch-all-apply 'vlax-create-object (list "Excel.Application")))
  (if (and xl (not (vl-catch-all-error-p xl)))
    (progn
      (vl-catch-all-apply 'vlax-put-property (list xl 'Visible 0))
      (vl-catch-all-apply 'vlax-put-property (list xl 'DisplayAlerts 0))
      (vl-catch-all-apply 'vlax-put-property (list xl 'AskToUpdateLinks 0))
      (vl-catch-all-apply 'vlax-put-property (list xl 'AutomationSecurity 3))
      (setq wbs (vl-catch-all-apply 'vlax-get-property (list xl 'Workbooks)))
      (setq wb (vl-catch-all-apply 'vlax-invoke-method (list wbs 'Open path 0 1)))
      (if (and wb (not (vl-catch-all-error-p wb)))
        (progn
          (setq shs (vl-catch-all-apply 'vlax-get-property (list wb 'Sheets)))
          (if (and shs (not (vl-catch-all-error-p shs)))
            (progn
              (setq i 1)
              (setq shCount (if (and shs (not (vl-catch-all-error-p shs)))
                              (vlax-get-property shs 'Count) 0))
              (while (<= i shCount)
                (setq sh (vl-catch-all-apply 'vlax-get-property (list shs 'Item i)))
                (if (not (vl-catch-all-error-p sh))
                  (progn
                    (setq sheet (vlax-get-property sh 'Name))
                    (princ (strcat "\n  读取分表 " (itoa i) "/" (itoa shCount) " ..."))
                    ;; 用使用区域读取（ZWCAD 兼容；空表 .Value 可能返回 nil，需判空）
                    (setq ur (vl-catch-all-apply 'vlax-get-property (list sh 'UsedRange)))
                    (setq vals (if (and ur (not (vl-catch-all-error-p ur)))
                                 (vl-catch-all-apply 'vlax-get-property (list ur 'Value))
                                 nil))
                    (setq map nil curLbd nil)
                    (if (and vals (not (vl-catch-all-error-p vals)))
                          (progn
                            (setq arr (vlax-variant-value vals))
                            (setq rows (vlax-safearray->list arr))
                                                        (if (and rows (not (listp (car rows)))) (setq rows (list rows)))
(setq rows (mapcar '(lambda (r) (mapcar 'PdfLayout_CellStr r)) rows))
                            (setq headRow nil idxL nil idxT nil dataRows rows)
                            (if (and rows (listp (car rows)))
                              (progn
                                (setq headRow (car rows))
                                (setq idxL (PdfLayout_LbdFindCol headRow))
                                (if idxL (setq idxT (PdfLayout_LbdFindLabelCol headRow idxL)))
                                (if (not idxT) (setq idxT (PdfLayout_LbdFindLabelCol headRow nil)))
                                ;; 首行视为表头跳过；其后只有整行没有 LBD 编号的表头/标题行才继续跳过
                                (setq dataRows (cdr rows))
                                (while (and dataRows (not (PdfLayout_RowHasLbdNum (car dataRows))))
                                  (setq dataRows (cdr dataRows))
                                )
                              )
                            )
                            (if (not idxL) (setq idxL 0))
                            (if (not idxT) (setq idxT 2))
                            (foreach r dataRows
                              ;; 标签取识别到的标签列；识别到 LBD 列为空的续行(负极)归入上一个 LBD
                              (setq lbd (if (< idxL (length r)) (nth idxL r) "") lab (if (< idxT (length r)) (nth idxT r) ""))
                              (if (and lab (/= lab ""))
                                (progn
                                  (if (and lbd (/= lbd "") (PdfLayout_LbdNumFromText lbd))
                                    (setq n0 (PdfLayout_LbdNumFromText lbd) curLbd n0)
                                    (setq n0 curLbd)
                                  )
                                  (if n0
                                    (progn
                                      (setq cur (assoc n0 map))
                                      (if cur
                                        (setq map (subst (cons n0 (append (cdr cur) (list lab))) cur map))
                                        (setq map (append map (list (cons n0 (list lab)))))
                                      )
                                    )
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
                (setq i (1+ i))
              )
            )
          )
          (vl-catch-all-apply 'vlax-invoke-method (list wb 'Close 0))
        )
      )
      ;; 释放 Excel 的 COM 引用并退出不再需要的后台实例，避免读取表格后 Excel 挂在后台
      (PdfLayout_ExcelCleanup xl hadExcel (list shs sh ur wb wbs))
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
(defun PdfLayout_LbdDialogInit ()
  (setq *PdfLayout_DlgH* *PdfLayout_LbdTextHeight*)
  (set_tile "lbd_pdf" *PdfLayout_DlgPdf*)
  (set_tile "lbd_xlsx" *PdfLayout_DlgXlsx*)
  (set_tile "lbd_page" *PdfLayout_DlgPage*)
  (set_tile "lbd_h" (rtos *PdfLayout_DlgH* 2 4))
  (if (= *PdfLayout_DlgWhere* "L")
    (set_tile "lbd_l" "1")
    (if (= *PdfLayout_DlgWhere* "B")
      (set_tile "lbd_b" "1")
      (set_tile "lbd_m" "1")
    )
  )
  (if *PdfLayout_DlgExcl* (set_tile "lbd_excl" "1"))
)
(defun PdfLayout_LbdDialogPick (key / f dft flt)
  ;; 默认打开桌面目录；Excel/PDF 用各自的扩展名过滤；记住上次路径
  (setq dft (get_tile key))
  (if (or (not dft) (= dft ""))
    (setq dft (strcat (getenv "USERPROFILE") "\\Desktop"))
  )
  (setq flt (if (= key "lbd_pdf") "pdf" "xlsx;xls"))
  (setq f (getfiled "选择文件" dft flt 4))
  (if f (set_tile key f))
)
(defun PdfLayout_LbdDialogAccept ()
  (setq *PdfLayout_DlgPdf* (get_tile "lbd_pdf"))
  (setq *PdfLayout_DlgXlsx* (get_tile "lbd_xlsx"))
  (setq *PdfLayout_DlgPage* (get_tile "lbd_page"))
  (setq *PdfLayout_DlgH* (atof (get_tile "lbd_h")))
  (if (< *PdfLayout_DlgH* 0.001) (setq *PdfLayout_DlgH* 0.05))
  (setq *PdfLayout_DlgWhere*
    (if (= (get_tile "lbd_l") "1") "L"
      (if (= (get_tile "lbd_b") "1") "B" "M")))
  (setq *PdfLayout_DlgExcl* (= (get_tile "lbd_excl") "1"))
  (setq *PdfLayout_DlgMode* "auto")
  (if (or (not *PdfLayout_DlgPdf*) (= *PdfLayout_DlgPdf* ""))
    (alert "请选择 PDF 文件。")
    (done_dialog 1)
  )
)



(defun PdfLayout_LbdDialogPreview (/ lines1 lines2 i m sorted)
  ;; 按 LBD 号显示匹配：左侧 LBD 号，右侧标签（未匹配标出）
  (setq lines1 nil lines2 nil i 0)
  (setq sorted (vl-sort *PdfLayout_LbdSelMatches*
                '(lambda (a b)
                   (if (and (cadr a) (cadr b))
                     (< (cadr a) (cadr b))
                     (if (cadr a) T nil)))))
  (foreach m sorted
    (setq lines1 (append lines1
      (list (strcat (itoa (1+ i)) ": LBD-"
                    (if (cadr m) (itoa (cadr m)) "?")))))
    (setq lines2 (append lines2 (list (if (caddr m) (caddr m) "（未找到）"))))
    (setq i (1+ i))
  )
  (PdfLayout_SetList "lbd_grid" lines1)
  (PdfLayout_SetList "lbd_names" lines2)
  (set_tile "lbd_pv_info"
    (strcat "共 " (itoa (length *PdfLayout_LbdSelMatches*))
            " 个，已匹配 "
            (itoa (length (vl-remove-if-not '(lambda (x) (caddr x))
                                            *PdfLayout_LbdSelMatches*)))
            " 个"))
)

(defun PdfLayout_LbdShowDialog (/ dclId dlgRes)
  ;; 显示 PDFLBD 主弹窗；手动模式第二次打开时预览选中文字
  (setq dclId (load_dialog (PdfLayout_FindDcl)))
  (if (and dclId (not (minusp dclId)))
    (progn
      (if (new_dialog "PdfLbd" dclId)
        (progn
          (PdfLayout_LbdDialogInit)
          (action_tile "btn_pdf" "(PdfLayout_LbdDialogPick \"lbd_pdf\")")
          (action_tile "btn_xlsx" "(PdfLayout_LbdDialogPick \"lbd_xlsx\")")
          (action_tile "accept" "(PdfLayout_LbdDialogAccept)")
          (action_tile "cancel" "(done_dialog 0)")
          (setq dlgRes (start_dialog))
          (unload_dialog dclId)
          (= dlgRes 1)
        )
        (progn
          (unload_dialog dclId)
          nil
        )
      )
    )
    nil
  )
)



(defun PdfLayout_LbdManualRun (/ ss en bb i done kv sorted res)
  ;; 手动导入：框选文字可选 -> 弹窗(选Excel+排序+预览/点手动摆放) -> 按顺序填写 或 逐张挑点摆放
  (setq *PdfLayout_LbdManualLabels* nil)
  (princ "\n[可选择] 框选要填写的多行文字(MTEXT)，直接回车=仅手动摆放：")
  (setq ss (ssget '((0 . "MTEXT"))))
  (setq *PdfLayout_LbdSelPairs* nil)
  (if ss
    (progn
      (setq i 0)
      (while (setq en (ssname ss i))
        (setq bb (PdfLayout_GetExtentsSafeObj (vlax-ename->vla-object en)))
        (if bb
          (setq *PdfLayout_LbdSelPairs*
                (append *PdfLayout_LbdSelPairs* (list (cons en bb)))))
        (setq i (1+ i))
      )
    )
  )
  (setq res (PdfLayout_LbdManualShow))
  (cond
    ((= res 2)
      (PdfLayout_LbdManualPlacedRun))
    ((= res 1)
      (if *PdfLayout_LbdSelPairs*
        (progn
          (setq sorted (PdfLayout_SortPairsSmart *PdfLayout_LbdSelPairs* *PdfLayout_DlgOrder*))
          (setq done 0 i 0)
          (foreach pair sorted
            (setq kv (nth i *PdfLayout_LbdManualLabels*))
            (if kv
              (progn
                (vl-catch-all-apply 'vla-put-TextString
                  (list (vlax-ename->vla-object (car pair)) (cdr kv)))
                (setq done (1+ done))
              )
            )
            (setq i (1+ i))
          )
          (princ (strcat "\n手动导入完成：按LBD顺序填写 " (itoa done) " 个。"))
          (alert (strcat "手动导入完成\n\n已按 Excel LBD 顺序填写 " (itoa done) " 个"
                         (if (< done (length *PdfLayout_LbdSelPairs*))
                           "\n（所选文字多于标签，多余保持不变）" "")))
        )
        (alert "未选中任何文字，无法按顺序填写；请先框选要填写的多行文字，或点"手动摆放"逐张挑点。")
      )
    )
    (t (princ "\n已取消"))
  )
  (princ)
)
(defun PdfLayout_LbdManualPick (/ f)
  ;; 默认先用上次记忆的路径，没有才回桌面
  (setq f (getfiled "选择标签Excel(分表名=布局名)"
                    (if (and *PdfLayout_DlgXlsx* (/= *PdfLayout_DlgXlsx* ""))
                      *PdfLayout_DlgXlsx*
                      (strcat (getenv "USERPROFILE") "\\Desktop"))
                    "xlsx;xls" 4))
  (if f
    (progn
      (set_tile "lm_xlsx" f)
      (setq *PdfLayout_DlgXlsx* f)
      (PdfLayout_LbdManualLoadXlsx f)
    )
  )
)

(defun PdfLayout_LbdManualLoadXlsx (path / sheetMap sh)
  ;; 读 Excel：取当前布局分表（或第一个），按 LBD 号升序得到标签列表
  (setq *PdfLayout_LbdManualLabels* nil)
  (if (and path (/= path ""))
    (progn
      (setq *PdfLayout_DlgXlsx* path)
      (PdfLayout_SaveSettings)
      (setq sheetMap (PdfLayout_ReadAllLbdLabels path))
      (setq sh (if sheetMap
                 (assoc (vla-get-Name (vla-get-ActiveLayout (vla-get-ActiveDocument (vlax-get-Acad-Object)))) sheetMap)
                 nil))
      (if (not sh) (setq sh (if (and *PdfLayout_LbdSheet* (assoc *PdfLayout_LbdSheet* sheetMap)) (assoc *PdfLayout_LbdSheet* sheetMap) nil)))
      (if (not sh) (setq sh (if sheetMap (car sheetMap) nil)))
      (if sh (setq *PdfLayout_LbdSheet* (car sh)))
      (if sh
        (setq *PdfLayout_LbdManualLabels*
              (PdfLayout_StableSort (cdr sh) 'PdfLayout_CmpLbdNumAsc))
      )
    )
  )
  (PdfLayout_LbdManualPreview)
  (if *PdfLayout_LbdManualLabels* T nil)
)

(defun PdfLayout_LbdManualOrder ()
  (itoa (1+ (PdfLayout_GetTileInt "lm_order" 1)))
)

(defun PdfLayout_LbdManualPreview (/ order rowTol sorted lines1 lines2 i kv pair txt0)
  ;; 左列：按所选顺序排序后的文字序号+内容；右列：按 Excel LBD 号升序的标签
  (setq order (PdfLayout_LbdManualOrder))
  (setq rowTol (max 1 (min 50 (PdfLayout_GetTileInt "lm_rowtol" 10))))
  (setq *PdfLayout_DlgOrder* order)
  (setq *PdfLayout_RowTol* rowTol)
  (setq sorted (PdfLayout_SortPairsSmart *PdfLayout_LbdSelPairs* order))
  (setq lines1 nil lines2 nil i 1)
  (foreach pair sorted
    (setq txt0 (vl-catch-all-apply 'vla-get-TextString
                 (list (vlax-ename->vla-object (car pair)))))
    (if (or (not txt0) (vl-catch-all-error-p txt0)) (setq txt0 ""))
    (setq lines1 (append lines1 (list (strcat (itoa i) ": " (substr txt0 1 22)))))
    (setq i (1+ i))
  )
  (setq i 1)
  (foreach kv *PdfLayout_LbdManualLabels*
    (setq lines2 (append lines2 (list (strcat "LBD-" (PdfLayout_LbdNumToStr (car kv)) ": " (cdr kv)))))
    (setq i (1+ i))
  )
  (PdfLayout_SetList "lm_grid" lines1)
  (PdfLayout_SetList "lm_names" lines2)
  (set_tile "lm_info"
    (strcat "选中文字 " (itoa (length *PdfLayout_LbdSelPairs*))
            " 个，标签 " (itoa (length *PdfLayout_LbdManualLabels*))
            " 个；顺序: " (PdfLayout_OrderDesc order)))
)

(defun PdfLayout_LbdManualShow (/ dclId dlgRes dclPath)
  (setq dclPath (PdfLayout_FindDcl))
  (if (not (findfile dclPath))
    (progn
      (alert "无法生成 PdfLayout.dcl，手动导入弹窗无法打开。")
      nil
    )
    (progn
      (setq dclId (load_dialog dclPath))
      (if (and dclId (not (minusp dclId)))
        (progn
          (if (new_dialog "PdfLbdManual" dclId)
            (progn
              (PdfLayout_SetList "lm_order"
                '("1 列优先: 左→右列、列内上→下"
                  "2 行优先: 上→下行、行内左→右"
                  "3 列优先: 右→左列、列内上→下"
                  "4 行优先: 下→上行、行内左→右"
                  "5 列优先: 左→右列、列内下→上"
                  "6 列优先: 右→左列、列内下→上"
                  "7 行优先: 上→下行、行内右→左"
                  "8 行优先: 下→上行、行内右→左"))
              (set_tile "lm_order" (itoa (- (atoi *PdfLayout_DlgOrder*) 1)))
              (set_tile "lm_rowtol" (itoa (if (and *PdfLayout_RowTol* (> *PdfLayout_RowTol* 0))
                                            *PdfLayout_RowTol* 10)))
              (set_tile "lm_xlsx" (if *PdfLayout_DlgXlsx* *PdfLayout_DlgXlsx* ""))
              (if (and *PdfLayout_DlgXlsx* (/= *PdfLayout_DlgXlsx* ""))
                (PdfLayout_LbdManualLoadXlsx *PdfLayout_DlgXlsx*))
              (PdfLayout_LbdManualPreview)
              (action_tile "lm_btnxlsx" "(PdfLayout_LbdManualPick)")
              (action_tile "lm_btnxlsxre" "(PdfLayout_LbdManualLoadXlsx (get_tile \"lm_xlsx\"))")
              (action_tile "lm_xlsx" "(PdfLayout_LbdManualLoadXlsx (get_tile \"lm_xlsx\"))")
              (action_tile "lm_order" "(PdfLayout_LbdManualPreview)")
              (action_tile "lm_rowtol" "(PdfLayout_LbdManualPreview)")
              (action_tile "accept" "(PdfLayout_LbdManualAccept)")
              (action_tile "lm_place" "(done_dialog 2)")
              (action_tile "cancel" "(done_dialog 0)")
              (setq dlgRes (start_dialog))
              (unload_dialog dclId)
              dlgRes
            )
            (progn
              (unload_dialog dclId)
              (alert "无法打开 PdfLbdManual 对话框。")
              nil
            )
          )
        )
        nil
      )
    )
  )
)

(defun PdfLayout_LbdManualAccept ()
  (setq *PdfLayout_DlgOrder* (PdfLayout_LbdManualOrder))
  (setq *PdfLayout_RowTol* (max 1 (min 50 (PdfLayout_GetTileInt "lm_rowtol" 10))))
  (PdfLayout_SaveSettings)
  (if *PdfLayout_LbdManualLabels*
    (done_dialog 1)
    (alert "请先选择标签 Excel 文件。")
  )
)

(defun PdfLayout_LbdCopyAppearance (refE newE / refEd newEd grp entry)
  ;; 把参考 MTEXT 的外观（字高/文字样式/颜色/背景/对齐）复制到 newE，保证新建标签与已有标签一致
  (setq refEd (entget refE))
  (setq newEd (entget newE))
  (foreach grp '(7 40 62 420 45 63 421 90 71 72 73)
    (setq entry (assoc grp refEd))
    (if entry
      (progn
        (if (assoc grp newEd)
          (setq newEd (subst entry (assoc grp newEd) newEd))
          (setq newEd (append newEd (list entry)))
        )
      )
    )
  )
  (entmod newEd)
  (entupd newE)
  newE
)


(defun PdfLayout_MoveMTextFast (en p / ed)
  ;; 快速移动预览 MTEXT：直接用 entmod 改插入点，避免每帧 COM vla-Move 导致拖动卡顿
  (setq ed (entget en))
  (if (and ed (assoc 10 ed))
    (progn
      (entmod (subst (cons 10 (list (car p) (cadr p) (if (and (caddr p) (> (caddr p) 0.0)) (caddr p) 0.0))) (assoc 10 ed) ed))
      (redraw en)
    )
  )
)


(defun PdfLayout_LbdMakePreview (space p tw txt refE hgt / pv)
  ;; 新建预览 MTEXT：锚点左上，字高/宽度/外观与最终标签一致
  (setq pv (vl-catch-all-apply 'vla-AddMText (list space (vlax-3d-point p) tw txt)))
  (if (vl-catch-all-error-p pv) (setq pv nil))
  (if pv
    (progn
      (vl-catch-all-apply 'vla-put-Width (list pv tw))
      (if refE
        (vl-catch-all-apply 'PdfLayout_LbdCopyAppearance (list refE (vlax-vla-object->ename pv)))
        (progn
          (vl-catch-all-apply 'vla-put-Height (list pv hgt))
          (vl-catch-all-apply 'PdfLayout_MTextRedWhite (list pv))
        )
      )
      (vl-catch-all-apply 'vla-put-AttachmentPoint (list pv 1))
    )
  )
  pv
)

(defun PdfLayout_NowMs (/ v)
  ;; 毫秒计时（过滤同一次点击的重复事件）；取不到 MILLISECS 时退回“当天毫秒”
  (setq v (vl-catch-all-apply 'getvar (list "MILLISECS")))
  (if (or (vl-catch-all-error-p v) (not (numberp v)))
    (setq v (fix (* 86400000.0 (rem (getvar "CDATE") 1.0))))
  )
  v
)

(defun PdfLayout_LbdManualPlacedRun (/ xlPath sheetMap sh labels kv i cnt done skipped txt hgt space os
                                        refE refSel refEn refObj refH tw res gr code val ptraw ptx
                                        baseRef moved lastMs abort pv pve oldss running j e hit regen)
  ;; 手动摆放：弹窗里已识别的 LBD 标签直接复用；逐个挑点写入/覆盖 MTEXT
  ;;  · 移动鼠标实时预览；正交(F8)实时生效，参照物=上一次落点
  ;;  · 左键放入；回车 = 跳过当前；Esc = 结束整个摆放
  ;;  · 同一次点击（含双击）在部分 CAD 会连发两次按键事件，第二次会被忽略，避免一次点击落下两个标签
  (vl-load-com)
  (setq labels nil)
  (if (and *PdfLayout_LbdManualLabels* (> (length *PdfLayout_LbdManualLabels*) 0))
    (setq labels *PdfLayout_LbdManualLabels*)
    (progn
      (setq xlPath (getfiled "选择标签Excel(每页标签=模型名,可选)"
                             (if (and *PdfLayout_DlgXlsx* (/= *PdfLayout_DlgXlsx* ""))
                               *PdfLayout_DlgXlsx*
                               (strcat (getenv "USERPROFILE") "\\Desktop"))
                             "xlsx;xls" 4))
      (if xlPath
        (progn
          (setq *PdfLayout_DlgXlsx* xlPath)
          (PdfLayout_SaveSettings)
          (setq sheetMap (PdfLayout_ReadAllLbdLabels xlPath))
          (setq sh (if sheetMap
                       (assoc (vla-get-Name (vla-get-ActiveLayout (vla-get-ActiveDocument (vlax-get-Acad-Object)))) sheetMap)
                       nil))
          (if (not sh) (setq sh (if sheetMap (car sheetMap) nil)))
          (if sh
            (setq labels (PdfLayout_StableSort (cdr sh) 'PdfLayout_CmpLbdNumAsc))
          )
        )
        (princ "\n未选择 Excel，已取消。")
      )
    )
  )
  (if labels
    (progn
      (setq cnt (length labels) done 0 skipped 0 i 0 abort nil baseRef nil lastMs nil)
      (setq space (vla-get-Block (vla-get-ActiveLayout (vla-get-ActiveDocument (vlax-get-Acad-Object)))))
      (setq os (getvar "OSMODE"))
      (setq regen (getvar "REGENMODE"))
      ;; 记到全局：万一被 Esc / 出错中断，由错误处理恢复，避免留下“捕捉关 + 不重生成”
      (setq *PdfLayout_SavedOsmode* os *PdfLayout_SavedRegen* regen)
      (setvar "OSMODE" 0)
      (setvar "REGENMODE" 0)
      (setq refSel (entsel "\n[参考样式] 点选一个现有的 LBD 标签作为新标签的字高/格式/颜色/对齐，直接回车=默认："))
      (setq refE nil refH nil)
      (if refSel
        (progn
          (setq refEn (car refSel))
          (setq refObj (vl-catch-all-apply 'vlax-ename->vla-object (list refEn)))
          (if (and refObj (not (vl-catch-all-error-p refObj)) (= (vla-get-ObjectName refObj) "AcDbMText"))
            (progn
              (setq refE refEn)
              (setq refH (cdr (assoc 40 (entget refE))))
              (if (or (not refH) (<= refH 0.0)) (setq refH nil))
            )
            (princ "\n  未选取 MTEXT，将使用默认样式。")
          )
        )
      )
      (while (and (not abort) (< i cnt))
        (setq kv (nth i labels))
        (setq i (1+ i))
        (setq txt (cdr kv))
        (setq hgt (cond (refH refH)
                        ((and *PdfLayout_LbdTextHeight* (> *PdfLayout_LbdTextHeight* 0)) *PdfLayout_LbdTextHeight*)
                        (t 0.05)))
        (setq tw (max (* 0.62 (strlen txt) hgt) (* hgt 2.0)))
        (princ (strcat "\n[第 " (itoa i) "/" (itoa cnt) " 个] LBD-" (PdfLayout_LbdNumToStr (car kv))
                       ": " txt "  移动鼠标预览，左键放入，回车跳过，Esc结束；正交: "
                       (if (= (getvar "ORTHOMODE") 1) "开" "关")))
        (setq pv nil pve nil ptraw nil ptx nil running T res nil
              moved (if (= i 1) T nil))
        (while running
          (setq gr (vl-catch-all-apply 'grread (list T 11 0)))
          (if (vl-catch-all-error-p gr) (setq gr nil))
          (setq code (if (and gr (car gr)) (car gr) -1) val (if gr (cadr gr) nil))
          (cond
            ((= code 5)
              (setq moved T)
              (setq ptraw (trans val 1 1))
              (setq ptx (if baseRef (PdfLayout_GrOrtho ptraw baseRef) ptraw))
              (if (not pv)
                (progn
                  (setq pv (PdfLayout_LbdMakePreview space ptx tw txt refE hgt))
                  (setq pve (if pv (vlax-vla-object->ename pv) nil))
                )
                (if pve (PdfLayout_MoveMTextFast pve ptx))
              )
            )
            ((= code 3)
              (if (or (not moved)
                      (and lastMs (< (- (PdfLayout_NowMs) lastMs) 120)))
                (princ "\r  * 已忽略同一次点击的重复按键（移动鼠标后再点）        ")
                (progn
                  (setq ptraw (trans val 1 1))
                  (setq ptx (if baseRef (PdfLayout_GrOrtho ptraw baseRef) ptraw))
                  (if (not pv)
                    (progn
                      (setq pv (PdfLayout_LbdMakePreview space ptx tw txt refE hgt))
                      (setq pve (if pv (vlax-vla-object->ename pv) nil))
                    )
                  )
                  (if pve (PdfLayout_MoveMTextFast pve ptx))
                  (setq oldss (vl-catch-all-apply 'ssget (list ptx '((0 . "MTEXT")))))
                  (setq hit nil)
                  (if (and oldss (not (vl-catch-all-error-p oldss)) (> (sslength oldss) 0))
                    (progn
                      (setq j 0)
                      (while (and (not hit) (< j (sslength oldss)))
                        (setq e (ssname oldss j))
                        (if (not (and pve (= e pve))) (setq hit e))
                        (setq j (1+ j))
                      )
                    )
                  )
                  (if hit
                    (progn
                      (vl-catch-all-apply 'vla-put-TextString (list (vlax-ename->vla-object hit) txt))
                      (if pv (vl-catch-all-apply 'vla-Delete (list pv)))
                    )
                  )
                  (setq baseRef ptx)
                  (setq lastMs (PdfLayout_NowMs))
                  (setq res "ok")
                  (setq running nil)
                )
              )
            )
            ((= code 2)
              (cond
                ((= val 15)
                  (setvar "ORTHOMODE" (if (= (getvar "ORTHOMODE") 1) 0 1))
                  (princ (strcat "\r正交: " (if (= (getvar "ORTHOMODE") 1) "开" "关") "        "))
                  (if (and pve ptraw)
                    (progn
                      (setq ptx (if baseRef (PdfLayout_GrOrtho ptraw baseRef) ptraw))
                      (PdfLayout_MoveMTextFast pve ptx)
                    )
                  )
                )
                ((= val 27)
                  (if pv (vl-catch-all-apply 'vla-Delete (list pv)))
                  (setq res "abort") (setq running nil))
                ((or (= val 13) (= val 32))
                  (if pv (vl-catch-all-apply 'vla-Delete (list pv)))
                  (setq res "skip") (setq running nil))
              )
            )
            ((= code 12)
              (if pv (vl-catch-all-apply 'vla-Delete (list pv)))
              (setq res "abort") (setq running nil))
            (t nil)
          )
        )
        (if (= res "ok") (setq done (1+ done)))
        (if (= res "skip") (setq skipped (1+ skipped)))
        (if (= res "abort") (setq abort T))
      )
      (setvar "REGENMODE" regen)
      (setvar "OSMODE" os)
      (setq *PdfLayout_SavedOsmode* nil *PdfLayout_SavedRegen* nil)
      (princ (strcat "\n手动摆放" (if abort "已结束" "完成") "：写入 " (itoa done) " 个标签，跳过 "
                     (itoa skipped) " 个" (if abort (strcat "，剩余 " (itoa (- cnt i)) " 个未放") "")))
      (alert (strcat "手动摆放" (if abort "已结束（中途退出）" "完成") "\n\n共写入 " (itoa done) " 个标签，跳过 "
                     (itoa skipped) " 个"
                     (if abort (strcat "\n还有 " (itoa (- cnt i)) " 个标签未摆放") "")))
    )
    (princ "\n没有可用的 LBD 标签。")
  )
  (princ)
)
(defun c:pdflbd ()
  (vl-load-com)
  (PdfLayout_LoadSettings)
  (PdfLayout_LbdManualRun)
  (princ)
)
(defun c:pdffitvp (/ underlays n u bb vp)
  ;; 把当前布局的最大视口对准指定底图（输入模型空间底图序号）
  (vl-load-com)
  (setq underlays (PdfLayout_GetPdfUnderlays))
  (if (not underlays)
    (princ "\\n模型空间没有识别到 PDF 底图。")
    (progn
      (princ (strcat "\\n模型空间 PDF 底图数: " (itoa (length underlays))
                     "（按导入顺序）"))
      (initget 6)
      (setq n (getint (strcat "\\n要对准第几张底图(1-" (itoa (length underlays)) "): ")))
      (if (and n (<= 1 n (length underlays)))
        (progn
          (setq u (nth (1- n) underlays))
          (setq bb (PdfLayout_GetExtentsSafeObj u))
          (if bb
            (progn
              (setq vp (PdfLayout_LayoutBiggestVp
                         (vla-get-ActiveLayout (vla-get-ActiveDocument (vlax-get-Acad-Object)))))
              (if vp
                (progn
                  (PdfLayout_FitViewport vp bb nil)
                  (princ (strcat "\\n已把当前布局视口对准第 " (itoa n) " 张底图。")))
                (princ "\\n当前布局没有视口。")
              )
            )
            (princ "\\n底图范围读取失败。")
          )
        )
        (princ "\\n已取消。")
      )
    )
  )
  (princ)
)
(setvar "FILEDIA" 1)
(princ "\n=====================================")
  (princ "\n  MAP工具箱 v2.22 已加载")
(princ "\n  命令: PDFLAYOUT    (对话框版)")
(princ "\n  命令: PDFLBD      (识别底图LBD并填写标签)")
(princ "\n  命令: PDFGRID      (批量生成N×M网格多行文字并自动命名)")
(princ "\n  命令: PDFTOOL      (统一入口主菜单)")
(princ "\n  流程: 识别模型空间图纸 → 复制模板布局")
(princ "\n        → 按规则自动改名 → 视口自动对应")
(princ "\n=====================================")
(princ)

;;;-------------------------------------------------------------
;;; PDFGRID：批量生成 N×M 网格多行文字并自动命名
;;; 方案预设 + 几何自适应（框选范围自动算）
;;;-------------------------------------------------------------
(defun PdfLayout_GridPairsFromGlobals (/ rows cols rowSp colSp fx fy i j pt out)
  (setq rows (max 1 *PdfLayout_GridRows*) cols (max 1 *PdfLayout_GridCols*))
  (setq rowSp *PdfLayout_GridRowSp* colSp *PdfLayout_GridColSp*)
  (setq fx *PdfLayout_GridFirstX* fy *PdfLayout_GridFirstY*)
  (setq out nil i 0)
  (while (< i rows)
    (setq j 0)
    (while (< j cols)
      (setq pt (list (+ fx (* j colSp *PdfLayout_GridColDir*))
                     (+ fy (* i rowSp *PdfLayout_GridRowDir*)) 0.0))
      (setq out (append out (list (cons nil (list pt pt)))))
      (setq j (1+ j))
    )
    (setq i (1+ i))
  )
  out
)

(defun PdfLayout_GridUpdate (/ pairs order sorted pr i name names lines grid colSp rowSp h uw uh sx sy bgIdx txtIdx srcDesc initCol initRow rotDeg w)
  (setq *PdfLayout_GridRows* (max 1 (min 100 (PdfLayout_GetTileInt "g_rows" 4))))
  (setq *PdfLayout_GridCols* (max 1 (min 100 (PdfLayout_GetTileInt "g_cols" 5))))
  ;; PDFGRID 只保留「框选范围自动算」；固定绝对参数已移除（PDFRENAME 仍走 "S"）
  (if (/= *PdfLayout_GridGeom* "S")
    (setq *PdfLayout_GridGeom* "1")
  )
  (setq *PdfLayout_GridHMode* (if (= (PdfLayout_GetTileStr "g_hmanual") "1") "manual" "auto"))
  (setq *PdfLayout_GridHRatio* (max 0.01 (min 2.0 (PdfLayout_GetTileReal "g_hratio" 0.4))))
  (setq *PdfLayout_GridMMode* (if (= (PdfLayout_GetTileStr "g_mmode") "1") "custom" "auto"))
  (setq *PdfLayout_GridMT* (PdfLayout_GetTileReal "g_mt" 0.0))
  (setq *PdfLayout_GridMB* (PdfLayout_GetTileReal "g_mb" 0.0))
  (setq *PdfLayout_GridML* (PdfLayout_GetTileReal "g_ml" 0.0))
  (setq *PdfLayout_GridMR* (PdfLayout_GetTileReal "g_mr" 0.0))
  (if (= *PdfLayout_GridGeom* "1")
    (progn
  ;; Auto margin depends on text rotation (0/180 horizontal, 90/270 vertical)
  (setq initCol (if (> *PdfLayout_GridCols* 1) (/ *PdfLayout_GridExtX* (1- *PdfLayout_GridCols*)) *PdfLayout_GridExtX*))
  (setq initRow (if (> *PdfLayout_GridRows* 1) (/ *PdfLayout_GridExtY* (1- *PdfLayout_GridRows*)) *PdfLayout_GridExtY*))
  (setq h (min initCol initRow))
  (if (<= h 0.0) (setq h 1.0))
  (if (= *PdfLayout_GridHMode* "auto")
    (setq h (* h *PdfLayout_GridHRatio*))
    (setq h (PdfLayout_GetTileReal "g_h" 0.5)))
  (if (<= h 0.0) (setq h 1.0))
  (setq rotDeg (nth (max 0 (min 3 (PdfLayout_GetTileInt "g_rot" 0))) '(0 90 180 270)))
  (setq w (min (* h 4.0) initCol))
  (if (<= w 0.0) (setq w h))
  (if (member rotDeg '(90 270))
    (progn
      (setq *PdfLayout_GridMT* (* w 2.0))
      (setq *PdfLayout_GridMB* *PdfLayout_GridMT*)
      (setq *PdfLayout_GridML* (* h 0.5))
      (setq *PdfLayout_GridMR* *PdfLayout_GridML*))
    (progn
      (setq *PdfLayout_GridMT* (* h 2.0))
      (setq *PdfLayout_GridMB* *PdfLayout_GridMT*)
      (setq *PdfLayout_GridML* (* w 0.5))
      (setq *PdfLayout_GridMR* *PdfLayout_GridML*)))
      ;; 按范围自动算：列距=范围宽/(列数-1)，行距=范围高/(行数-1)，字高=min(行距,列距)×比例
  (if (equal *PdfLayout_GridMMode* "custom")
    (progn
      (setq *PdfLayout_GridMT* (PdfLayout_GetTileReal "g_mt" 0.0))
      (setq *PdfLayout_GridMB* (PdfLayout_GetTileReal "g_mb" 0.0))
      (setq *PdfLayout_GridML* (PdfLayout_GetTileReal "g_ml" 0.0))
      (setq *PdfLayout_GridMR* (PdfLayout_GetTileReal "g_mr" 0.0)))
  )
      (setq uw (max 0.0 (- *PdfLayout_GridExtX* *PdfLayout_GridML* *PdfLayout_GridMR*)))
      (setq uh (max 0.0 (- *PdfLayout_GridExtY* *PdfLayout_GridMT* *PdfLayout_GridMB*)))
      (setq colSp (if (> *PdfLayout_GridCols* 1)
                    (/ uw (1- *PdfLayout_GridCols*))
                    uw))
      (setq rowSp (if (> *PdfLayout_GridRows* 1)
                    (/ uh (1- *PdfLayout_GridRows*))
                    uh))
      (setq *PdfLayout_GridColSp* colSp)
      (setq *PdfLayout_GridRowSp* rowSp)
      (setq sx (if *PdfLayout_GridStart* (car *PdfLayout_GridStart*) 0.0))
      (setq sy (if *PdfLayout_GridStart* (cadr *PdfLayout_GridStart*) 0.0))
      (setq *PdfLayout_GridFirstX* (+ sx *PdfLayout_GridML*
                                     (if (> *PdfLayout_GridCols* 1) 0.0 (/ uw 2.0))))
      (setq *PdfLayout_GridFirstY* (- sy *PdfLayout_GridMT*
                                     (if (> *PdfLayout_GridRows* 1) 0.0 (/ uh 2.0))))
      (setq *PdfLayout_GridColDir* 1)
      (setq *PdfLayout_GridRowDir* -1)
      (if (= *PdfLayout_GridHMode* "auto")
        (progn
          (setq h (min rowSp colSp))
          (if (<= h 0.0) (setq h (max *PdfLayout_GridExtX* *PdfLayout_GridExtY*)))
          (if (<= h 0.0) (setq h 1.0))
          (setq *PdfLayout_GridH* (* h *PdfLayout_GridHRatio*))
          (if (<= *PdfLayout_GridH* 0.0) (setq *PdfLayout_GridH* 1.7))
          (set_tile "g_h" (rtos *PdfLayout_GridH* 2 2))
        )
        (setq *PdfLayout_GridH* (PdfLayout_GetTileReal "g_h" 0.5))
      )
      (set_tile "g_rowsp" (rtos *PdfLayout_GridRowSp* 2 2))
      (set_tile "g_colsp" (rtos *PdfLayout_GridColSp* 2 2))
    )
  )
  (mode_tile "g_ml" (if (equal *PdfLayout_GridMMode* "custom") 0 1))
  (mode_tile "g_mr" (if (equal *PdfLayout_GridMMode* "custom") 0 1))
  (mode_tile "g_mt" (if (equal *PdfLayout_GridMMode* "custom") 0 1))
  (mode_tile "g_mb" (if (equal *PdfLayout_GridMMode* "custom") 0 1))
  (mode_tile "g_hratio" (if (and (= *PdfLayout_GridGeom* "1") (= *PdfLayout_GridHMode* "auto")) 0 1))
  (mode_tile "g_h" (if (and (= *PdfLayout_GridGeom* "1") (= *PdfLayout_GridHMode* "auto")) 1 0))
  (if (= *PdfLayout_GridGeom* "S")
    (progn
      (mode_tile "g_rows" 1)
      (mode_tile "g_cols" 1)
      (mode_tile "g_rowsp" 1)
      (mode_tile "g_colsp" 1)
      (mode_tile "g_rot" 1)
    )
  )
  ;; 「继续框选下一个区域」只在 PDFRENAME（选择已有文字）下可用；PDFGRID 是新建文字，用不到
  (vl-catch-all-apply 'mode_tile (list "g_addsel" (if (= *PdfLayout_GridGeom* "S") 0 1)))
  (setq *PdfLayout_GridRot* (nth (max 0 (min 3 (PdfLayout_GetTileInt "g_rot" 0)))
                                 '(0 90 180 270)))
(setq *PdfLayout_GridBg* (if (= (PdfLayout_GetTileStr "g_bgon") "1") "fill" "none"))
  (setq bgIdx (max 0 (min 11 (PdfLayout_GetTileInt "g_bgcolor" 0))))
  (if (< bgIdx 11)
    (setq *PdfLayout_GridBgColor* (nth bgIdx (PdfLayout_GridColorList)))
    (setq *PdfLayout_GridBgColor* (max 1 (min 255 (PdfLayout_GetTileInt "g_bgaci" 1))))
  )
  (setq txtIdx (max 0 (min 11 (PdfLayout_GetTileInt "g_txtcolor" 0))))
  (if (< txtIdx 11)
    (progn
      (setq *PdfLayout_GridTxtColor* (nth txtIdx (PdfLayout_GridColorList)))
      (setq *PdfLayout_GridTxtRGB* (nth txtIdx (PdfLayout_GridRgbList)))
      (setq *PdfLayout_GridTxtTrue* T)
    )
    (progn
      (setq *PdfLayout_GridTxtColor* (max 1 (min 255 (PdfLayout_GetTileInt "g_txtaci" 7))))
      (setq *PdfLayout_GridTxtRGB* 0)
      (setq *PdfLayout_GridTxtTrue* nil)
    )
  )
  (setq *PdfLayout_GridBgScale* (PdfLayout_GetTileReal "g_bgscale" 1.0))
  ;; 允许直接填遮罩因子(1~5)，也兼容按百分比填写(100=1.0, 150=1.5)
  (if (> *PdfLayout_GridBgScale* 50.0) (setq *PdfLayout_GridBgScale* (/ *PdfLayout_GridBgScale* 100.0)))
  (setq *PdfLayout_GridBgScale* (max 1.0 (min 5.0 *PdfLayout_GridBgScale*)))
  (setq *PdfLayout_GridBgRGB* (PdfLayout_GridColorRGB *PdfLayout_GridBgColor*))
  (mode_tile "g_bgcolor" (if (= *PdfLayout_GridBg* "fill") 0 1))
  (mode_tile "g_bgaci" (if (and (= *PdfLayout_GridBg* "fill") (= bgIdx 11)) 0 1))
  (mode_tile "g_bgscale" (if (= *PdfLayout_GridBg* "fill") 0 1))
  (mode_tile "g_txtaci" (if (= txtIdx 11) 0 1))
  ;; PDFRENAME（选择已有文字）只按顺序改名字：字高/文字色/背景填充一律保持现状，相关控件灰显
  (if (= *PdfLayout_GridGeom* "S")
    (foreach tk '("g_h" "g_hauto" "g_hmanual" "g_hratio" "g_bgnone" "g_bgon"
                   "g_bgcolor" "g_bgaci" "g_txtcolor" "g_txtaci" "g_bgscale")
      (mode_tile tk 1)
    )
  )
  (setq *PdfLayout_GridSrc*
    (cond
      ((= (PdfLayout_GetTileStr "g_srcxlsx") "1") "xlsx")
            (t "auto")
    )
  )
  (setq *PdfLayout_GridPrefix* (PdfLayout_GetTileStr "g_prefix"))
  (if (= *PdfLayout_GridPrefix* "") (setq *PdfLayout_GridPrefix* "CIR"))
  (setq *PdfLayout_GridStartN* (max 1 (PdfLayout_GetTileInt "g_startn" 1)))
  (setq *PdfLayout_GridDigits* (max 0 (PdfLayout_GetTileInt "g_digits" 2)))
  (setq *PdfLayout_PreviewOrder* (cond
    ((= (PdfLayout_GetTileStr "ord1") "1") "1")
    ((= (PdfLayout_GetTileStr "ord2") "1") "2")
    ((= (PdfLayout_GetTileStr "ord3") "1") "3")
    ((= (PdfLayout_GetTileStr "ord4") "1") "4")
    ((= (PdfLayout_GetTileStr "ord5") "1") "5")
    ((= (PdfLayout_GetTileStr "ord6") "1") "6")
    ((= (PdfLayout_GetTileStr "ord7") "1") "7")
    ((= (PdfLayout_GetTileStr "ord8") "1") "8")
    (t *PdfLayout_PreviewOrder*)
  ))
  (setq pairs (if (= *PdfLayout_GridGeom* "S") *PdfLayout_GridSelPairs* (PdfLayout_GridPairsFromGlobals)))
  (setq *PdfLayout_GridPairs* pairs)
  (setq order *PdfLayout_PreviewOrder*)
  ;; PDFRENAME：按框选批次先后给顺序（批内仍按位置排），这样多批选择不会跨批交叉编号
  (setq sorted (if (= *PdfLayout_GridGeom* "S")
                 (PdfLayout_RenameBatchSorted order)
                 (PdfLayout_SortPairsSmart pairs order)))
  (if (= *PdfLayout_GridGeom* "S")
    (if pairs
      (setq grid (vl-catch-all-apply 'PdfLayout_BuildSchemeGrid (list pairs order sorted)))
      (setq grid (list "（未选择文字）"))
    )
    (setq grid (vl-catch-all-apply 'PdfLayout_BuildSchemeGrid (list pairs order)))
  )
  (if (vl-catch-all-error-p grid)
    (setq grid (list "（无法生成示意图）"))
  )
  (setq grid (mapcar '(lambda (ln) (PdfLayout_EllipsisMid ln 24)) grid))
  (PdfLayout_SetList "g_grid" grid)
  (setq names (if (equal *PdfLayout_GridSrc* "xlsx") *PdfLayout_GridNames* nil))
  (setq srcDesc (cond
    ((= *PdfLayout_GridSrc* "xlsx") (strcat "Excel分表" (if *PdfLayout_GridSheetSel* (strcat " [" *PdfLayout_GridSheetSel* "]") "")))
        (t "自动命名")
  ))
  (if (not sorted) (setq sorted (PdfLayout_SortPairsSmart pairs order)))
  (setq i 0 lines nil)
  (if (= *PdfLayout_GridGeom* "S")
    ;; PDFRENAME：每个框选区域都从头编号（批内序号从 0 重新开始）
    (foreach pr (PdfLayout_RenamePlan order)
      (setq lines (append lines (list (strcat "第" (itoa (1+ i)) "个: "
                                             (PdfLayout_EllipsisMid
                                               (PdfLayout_RenameNameAt names (cdr pr)) 14)))))
      (setq i (1+ i))
    )
    (foreach p sorted
      (setq name (if (and names (< i (length names)))
                    (nth i names)
                    (PdfLayout_NameAtPrefix *PdfLayout_GridPrefix*
                                            (+ *PdfLayout_GridStartN* i)
                                            *PdfLayout_GridDigits*)))
      (setq lines (append lines (list (strcat "第" (itoa (1+ i)) "个: "
                                             (PdfLayout_EllipsisMid name 14)))))
      (setq i (1+ i))
    )
  )
  (PdfLayout_SetList "g_names" lines)
  (set_tile "g_info"
    (strcat "共 " (itoa (length pairs)) " 个多行文字"
            (if (and names (/= (length names) (length pairs)))
              (strcat "（名单 " (itoa (length names)) " 个，按文字/名单较少者执行）")
              "")
            (if (and (= *PdfLayout_GridGeom* "S") (> (length *PdfLayout_GridSelBatches*) 1))
              (strcat "（分 " (itoa (length *PdfLayout_GridSelBatches*)) " 批，每批都从头编号）")
              "")
            "；几何: " (if (= *PdfLayout_GridGeom* "S") "选择已有文字" "按范围自动")
            "；字高: " (if (= *PdfLayout_GridHMode* "manual") "直接输入" "按比例")
            "；排序: " (PdfLayout_OrderDesc order) "；来源: " srcDesc))
)
(defun PdfLayout_GridStripName (s / up L)
  ;; 分表名只取到最后 ".dc" 之前（大小写不敏感），保留前面的 .数字
  (setq s (vl-string-trim " " s))
  (setq up (strcase s))
  (setq L (strlen up))
  (if (and (>= L 4) (= (substr up (- L 2) 3) ".DC"))
    (substr s 1 (- L 3))
    s
  )
)
(defun PdfLayout_GridPairNames (codes / out n a b)
  ;; 把 Item Code 列表两两一组，生成 "A/B" 名字
  (setq out nil)
  (setq n 0)
  (while (< n (length codes))
    (setq a (nth n codes))
    (setq b (nth (1+ n) codes))
    (if a
      (setq out (append out (list (if (and b (/= b "")) (strcat a "/" b) a)))))
    (setq n (+ n 2))
  )
  out
)

(defun PdfLayout_GridPickXlsx (/ fpath)
  (setq fpath (getfiled "选择Excel(分表名=布局名)" "" "xlsx;xls" 4))
  (if fpath
    (progn
      (set_tile "g_filexlsx" fpath)
      (setq *PdfLayout_GridXlsx* fpath)
      (PdfLayout_GridReadXlsx)
    )
  )
)

(defun PdfLayout_GridNamesFor (disp / i full)
  ;; 根据去后缀后的分表名(布局名)找到对应名单
  (setq i 0)
  (while (and (nth i *PdfLayout_GridSheetNames*)
              (not (string= (strcase (nth i *PdfLayout_GridSheetNames*)) (strcase disp))))
    (setq i (1+ i))
  )
  (setq full (nth i *PdfLayout_GridSheetFull*))
  (if (and full (assoc full *PdfLayout_GridSheets*))
    (cdr (assoc full *PdfLayout_GridSheets*))
    nil
  )
)

(defun PdfLayout_GridPickSheet (/ tab disp found)
  ;; 按当前布局名自动匹配同名分表；找不到用第一个分表
  (setq tab (getvar "CTAB"))
  (setq found nil)
  (foreach disp *PdfLayout_GridSheetNames*
    (if (string= (strcase disp) (strcase tab)) (setq found disp))
  )
  (if (not found) (setq found (car *PdfLayout_GridSheetNames*)))
  (setq *PdfLayout_GridSheetSel* found)
  (setq *PdfLayout_GridNames* (PdfLayout_GridNamesFor found))
)

(defun PdfLayout_GridSheetList (/ items idx i sheet)
  (setq items *PdfLayout_GridSheetNames*)
  (if (null items) (setq items (list "(无分表)")))
  (setq idx 0 i 0)
  (foreach sheet *PdfLayout_GridSheetNames*
    (if (string= (strcase sheet) (strcase *PdfLayout_GridSheetSel*))
      (setq idx i))
    (setq i (1+ i))
  )
  (PdfLayout_SetList "g_xlsxsheet" items)
  (set_tile "g_xlsxsheet" (itoa idx))
)

(defun PdfLayout_GridSheetChanged (/ idx disp)
  (setq idx (PdfLayout_GetTileInt "g_xlsxsheet" 0))
  (setq disp (nth idx *PdfLayout_GridSheetNames*))
  (if disp (setq *PdfLayout_GridSheetSel* disp))
  (setq *PdfLayout_GridNames* (PdfLayout_GridNamesFor disp))
  (PdfLayout_GridUpdate)
)

(defun PdfLayout_GridIsCode (s / i c ok)
  ;; 只认 2 个以上纯字母的 Item Code，过滤表头/标题等杂项
  (setq s (vl-string-trim " " s))
  (setq ok T i 1)
  (if (< (strlen s) 2) (setq ok nil))
  (while (and ok (<= i (strlen s)))
    (setq c (substr s i 1))
    (if (not (or (and (>= c "A") (<= c "Z")) (and (>= c "a") (<= c "z"))))
      (setq ok nil))
    (setq i (1+ i))
  )
  ok
)

(defun PdfLayout_GridReadXlsx (/ path xl hadExcel wbs wb shs i shCount sh sheet ur vals arr rows codes name j disp)
  (setq path (PdfLayout_GetTileStr "g_filexlsx"))
  (if (= path "") (setq path *PdfLayout_GridXlsx*))
  (if (= path "")
    (progn (alert "请先选择 Excel 文件。") nil)
    (progn
      (setq *PdfLayout_GridXlsx* path)
      (setq *PdfLayout_GridSrc* "xlsx")
      (set_tile "g_srcxlsx" "1")
      (setq *PdfLayout_GridSheets* nil)
      (setq *PdfLayout_GridSheetNames* nil)
      (setq *PdfLayout_GridSheetFull* nil)
      (setq hadExcel (vl-catch-all-apply 'vlax-get-object (list "Excel.Application")))
      (setq hadExcel (and hadExcel (not (vl-catch-all-error-p hadExcel))))
      (setq xl (vl-catch-all-apply 'vlax-create-object (list "Excel.Application")))
      (if (and xl (not (vl-catch-all-error-p xl)))
        (progn
          (vl-catch-all-apply 'vlax-put-property (list xl 'Visible 0))
          (vl-catch-all-apply 'vlax-put-property (list xl 'DisplayAlerts 0))
          (vl-catch-all-apply 'vlax-put-property (list xl 'AskToUpdateLinks 0))
          (vl-catch-all-apply 'vlax-put-property (list xl 'AutomationSecurity 3))
          (setq wbs (vl-catch-all-apply 'vlax-get-property (list xl 'Workbooks)))
          (setq wb (vl-catch-all-apply 'vlax-invoke-method (list wbs 'Open path 0 1)))
          (if (and wb (not (vl-catch-all-error-p wb)))
            (progn
              (setq shs (vl-catch-all-apply 'vlax-get-property (list wb 'Sheets)))
              (if (and shs (not (vl-catch-all-error-p shs)))
                (progn
                  (setq shCount (vl-catch-all-apply 'vlax-get-property (list shs 'Count)))
                  (setq i 1)
                  (while (<= i shCount)
                    (setq sh (vl-catch-all-apply 'vlax-get-property (list shs 'Item i)))
                    (if (not (vl-catch-all-error-p sh))
                      (progn
                        (setq sheet (vl-catch-all-apply 'vlax-get-property (list sh 'Name)))
                        (if (vl-catch-all-error-p sheet) (setq sheet (strcat "分表" (itoa i))))
                        (setq sheet (vl-string-trim " " sheet))
                        (setq ur (vl-catch-all-apply 'vlax-get-property (list sh 'UsedRange)))
                        (setq vals (if (and ur (not (vl-catch-all-error-p ur)))
                                     (vl-catch-all-apply 'vlax-get-property (list ur 'Value)) nil))
                        (setq codes nil)
                        (if (and vals (not (vl-catch-all-error-p vals)))
                          (progn
                            (setq arr (vl-catch-all-apply 'vlax-variant-value (list vals)))
                            (if (not (vl-catch-all-error-p arr))
                              (progn
                                (setq rows (vl-catch-all-apply 'vlax-safearray->list (list arr)))
                                (if (not (vl-catch-all-error-p rows))
                                  (progn
                                    (setq rows (mapcar '(lambda (r) (mapcar 'PdfLayout_CellStr r)) rows))
                                    (foreach r rows
                                      (setq name (nth 2 r))
                                      (if (and name (PdfLayout_GridIsCode name))
                                        (setq codes (append codes (list (vl-string-trim " " name))))
                                      )
                                    )
                                  )
                                )
                              )
                            )
                          )
                        )
                        (setq disp (PdfLayout_GridStripName sheet))
                        (setq *PdfLayout_GridSheets*
                              (append *PdfLayout_GridSheets* (list (cons sheet (PdfLayout_GridPairNames codes)))))
                        (setq *PdfLayout_GridSheetFull*
                              (append *PdfLayout_GridSheetFull* (list sheet)))
                        (setq *PdfLayout_GridSheetNames*
                              (append *PdfLayout_GridSheetNames* (list disp)))
                        (princ (strcat "\n  分表 [" sheet "] -> [" disp "] : " (itoa (length codes)) " 项"))
                      )
                    )
                    (setq i (1+ i))
                  )
                )
              )
              (vl-catch-all-apply 'vlax-invoke-method (list wb 'Close 0))
            )
          )
          (PdfLayout_ExcelCleanup xl hadExcel (list shs sh ur wb wbs))
        )
      )
      (if *PdfLayout_GridSheetNames*
        (progn
          (PdfLayout_GridPickSheet)
          (PdfLayout_GridSheetList)
          (PdfLayout_GridUpdate)
          (princ (strcat "\nPDFGRID: 已读取 " (itoa (length *PdfLayout_GridSheetNames*)) " 个分表。"))
        )
        (alert "无法读取 Excel，或文件中没有可识别的分表。")
      )
    )
  )
)
(defun PdfLayout_GridFillProfiles (/ items i)
  (setq items (list "默认(当前参数)"))
  (foreach pf *PdfLayout_GridProfiles*
    (if (eq (type (car pf)) 'STR)
      (setq items (append items (list (car pf))))
    )
  )
  (PdfLayout_SetList "g_prof" items)
  (setq i 0)
  (foreach pf *PdfLayout_GridProfiles*
    (setq i (1+ i))
    (if (= (strcase (car pf)) (strcase *PdfLayout_GridProfile*))
      (set_tile "g_prof" (itoa i))
    )
  )
  (set_tile "g_profname" (if (eq (type *PdfLayout_GridProfile*) 'STR) *PdfLayout_GridProfile* ""))
)

(defun PdfLayout_GridApplyProfile (idx / pf)
  (if (> idx 0)
    (progn
      (setq pf (nth (1- idx) *PdfLayout_GridProfiles*))
      (if pf
        (progn
          (setq *PdfLayout_GridRows* (PdfLayout_OrDefault (PdfLayout_ProfileGet (cdr pf) "Rows") 4))
          (setq *PdfLayout_GridCols* (PdfLayout_OrDefault (PdfLayout_ProfileGet (cdr pf) "Cols") 5))
          (setq *PdfLayout_GridRowSp* (PdfLayout_OrDefault (PdfLayout_ProfileGet (cdr pf) "RowSp") 10.0))
          (setq *PdfLayout_GridColSp* (PdfLayout_OrDefault (PdfLayout_ProfileGet (cdr pf) "ColSp") 20.0))
          (setq *PdfLayout_GridH* (PdfLayout_OrDefault (PdfLayout_ProfileGet (cdr pf) "H") 0.5))
          (setq *PdfLayout_GridHRatio* (PdfLayout_OrDefault (PdfLayout_ProfileGet (cdr pf) "HRatio") 0.4))
          (setq *PdfLayout_GridGeom* (PdfLayout_OrDefault (PdfLayout_ProfileGet (cdr pf) "Geom") "1"))
          (setq *PdfLayout_GridHMode* (PdfLayout_OrDefault (PdfLayout_ProfileGet (cdr pf) "HMode") "auto"))
          (setq *PdfLayout_GridMT* (PdfLayout_OrDefault (PdfLayout_ProfileGet (cdr pf) "MT") 0.0))
          (setq *PdfLayout_GridMB* (PdfLayout_OrDefault (PdfLayout_ProfileGet (cdr pf) "MB") 0.0))
          (setq *PdfLayout_GridML* (PdfLayout_OrDefault (PdfLayout_ProfileGet (cdr pf) "ML") 0.0))
          (setq *PdfLayout_GridMR* (PdfLayout_OrDefault (PdfLayout_ProfileGet (cdr pf) "MR") 0.0))
          (setq *PdfLayout_GridColDir* (PdfLayout_OrDefault (PdfLayout_ProfileGet (cdr pf) "ColDir") 1))
          (setq *PdfLayout_GridRowDir* (PdfLayout_OrDefault (PdfLayout_ProfileGet (cdr pf) "RowDir") -1))
          (setq *PdfLayout_GridRot* (PdfLayout_OrDefault (PdfLayout_ProfileGet (cdr pf) "Rot") 0))
(setq *PdfLayout_GridBg* (PdfLayout_OrDefault (PdfLayout_ProfileGet (cdr pf) "Bg") "fill"))
          (setq *PdfLayout_GridBgColor* (PdfLayout_OrDefault (PdfLayout_ProfileGet (cdr pf) "BgColor") 1))
          (setq *PdfLayout_GridTxtColor* (PdfLayout_OrDefault (PdfLayout_ProfileGet (cdr pf) "TxtColor") 7))
          (setq *PdfLayout_GridTxtTrue* (= (PdfLayout_OrDefault (PdfLayout_ProfileGet (cdr pf) "TxtTrue") "0") "1"))
          (setq *PdfLayout_GridTxtRGB* (PdfLayout_OrDefault (PdfLayout_ProfileGet (cdr pf) "TxtRGB") 0))
          (setq *PdfLayout_GridBgScale* (PdfLayout_OrDefault (PdfLayout_ProfileGet (cdr pf) "BgScale") 1.0))
          (if (> *PdfLayout_GridBgScale* 50)
            (setq *PdfLayout_GridBgScale* (/ *PdfLayout_GridBgScale* 100.0)))
          (setq *PdfLayout_GridPrefix* (PdfLayout_OrDefault (PdfLayout_ProfileGet (cdr pf) "Prefix") "CIR"))
          (setq *PdfLayout_GridStartN* (PdfLayout_OrDefault (PdfLayout_ProfileGet (cdr pf) "StartN") 1))
          (setq *PdfLayout_GridDigits* (PdfLayout_OrDefault (PdfLayout_ProfileGet (cdr pf) "Digits") 2))
          (setq *PdfLayout_PreviewOrder* (PdfLayout_OrDefault (PdfLayout_ProfileGet (cdr pf) "Order") "1"))
          (setq *PdfLayout_GridProfile* (car pf))
          (PdfLayout_GridInit)
        )
      )
    )
  )
)

(defun PdfLayout_GridSaveProfile (/ name prof)
  (setq name (PdfLayout_GetTileStr "g_profname"))
  (if (= name "")
    (alert "请先输入方案名。")
    (progn
      (PdfLayout_GridUpdate)
      (setq prof nil)
      (setq prof (PdfLayout_ProfileSet prof "Rows" *PdfLayout_GridRows*))
      (setq prof (PdfLayout_ProfileSet prof "Cols" *PdfLayout_GridCols*))
      (setq prof (PdfLayout_ProfileSet prof "RowSp" *PdfLayout_GridRowSp*))
      (setq prof (PdfLayout_ProfileSet prof "ColSp" *PdfLayout_GridColSp*))
      (setq prof (PdfLayout_ProfileSet prof "H" *PdfLayout_GridH*))
      (setq prof (PdfLayout_ProfileSet prof "HRatio" *PdfLayout_GridHRatio*))
      (setq prof (PdfLayout_ProfileSet prof "Geom" *PdfLayout_GridGeom*))
      (setq prof (PdfLayout_ProfileSet prof "HMode" *PdfLayout_GridHMode*))
      (setq prof (PdfLayout_ProfileSet prof "MT" *PdfLayout_GridMT*))
      (setq prof (PdfLayout_ProfileSet prof "MB" *PdfLayout_GridMB*))
      (setq prof (PdfLayout_ProfileSet prof "ML" *PdfLayout_GridML*))
      (setq prof (PdfLayout_ProfileSet prof "MR" *PdfLayout_GridMR*))
      (setq prof (PdfLayout_ProfileSet prof "ColDir" *PdfLayout_GridColDir*))
      (setq prof (PdfLayout_ProfileSet prof "RowDir" *PdfLayout_GridRowDir*))
      (setq prof (PdfLayout_ProfileSet prof "Rot" *PdfLayout_GridRot*))
(setq prof (PdfLayout_ProfileSet prof "Bg" *PdfLayout_GridBg*))
      (setq prof (PdfLayout_ProfileSet prof "BgColor" *PdfLayout_GridBgColor*))
      (setq prof (PdfLayout_ProfileSet prof "TxtColor" *PdfLayout_GridTxtColor*))
      (setq prof (PdfLayout_ProfileSet prof "TxtTrue" (if *PdfLayout_GridTxtTrue* "1" "0")))
      (setq prof (PdfLayout_ProfileSet prof "TxtRGB" *PdfLayout_GridTxtRGB*))
      (setq prof (PdfLayout_ProfileSet prof "BgScale" *PdfLayout_GridBgScale*))
      (setq prof (PdfLayout_ProfileSet prof "Prefix" *PdfLayout_GridPrefix*))
      (setq prof (PdfLayout_ProfileSet prof "StartN" *PdfLayout_GridStartN*))
      (setq prof (PdfLayout_ProfileSet prof "Digits" *PdfLayout_GridDigits*))
      (setq prof (PdfLayout_ProfileSet prof "Order" *PdfLayout_PreviewOrder*))
      (setq *PdfLayout_GridProfiles*
        (vl-remove-if
          '(lambda (x) (= (strcase (car x)) (strcase name)))
          *PdfLayout_GridProfiles*))
      (setq *PdfLayout_GridProfiles* (append *PdfLayout_GridProfiles* (list (cons name prof))))
      (setq *PdfLayout_GridProfile* name)
      (PdfLayout_SaveSettings)
      (PdfLayout_GridFillProfiles)
      (princ (strcat "\n网格方案已保存: " name))
    )
  )
)

(defun PdfLayout_GridDeleteProfile (/ idx sel name)
  (setq idx (PdfLayout_GetTileInt "g_prof" -1))
  (if (> idx 0)
    (progn
      (setq sel (nth (1- idx) *PdfLayout_GridProfiles*))
      (if sel
        (progn
          (setq name (car sel))
          (setq *PdfLayout_GridProfiles*
            (vl-remove-if
              '(lambda (x) (= (strcase (car x)) (strcase name)))
              *PdfLayout_GridProfiles*))
          (if (= (strcase *PdfLayout_GridProfile*) (strcase name))
            (setq *PdfLayout_GridProfile* "")
          )
          (PdfLayout_SaveSettings)
          (PdfLayout_GridFillProfiles)
          (set_tile "g_prof" "0")
          (set_tile "g_profname" "")
          (princ (strcat "\n网格方案已删除: " name))
        )
        (alert "请先选择要删除的方案。")
      )
    )
    (alert "请先选择要删除的方案。")
  )
)

(defun PdfLayout_GridLoadProfiles (/ i cnt name prof)
  (setq *PdfLayout_GridProfiles* nil)
  (setq i 1)
  (setq cnt (atoi (PdfLayout_OrDefault (PdfLayout_IniGet "GridProfileCount") "0")))
  (while (<= i cnt)
    (setq name (PdfLayout_IniGet (strcat "GridProfile" (itoa i) "Name")))
    (if name
      (progn
        (setq prof nil)
        (setq prof (PdfLayout_ProfileSet prof "Rows" (atoi (PdfLayout_OrDefault (PdfLayout_IniGet (strcat "GridProfile" (itoa i) "Rows")) "4"))))
        (setq prof (PdfLayout_ProfileSet prof "Cols" (atoi (PdfLayout_OrDefault (PdfLayout_IniGet (strcat "GridProfile" (itoa i) "Cols")) "5"))))
        (setq prof (PdfLayout_ProfileSet prof "RowSp" (atof (PdfLayout_OrDefault (PdfLayout_IniGet (strcat "GridProfile" (itoa i) "RowSp")) "10"))))
        (setq prof (PdfLayout_ProfileSet prof "ColSp" (atof (PdfLayout_OrDefault (PdfLayout_IniGet (strcat "GridProfile" (itoa i) "ColSp")) "20"))))
        (setq prof (PdfLayout_ProfileSet prof "H" (atof (PdfLayout_OrDefault (PdfLayout_IniGet (strcat "GridProfile" (itoa i) "H")) "0.5"))))
        (setq prof (PdfLayout_ProfileSet prof "HRatio" (atof (PdfLayout_OrDefault (PdfLayout_IniGet (strcat "GridProfile" (itoa i) "HRatio")) "0.4"))))
        (setq prof (PdfLayout_ProfileSet prof "Geom" (PdfLayout_OrDefault (PdfLayout_IniGet (strcat "GridProfile" (itoa i) "Geom")) "1")))
        (setq prof (PdfLayout_ProfileSet prof "HMode" (PdfLayout_OrDefault (PdfLayout_IniGet (strcat "GridProfile" (itoa i) "HMode")) "auto")))
        (setq prof (PdfLayout_ProfileSet prof "MT" (atof (PdfLayout_OrDefault (PdfLayout_IniGet (strcat "GridProfile" (itoa i) "MT")) "0"))))
        (setq prof (PdfLayout_ProfileSet prof "MB" (atof (PdfLayout_OrDefault (PdfLayout_IniGet (strcat "GridProfile" (itoa i) "MB")) "0"))))
        (setq prof (PdfLayout_ProfileSet prof "ML" (atof (PdfLayout_OrDefault (PdfLayout_IniGet (strcat "GridProfile" (itoa i) "ML")) "0"))))
        (setq prof (PdfLayout_ProfileSet prof "MR" (atof (PdfLayout_OrDefault (PdfLayout_IniGet (strcat "GridProfile" (itoa i) "MR")) "0"))))
        (setq prof (PdfLayout_ProfileSet prof "ColDir" (atoi (PdfLayout_OrDefault (PdfLayout_IniGet (strcat "GridProfile" (itoa i) "ColDir")) "1"))))
        (setq prof (PdfLayout_ProfileSet prof "RowDir" (atoi (PdfLayout_OrDefault (PdfLayout_IniGet (strcat "GridProfile" (itoa i) "RowDir")) "-1"))))
        (setq prof (PdfLayout_ProfileSet prof "Rot" (atoi (PdfLayout_OrDefault (PdfLayout_IniGet (strcat "GridProfile" (itoa i) "Rot")) "0"))))
(setq prof (PdfLayout_ProfileSet prof "Bg" (PdfLayout_OrDefault (PdfLayout_IniGet (strcat "GridProfile" (itoa i) "Bg")) "fill")))
        (setq prof (PdfLayout_ProfileSet prof "BgColor" (atoi (PdfLayout_OrDefault (PdfLayout_IniGet (strcat "GridProfile" (itoa i) "BgColor")) "1"))))
        (setq prof (PdfLayout_ProfileSet prof "TxtColor" (atoi (PdfLayout_OrDefault (PdfLayout_IniGet (strcat "GridProfile" (itoa i) "TxtColor")) "7"))))
        (setq prof (PdfLayout_ProfileSet prof "TxtTrue" (PdfLayout_OrDefault (PdfLayout_IniGet (strcat "GridProfile" (itoa i) "TxtTrue")) "0")))
        (setq prof (PdfLayout_ProfileSet prof "TxtRGB" (atoi (PdfLayout_OrDefault (PdfLayout_IniGet (strcat "GridProfile" (itoa i) "TxtRGB")) "0"))))
        (setq prof (PdfLayout_ProfileSet prof "BgScale" (atof (PdfLayout_OrDefault (PdfLayout_IniGet (strcat "GridProfile" (itoa i) "BgScale")) "1"))))
        (setq prof (PdfLayout_ProfileSet prof "Prefix" (PdfLayout_OrDefault (PdfLayout_IniGet (strcat "GridProfile" (itoa i) "Prefix")) "CIR")))
        (setq prof (PdfLayout_ProfileSet prof "StartN" (atoi (PdfLayout_OrDefault (PdfLayout_IniGet (strcat "GridProfile" (itoa i) "StartN")) "1"))))
        (setq prof (PdfLayout_ProfileSet prof "Digits" (atoi (PdfLayout_OrDefault (PdfLayout_IniGet (strcat "GridProfile" (itoa i) "Digits")) "2"))))
        (setq prof (PdfLayout_ProfileSet prof "Order" (PdfLayout_OrDefault (PdfLayout_IniGet (strcat "GridProfile" (itoa i) "Order")) "1")))
        (setq *PdfLayout_GridProfiles* (append *PdfLayout_GridProfiles* (list (cons name prof))))
      )
    )
    (setq i (1+ i))
  )
)

(defun PdfLayout_GridInit (/ bgIdx txtIdx)
  (set_tile "g_rows" (itoa *PdfLayout_GridRows*))
  (set_tile "g_cols" (itoa *PdfLayout_GridCols*))
  (set_tile "g_rowsp" (rtos *PdfLayout_GridRowSp* 2 2))
  (set_tile "g_colsp" (rtos *PdfLayout_GridColSp* 2 2))
  (set_tile "g_h" (rtos *PdfLayout_GridH* 2 2))
  (PdfLayout_SetList "g_mmode" '("自动" "自定义"))
  (set_tile "g_mmode" (if (equal *PdfLayout_GridMMode* "custom") "1" "0"))
  (set_tile "g_mt" (rtos *PdfLayout_GridMT* 2 2))
  (set_tile "g_mb" (rtos *PdfLayout_GridMB* 2 2))
  (set_tile "g_ml" (rtos *PdfLayout_GridML* 2 2))
  (set_tile "g_mr" (rtos *PdfLayout_GridMR* 2 2))
  (set_tile "g_hratio" (rtos *PdfLayout_GridHRatio* 2 2))
  (set_tile (if (= *PdfLayout_GridHMode* "manual") "g_hmanual" "g_hauto") "1")
  (PdfLayout_SetList "g_rot" '("0°" "90°" "180°" "270°"))
  (set_tile "g_rot" (itoa (cond
    ((= *PdfLayout_GridRot* 90) 1)
    ((= *PdfLayout_GridRot* 180) 2)
    ((= *PdfLayout_GridRot* 270) 3)
    (t 0)
  )))
(set_tile (if (= *PdfLayout_GridBg* "fill") "g_bgon" "g_bgnone") "1")
  (PdfLayout_SetList "g_bgcolor" '("红色" "黄色" "绿色" "青色" "蓝色" "品红" "白色" "灰色" "黑色" "橙色" "深灰" "自定义"))
  (PdfLayout_SetList "g_txtcolor" '("红色" "黄色" "绿色" "青色" "蓝色" "品红" "白色" "灰色" "黑色" "橙色" "深灰" "自定义"))
  (setq bgIdx (PdfLayout_GridColorIndex *PdfLayout_GridBgColor*))
  (setq txtIdx (if *PdfLayout_GridTxtTrue*
                  (PdfLayout_GridIndexByRGB *PdfLayout_GridTxtRGB*)
                  (PdfLayout_GridColorIndex *PdfLayout_GridTxtColor*)))
  (set_tile "g_bgcolor" (itoa bgIdx))
  (set_tile "g_txtcolor" (itoa txtIdx))
  (set_tile "g_bgaci" (itoa *PdfLayout_GridBgColor*))
  (set_tile "g_txtaci" (itoa *PdfLayout_GridTxtColor*))
  (set_tile "g_bgscale" (rtos *PdfLayout_GridBgScale* 2 2))
  (cond
    ((= *PdfLayout_GridSrc* "xlsx") (set_tile "g_srcxlsx" "1"))
        (t (set_tile "g_srcauto" "1"))
  )
  (set_tile "g_prefix" *PdfLayout_GridPrefix*)
  (set_tile "g_startn" (itoa *PdfLayout_GridStartN*))
  (set_tile "g_digits" (itoa *PdfLayout_GridDigits*))
  (set_tile "g_filexlsx" *PdfLayout_GridXlsx*)
  (PdfLayout_GridSheetList)
  (if (and (= *PdfLayout_GridSrc* "xlsx") (/= *PdfLayout_GridXlsx* "") (not *PdfLayout_GridSheets*))
    (PdfLayout_GridReadXlsx)
  )
  (set_tile "g_start" (if *PdfLayout_GridStart*
    (strcat "起点: " (rtos (car *PdfLayout_GridStart*) 2 2) ", " (rtos (cadr *PdfLayout_GridStart*) 2 2))
    "起点: 0, 0"))
  (if (member *PdfLayout_PreviewOrder* '("1" "2" "3" "4" "5" "6" "7" "8"))
    (set_tile (strcat "ord" *PdfLayout_PreviewOrder*) "1")
  )
  (PdfLayout_GridFillProfiles)
  (PdfLayout_GridUpdate)
)

(defun PdfLayout_GridAccept ()
  (PdfLayout_GridUpdate)
  (PdfLayout_SaveSettings)
  (setq *PdfLayout_GridResult* 1)
  (done_dialog 1)
)

(defun PdfLayout_GridShowDialog (/ dclPath dclId result nd)
  (setq dclPath (PdfLayout_FindDcl))
  (if (not dclPath)
    (progn
      "0"
    )
    (progn
      (setq dclId (load_dialog dclPath))
      (if (< dclId 0)
        (progn
          "0"
        )
        (progn
          (setq nd (vl-catch-all-apply 'new_dialog (list "PdfGrid" dclId)))
          (if (and nd (not (vl-catch-all-error-p nd)))
            (progn
              (PdfLayout_GridInit)
              (action_tile "g_prof" "(PdfLayout_GridApplyProfile (PdfLayout_GetTileInt \"g_prof\" -1))")
              (action_tile "g_saveprof" "(PdfLayout_GridSaveProfile)")
              (action_tile "g_delprof" "(PdfLayout_GridDeleteProfile)")
              (action_tile "g_rows" "(PdfLayout_GridUpdate)")
              (action_tile "g_cols" "(PdfLayout_GridUpdate)")
              (action_tile "g_rowsp" "(PdfLayout_GridUpdate)")
              (action_tile "g_colsp" "(PdfLayout_GridUpdate)")
              (action_tile "g_hratio" "(PdfLayout_GridUpdate)")
              (action_tile "g_hauto" "(PdfLayout_GridUpdate)")
              (action_tile "g_hmanual" "(PdfLayout_GridUpdate)")
              (action_tile "g_h" "(PdfLayout_GridUpdate)")
              (action_tile "g_mmode" "(PdfLayout_GridUpdate)")
              (action_tile "g_mt" "(PdfLayout_GridUpdate)")
              (action_tile "g_mb" "(PdfLayout_GridUpdate)")
              (action_tile "g_ml" "(PdfLayout_GridUpdate)")
              (action_tile "g_mr" "(PdfLayout_GridUpdate)")
              (action_tile "g_rot" "(PdfLayout_GridUpdate)")
(action_tile "g_bgnone" "(PdfLayout_GridUpdate)")
              (action_tile "g_bgon" "(PdfLayout_GridUpdate)")
              (action_tile "g_bgcolor" "(PdfLayout_GridUpdate)")
              (action_tile "g_bgaci" "(PdfLayout_GridUpdate)")
              (action_tile "g_txtcolor" "(PdfLayout_GridUpdate)")
              (action_tile "g_txtaci" "(PdfLayout_GridUpdate)")
              (action_tile "g_bgscale" "(PdfLayout_GridUpdate)")
              (action_tile "g_srcauto" "(setq *PdfLayout_GridSrc* \"auto\") (PdfLayout_GridUpdate)")
              (action_tile "g_srcxlsx" "(setq *PdfLayout_GridSrc* \"xlsx\") (PdfLayout_GridUpdate)")
              (action_tile "g_prefix" "(PdfLayout_GridUpdate)")
              (action_tile "g_startn" "(PdfLayout_GridUpdate)")
              (action_tile "g_digits" "(PdfLayout_GridUpdate)")
              (action_tile "g_filexlsx" "(PdfLayout_GridReadXlsx)")
              (action_tile "g_btnxlsx" "(PdfLayout_GridPickXlsx)")
              (action_tile "g_xlsxsheet" "(PdfLayout_GridSheetChanged)")
              (action_tile "g_btnxlsxre" "(PdfLayout_GridReadXlsx)")
              (action_tile "ord1" "(setq *PdfLayout_PreviewOrder* \"1\") (PdfLayout_GridUpdate)")
              (action_tile "ord2" "(setq *PdfLayout_PreviewOrder* \"2\") (PdfLayout_GridUpdate)")
              (action_tile "ord3" "(setq *PdfLayout_PreviewOrder* \"3\") (PdfLayout_GridUpdate)")
              (action_tile "ord4" "(setq *PdfLayout_PreviewOrder* \"4\") (PdfLayout_GridUpdate)")
              (action_tile "ord5" "(setq *PdfLayout_PreviewOrder* \"5\") (PdfLayout_GridUpdate)")
              (action_tile "ord6" "(setq *PdfLayout_PreviewOrder* \"6\") (PdfLayout_GridUpdate)")
              (action_tile "ord7" "(setq *PdfLayout_PreviewOrder* \"7\") (PdfLayout_GridUpdate)")
              (action_tile "ord8" "(setq *PdfLayout_PreviewOrder* \"8\") (PdfLayout_GridUpdate)")
              (action_tile "accept" "(PdfLayout_GridAccept)")
              (action_tile "cancel" "(setq *PdfLayout_GridResult* 0) (done_dialog 0)")
              ;; 仅 PDFRENAME 用到：先把当前参数记下，再去框选下一个区域，回来重新打开本对话框
              (vl-catch-all-apply 'action_tile
                (list "g_addsel"
                      "(PdfLayout_GridUpdate) (setq *PdfLayout_GridResult* 3) (done_dialog 3)"))
              (setq *PdfLayout_GridResult* 0)
              (setq result (start_dialog))
              (unload_dialog dclId)
              (cond
                ((= *PdfLayout_GridResult* 1) "1")
                ((= *PdfLayout_GridResult* 3) "3")
                (t "0")
              )
            )
            (progn
              (unload_dialog dclId)
              "0"
            )
          )
        )
      )
    )
  )
)

(defun PdfLayout_GridApplyStyle (e / ed obj fac)
  ;; 背景填充：DXF 90/63/45 + ActiveX 兜底；文字颜色用 420 真彩色。
  ;; 说明：90=填充开关(0=关 / 1=使用背景填充色)，45=背景遮罩缩放因子；
  ;; 45 就是 CAD 特性面板里的“遮罩缩放因子”(默认1.5，1.0~5.0)，以前 45/90 写反导致调了不生效；
  ;; MTEXT 的 420=实体真彩色、421=背景填充真彩色，两者不能混用。
  (if (= (type e) 'VLA-OBJECT)
    (setq e (vlax-vla-object->ename e))
  )
  (setq ed (entget e))
  ;; 文字颜色：预设色写 62 ACI + 420 真彩色(420优先，白=白、黑=黑)；
  ;; 自定义 ACI 只写 62 并移除 420，避免残留真彩色。
  (if *PdfLayout_GridTxtTrue*
    (progn
      (if (assoc 62 ed)
        (setq ed (subst (cons 62 *PdfLayout_GridTxtColor*) (assoc 62 ed) ed))
        (setq ed (append ed (list (cons 62 *PdfLayout_GridTxtColor*))))
      )
      (if (assoc 420 ed)
        (setq ed (subst (cons 420 *PdfLayout_GridTxtRGB*) (assoc 420 ed) ed))
        (setq ed (append ed (list (cons 420 *PdfLayout_GridTxtRGB*))))
      )
    )
    (progn
      (if (assoc 62 ed)
        (setq ed (subst (cons 62 *PdfLayout_GridTxtColor*) (assoc 62 ed) ed))
        (setq ed (append ed (list (cons 62 *PdfLayout_GridTxtColor*))))
      )
      (if (assoc 420 ed)
        (setq ed (vl-remove (assoc 420 ed) ed))
      )
    )
  )
  (setq fac (max 1.0 (min 5.0 *PdfLayout_GridBgScale*)))
  ;; 背景填充按 DXF 规范写：90=填充开关(1=使用背景填充色) + 63 背景色 ACI + 45 缩放因子(1.0~5.0)。
  (if (= *PdfLayout_GridBg* "fill")
    (progn
      (if (assoc 90 ed)
        (setq ed (subst (cons 90 1) (assoc 90 ed) ed))
        (setq ed (append ed (list (cons 90 1))))
      )
      (if (assoc 63 ed)
        (setq ed (subst (cons 63 *PdfLayout_GridBgColor*) (assoc 63 ed) ed))
        (setq ed (append ed (list (cons 63 *PdfLayout_GridBgColor*))))
      )
      (if (assoc 421 ed)
        (setq ed (vl-remove (assoc 421 ed) ed))
      )
      (if (assoc 45 ed)
        (setq ed (subst (cons 45 fac) (assoc 45 ed) ed))
        (setq ed (append ed (list (cons 45 fac))))
      )
    )
    (progn
      (if (assoc 90 ed)
        (setq ed (subst (cons 90 0) (assoc 90 ed) ed))
        (setq ed (append ed (list (cons 90 0))))
      )
    )
  )
  (entmod ed)
  (setq obj (vlax-ename->vla-object e))
  (if (= *PdfLayout_GridBg* "fill")
    (progn
      (vl-catch-all-apply 'vla-put-BackgroundFill (list obj :vlax-true))
      (vl-catch-all-apply '(lambda () (vlax-put-property obj 'BackgroundFillUseDrawingBackgroundColor :vlax-false)) nil)
      (vl-catch-all-apply '(lambda () (vlax-put-property obj 'BackgroundFillColor *PdfLayout_GridBgColor*)) nil)
      (vl-catch-all-apply '(lambda () (vlax-put-property obj 'BackgroundFillGapFactor fac)) nil)
      (vl-catch-all-apply '(lambda () (vlax-put-property obj 'BackgroundFillScaleFactor fac)) nil)
      ;; 原生属性面板路径（setpropertyvalue），能走通时优先于 DXF
      (vl-catch-all-apply '(lambda () (setpropertyvalue e "BackgroundFill" "1")) nil)
      (vl-catch-all-apply '(lambda () (setpropertyvalue e "BackgroundFillUseDrawingBackgroundColor" "0")) nil)
      (vl-catch-all-apply '(lambda () (setpropertyvalue e "BackgroundFillColor" (itoa *PdfLayout_GridBgColor*))) nil)
      (foreach pn '("BackgroundScaleFactor" "BackgroundFillGapFactor" "BackgroundFillScaleFactor")
        (vl-catch-all-apply '(lambda () (setpropertyvalue e pn fac)) nil)
      )
      ;; ActiveX/属性面板可能覆盖组码，最后再用 DXF 写一次“填充开关 + 遮挡因子”保证生效
      (entmod ed)
    )
    (vl-catch-all-apply 'vla-put-BackgroundFill (list obj :vlax-false))
  )
  (entupd e)
  (vl-catch-all-apply 'vla-update (list obj))
  e
)

(defun PdfLayout_GridColorList ()
  ;; 预设颜色ACI表：红黄绿青蓝品红白灰黑橙深灰
  '(1 2 3 4 5 6 7 8 7 30 250)
)

(defun PdfLayout_GridRgbList ()
  ;; 与ACI表对应的真彩色RGB(0xRRGGBB)：黑=0
  '(255 65535 65280 65535 255 16711935 16777215 8421504 0 16753920 4210752)
)

(defun PdfLayout_GridColorRGB (aci / i)
  ;; 根据ACI返回对应RGB(真彩色)值，自定义返回 0
  (setq i (PdfLayout_GridColorIndex aci))
  (if (< i 11)
    (nth i (PdfLayout_GridRgbList))
    0
  )
)

(defun PdfLayout_GridColorIndex (aci / i)
  ;; 颜色索引号，0-10 对应预设颜色，11=自定义
  (setq i 0)
  (while (and (< i 11) (/= aci (nth i (PdfLayout_GridColorList))))
    (setq i (1+ i))
  )
  i
)

(defun PdfLayout_GridIndexByRGB (rgb / i)
  ;; 按真彩色RGB查找颜色索引（黑白按RGB区分），找不到返回11=自定义
  (setq i 0)
  (while (and (< i 11) (/= rgb (nth i (PdfLayout_GridRgbList))))
    (setq i (1+ i))
  )
  i
)

(defun PdfLayout_GridProcessExisting (/ pairs plan names pr pair i done total)
  ;; 处理已有文字：只按排序改名字，字高 / 文字色 / 背景遮挡都保持原状（PDFRENAME 命令专用）
  ;; 多批框选：按框选先后逐批处理，并且每一批都从“起始编号”重新编号（批内按位置排）
  (setq pairs *PdfLayout_GridSelPairs*)
  (if pairs
    (progn
      (setq plan (PdfLayout_RenamePlan *PdfLayout_PreviewOrder*))
      (setq total (length plan))
      (setq names (if (equal *PdfLayout_GridSrc* "xlsx") *PdfLayout_GridNames* nil))
      (setq i 0 done 0)
      (if (= (logand (getvar "UNDOCTL") 1) 1)
        (command "._UNDO" "_BE")
      )
      (foreach pr plan
        (setq pair (car pr))
        (setq name (PdfLayout_RenameNameAt names (cdr pr)))
        (if (and name (car pair))
          (progn
            (vl-catch-all-apply 'vla-put-TextString
              (list (vlax-ename->vla-object (car pair)) name))
            (setq done (1+ done))
          )
        )
        (setq i (1+ i))
      )
      (if (= (logand (getvar "UNDOCTL") 1) 1)
        (command "._UNDO" "_E")
      )
      (princ (strcat "\nPDFRENAME: 已处理 " (itoa done) " 个。"))
      (alert (strcat "PDFRENAME 完成\n\n已按排序方向 " *PdfLayout_PreviewOrder*
                     " 处理 " (itoa done) " 个"
                     (if (< done total)
                       "\n（文字多于名称，多余的未改名）" "")
                     (if (> (length *PdfLayout_GridSelBatches*) 1)
                       (strcat "\n（分 " (itoa (length *PdfLayout_GridSelBatches*))
                               " 批，每批都从起始编号重新编号）")
                       "")
                     "\n（只改名字，字高/颜色/背景保持现状）"))
    )
    (princ "\n未选择文字。")
  )
)

(defun c:pdfgrid (/ p1 p2 res doc blk pairs sorted i done name txtH rad m ins lay pt bb pmin pmax tw sel en)
  (vl-load-com)
  (PdfLayout_OrderPreviewClear)
  (PdfLayout_LoadSettings)
  ;; PDFGRID 只用「框选范围自动算」：固定绝对参数(F) 与 手动点取(M) 已移除
  (setq *PdfLayout_GridGeom* "1")
  (setq p1 (getpoint "\n点取网格范围第一角: "))
  (if p1
    (progn
      (setq p2 (getpoint p1 "\n点取网格范围对角: "))
      (if p2
        (progn
          (setq *PdfLayout_GridP1* p1 *PdfLayout_GridP2* p2)
          (setq *PdfLayout_GridExtX* (abs (- (car p2) (car p1))))
          (setq *PdfLayout_GridExtY* (abs (- (cadr p2) (cadr p1))))
          (setq *PdfLayout_GridStart*
                (list (min (car p1) (car p2)) (max (cadr p1) (cadr p2)) 0.0))
        )
      )
    )
  )
  (if (not *PdfLayout_GridStart*) (setq *PdfLayout_GridStart* '(0 0 0)))
  (setq res (PdfLayout_GridShowDialog))
  (if (= res "1")
      (progn
        (setq pairs (PdfLayout_GridPairsFromGlobals))
      (setq sorted (PdfLayout_SortPairsSmart pairs *PdfLayout_PreviewOrder*))
      (setq doc (vla-get-ActiveDocument (vlax-get-Acad-Object)))
      (if (= (getvar "TILEMODE") 1)
        (setq blk (vla-get-ModelSpace doc))
        (setq blk (vla-get-Block (vla-get-ActiveLayout doc)))
      )
      (setq txtH *PdfLayout_GridH*)
      (setq rad (* *PdfLayout_GridRot* (/ pi 180.0)))
      (setq i 0 done 0)
      (setq lay (PdfLayout_EnsureLayer "PDF网格文字"))
      (if (= (logand (getvar "UNDOCTL") 1) 1)
        (command "._UNDO" "_BE")
      )
      ;; 用 vla-AddMText 创建（背景填充 DXF 生效路径与 PDFLBD 一致），
      ;; 改"正中"附着点后中望不重排文字，读出插入点整体移到网格点，保证中心=网格点
      (foreach pair sorted
        (setq name (if (and (equal *PdfLayout_GridSrc* "xlsx") *PdfLayout_GridNames*
                            (< i (length *PdfLayout_GridNames*)))
                      (nth i *PdfLayout_GridNames*)
                      (PdfLayout_NameAtPrefix *PdfLayout_GridPrefix*
                                              (+ *PdfLayout_GridStartN* i)
                                              *PdfLayout_GridDigits*)))
        (setq pt (PdfLayout_BBoxCenter (cdr pair)))
        (setq m (vl-catch-all-apply 'vla-AddMText
                  (list blk (vlax-3d-point pt) 0.0 name)))
        (if (and m (not (vl-catch-all-error-p m)))
          (progn
            (vl-catch-all-apply 'vla-put-Height (list m txtH))
            (vl-catch-all-apply 'vla-put-AttachmentPoint (list m 5))
            ;; 先量真实文字宽度，再收紧文字框，背景遮罩才不会左右留太多
;; Width auto by font height: ideal = 4 * height, capped by grid column spacing
(setq tw (* txtH 4.0))
(if (and *PdfLayout_GridColSp* (> *PdfLayout_GridColSp* 0.0))
  (setq tw (min tw *PdfLayout_GridColSp*)))
(if (> tw 0.0)
  (vl-catch-all-apply 'vla-put-Width (list m tw)))
            (setq ins (vl-catch-all-apply
                        '(lambda () (vlax-safearray->list
                                      (vlax-variant-value (vla-get-InsertionPoint m))))
                        nil))
            (if (and ins (not (vl-catch-all-error-p ins)))
              (vl-catch-all-apply 'vla-Move (list m (vlax-3d-point ins) (vlax-3d-point pt)))
            )
            (if (/= rad 0.0)
              (vl-catch-all-apply 'vla-put-Rotation (list m rad))
            )
            (if (and lay (not (vl-catch-all-error-p lay)))
              (vl-catch-all-apply 'vla-put-Layer (list m "PDF网格文字"))
            )
            (PdfLayout_GridApplyStyle m)
            (vl-catch-all-apply
              '(lambda () (command "._DRAWORDER" (vlax-vla-object->ename m) "" "_Front"))
              nil)
            (setq done (1+ done))
          )
        )
        (setq i (1+ i))
      )
      (if (= (logand (getvar "UNDOCTL") 1) 1)
        (command "._UNDO" "_E")
      )
      (princ (strcat "\nPDFGRID: 已按排序生成 " (itoa done) " 个多行文字。"))
      (alert (strcat "PDFGRID 完成\n\n已按排序生成 " (itoa done) " 个多行文字。"
                     (if (< done (length pairs)) "\n（部分文字创建失败，请检查参数）" "")))
      )
    (princ "\n已取消。")
  )
  (princ)
)

(defun PdfLayout_CopyRowParseNum (s / i nstr)
  ;; 从末尾往前找最后一组数字（跳过末尾非数字字符），返回 (前缀 数字 位数)；找不到返回 nil
  (setq i (strlen s) nstr "")
  (while (and (>= i 1) (/= (PdfLayout_CharKind (substr s i 1)) "D"))
    (setq i (1- i))
  )
  (while (and (>= i 1) (= (PdfLayout_CharKind (substr s i 1)) "D"))
    (setq nstr (strcat (substr s i 1) nstr))
    (setq i (1- i))
  )
  (if (> (strlen nstr) 0)
    (list (substr s 1 i) (atoi nstr) (strlen nstr))
    nil
  )
)

(defun PdfLayout_RenamePlan (order / out b s)
  ;; 返回 ((pair . 批内序号) ...)：批次按框选先后；批内按 order 排序；
  ;; 关键：每一批的序号都从 0 重新开始，也就是“每个框选区域都从头编号”。
  (setq out nil)
  (if *PdfLayout_GridSelBatches*
    (foreach b *PdfLayout_GridSelBatches*
      (setq s 0)
      (foreach p (PdfLayout_SortPairsSmart b order)
        (setq out (append out (list (cons p s))))
        (setq s (1+ s))
      )
    )
    (progn
      (setq s 0)
      (foreach p (PdfLayout_SortPairsSmart *PdfLayout_GridSelPairs* order)
        (setq out (append out (list (cons p s))))
        (setq s (1+ s))
      )
    )
  )
  out
)

(defun PdfLayout_RenameBatchSorted (order)
  ;; 只取顺序（给顺序示意图用）
  (mapcar 'car (PdfLayout_RenamePlan order))
)

(defun PdfLayout_RenameNameAt (names seq)
  ;; 批内序号 seq（从 0 起）对应的名称：有 Excel 名单就用名单第 seq 个，否则“前缀 + 起始编号+seq”
  (if (and names (< seq (length names)))
    (nth seq names)
    (PdfLayout_NameAtPrefix *PdfLayout_GridPrefix*
                            (+ *PdfLayout_GridStartN* seq)
                            *PdfLayout_GridDigits*)
  )
)

(defun PdfLayout_RenameAddBatch (/ sel en bb i added batch)
  ;; 再框一批：累加到 *PdfLayout_GridSelPairs*（按图元名去重），同时按框选先后记进 *PdfLayout_GridSelBatches*
  (setq added 0 batch nil)
  (setq sel (ssget '((0 . "MTEXT"))))
  (if sel
    (progn
      (setq i 0)
      (while (setq en (ssname sel i))
        (setq bb (PdfLayout_GetExtentsSafeObj (vlax-ename->vla-object en)))
        (if (and bb (not (assoc en *PdfLayout_GridSelPairs*)))
          (progn
            (setq *PdfLayout_GridSelPairs*
                  (append *PdfLayout_GridSelPairs* (list (cons en bb))))
            (setq batch (append batch (list (cons en bb))))
            (setq added (1+ added))
          )
        )
        (setq i (1+ i))
      )
    )
  )
  (if batch (setq *PdfLayout_GridSelBatches* (append *PdfLayout_GridSelBatches* (list batch))))
  added
)

(defun c:pdfrename (/ res added)
  (vl-load-com)
  (PdfLayout_OrderPreviewClear)
  (PdfLayout_LoadSettings)
  (setq *PdfLayout_GridGeom* "S")
  (setq *PdfLayout_GridSelPairs* nil)
  (setq *PdfLayout_GridSelBatches* nil)
  (princ "\n[PDFRENAME] 框选要处理的多行文字(MTEXT): ")
  (PdfLayout_RenameAddBatch)
  (if (not *PdfLayout_GridSelPairs*)
    (princ "\n未选择文字，已取消。")
    (progn
      (if (not *PdfLayout_GridStart*) (setq *PdfLayout_GridStart* '(0 0 0)))
      (princ (strcat "\n已选 " (itoa (length *PdfLayout_GridSelPairs*))
                     " 个多行文字；在对话框里可继续框选累加，最后点确定一次改名。"))
      (setq res (PdfLayout_GridShowDialog))
      ;; 对话框里点了「继续框选下一个区域」：再框一批累加，然后重新打开对话框
      ;; （编号顺序仍按图面位置统一排，不按框选先后）
      (while (= res "3")
        (princ (strcat "\n继续框选下一个区域（已选 " (itoa (length *PdfLayout_GridSelPairs*))
                       " 个，直接回车=不再追加）: "))
        (setq added (PdfLayout_RenameAddBatch))
        (princ (strcat "\n  本批新增 " (itoa added) " 个，累计 "
                       (itoa (length *PdfLayout_GridSelPairs*)) " 个。"))
        (PdfLayout_OrderPreviewClear)
        (setq res (PdfLayout_GridShowDialog))
      )
      (if (= res "1")
        (PdfLayout_GridProcessExisting)
      )
    )
  )
  (princ)
)
(defun PdfLayout_GrOrtho (pt ref / om ddx ddy)
  ;; 每次调用都重读正交开关（兼容数字/字符串/真值）
  (setq om (getvar "ORTHOMODE"))
  (setq om (cond ((numberp om) om) (om 1) (t 0)))
  (if (= om 1)
    (progn
      (setq ddx (abs (- (car pt) (car ref))))
      (setq ddy (abs (- (cadr pt) (cadr ref))))
      (if (> ddy ddx)
        (list (car ref) (cadr pt) (if (caddr pt) (caddr pt) 0.0))
        (list (car pt) (cadr ref) (if (caddr pt) (caddr pt) 0.0))
      )
    )
    pt
  )
)

(defun PdfLayout_QuickCopyIncDrag (ss base / ents i en etype s ref pv cp pvlast idx no nm gr code val ptx running dist ang ptraw baseRef)
  (setq ents nil i 0)
  (while (setq en (ssname ss i))
    (setq ents (append ents (list en)))
    (setq i (1+ i))
  )
  ;; 找最后一组可递增的序号
  (setq i 0 ref nil)
  (while (and (not ref) (setq en (ssname ss i)))
    (setq etype (cdr (assoc 0 (entget en))))
    (if (member etype '("MTEXT" "TEXT"))
      (progn
        (setq s (vl-catch-all-apply 'vla-get-TextString (list (vlax-ename->vla-object en))))
        (setq ref (if (vl-catch-all-error-p s) nil (PdfLayout_CopyRowParseNum s)))
      )
    )
    (setq i (1+ i))
  )
  (if (not ref)
    (princ "\n所选文字里找不到可递增的序号，已取消。")
    (progn
      (princ "\n[递增] 移动鼠标实时预览 STR 落点，点一下落定一排并 +1，回车/Esc 结束。")
      (vl-catch-all-apply (quote vla-StartUndoMark) (list (vla-get-ActiveDocument (vlax-get-acad-object))))
      (setq pv nil idx 0 pvlast base baseRef base running T)
      (while running
        (setq gr (vl-catch-all-apply 'grread (list T 11 0)))
        (if (vl-catch-all-error-p gr) (setq gr nil))
        (setq code (if (and gr (car gr)) (car gr) -1) val (if gr (cadr gr) nil))
        (cond
          ((= code 5)
            (setq ptraw (trans val 1 1))
                (setq ptx (PdfLayout_GrOrtho ptraw baseRef))
            (if ptx
              (progn
                (setq dist (distance pvlast ptx))
                (setq ang (angle pvlast ptx))
                (princ (strcat "\r距离: " (rtos dist 2 2) "  角度: " (angtos ang 0 4) "  正交:" (if (= (getvar "ORTHOMODE") 1) "开" "关")))
                (if (not pv)
                  (progn
                    (foreach e ents
                      (setq cp (vl-catch-all-apply 'vla-Copy (list (vlax-ename->vla-object e))))
                      (if (and cp (not (vl-catch-all-error-p cp))) (setq pv (append pv (list cp))))
                    )
                    (setq pvlast base)
                    (setq nm (PdfLayout_NameAtPrefix (car ref) (+ (cadr ref) (1+ idx)) (caddr ref)))
                    (foreach e pv (vl-catch-all-apply 'vla-put-TextString (list e nm)))
                  )
                )
                (foreach e pv (vl-catch-all-apply 'vla-Move (list e (vlax-3d-point pvlast) (vlax-3d-point ptx))))
                (setq pvlast ptx)
              )
            )
          )
          ((= code 3)
            (setq ptraw (trans val 1 1))
                (setq ptx (PdfLayout_GrOrtho ptraw baseRef))
            (if ptx
              (progn
                (if (not pv)
                  (progn
                    (foreach e ents
                      (setq cp (vl-catch-all-apply 'vla-Copy (list (vlax-ename->vla-object e))))
                      (if (and cp (not (vl-catch-all-error-p cp))) (setq pv (append pv (list cp))))
                    )
                    (setq pvlast base)
                    (setq nm (PdfLayout_NameAtPrefix (car ref) (+ (cadr ref) (1+ idx)) (caddr ref)))
                    (foreach e pv (vl-catch-all-apply 'vla-put-TextString (list e nm)))
                  )
                )
                (setq no (+ (cadr ref) (1+ idx)))
                (setq nm (PdfLayout_NameAtPrefix (car ref) no (caddr ref)))
                (foreach e ents
                  (setq cp (vl-catch-all-apply 'vla-Copy (list (vlax-ename->vla-object e))))
                  (if (and cp (not (vl-catch-all-error-p cp)))
                    (progn
                      (vl-catch-all-apply 'vla-Move (list cp (vlax-3d-point '(0.0 0.0 0.0))
                        (vlax-3d-point (list (- (car ptx) (car base)) (- (cadr ptx) (cadr base)) 0.0))))
                      (setq etype (cdr (assoc 0 (entget e))))
                      (if (member etype '("MTEXT" "TEXT"))
                        (vl-catch-all-apply 'vla-put-TextString (list cp nm))
                      )
                    )
                  )
                )
                (setq idx (1+ idx))
                (setq baseRef ptx)
                (setq nm (PdfLayout_NameAtPrefix (car ref) (+ (cadr ref) (1+ idx)) (caddr ref)))
                (foreach e pv (vl-catch-all-apply 'vla-put-TextString (list e nm)))
              )
            )
          )
          ((= code 2)
            (cond
              ((or (= val 13) (= val 27) (= val 3)) (setq running nil))
              ((= val 15)
                (setvar "ORTHOMODE" (if (= (getvar "ORTHOMODE") 1) 0 1))
                (if (and pv ptraw)
                  (progn
                    (setq ptx (PdfLayout_GrOrtho ptraw baseRef))
                    (foreach e pv (vl-catch-all-apply (quote vla-Move) (list e (vlax-3d-point pvlast) (vlax-3d-point ptx))))
                    (setq pvlast ptx)
                  )
                )
              )
            )
          )
          ((= code 12)
            (setq running nil)
          )
          (t
            (setq running nil)
          )
        )
      )
      (foreach e pv (vl-catch-all-apply 'vla-Delete (list e)))
      (vl-catch-all-apply (quote vla-EndUndoMark) (list (vla-get-ActiveDocument (vlax-get-acad-object))))
      (princ (strcat "\nPDFQUICKCOPY: 已递增生成 " (itoa idx) " 排。"))
    )
  )
  (princ)
)

(defun c:pdfquickcopy (/ ss n dx inc hasText k i en bb base etype)
  (vl-load-com)
  (princ "\n[PDFQUICKCOPY] 请框选要复制的一组对象(可含要递增的多行文字): ")
  (setq ss (ssget))
  (if (not ss)
    (princ "\n未选择对象，已取消。")
    (progn
      ;; 基准点 = 选中第一个多行文字的中心；同时判断是否含文字
      (setq bb nil hasText nil i 0)
      (while (and (not bb) (setq en (ssname ss i)))
        (setq etype (cdr (assoc 0 (entget en))))
        (if (member etype '("MTEXT" "TEXT")) (setq hasText T))
        (if (= etype "MTEXT")
          (setq bb (PdfLayout_GetExtentsSafeObj (vlax-ename->vla-object en)))
        )
        (setq i (1+ i))
      )
      (setq base (if bb (PdfLayout_BBoxCenter bb) '(0 0 0)))
      ;; 是否递增
      (setq inc "N")
      (if hasText
        (progn
          (initget "Y N")
          (setq inc (getkword "\n编号是否递增? Y=是 / N=否 <Y>: "))
          (if (not inc) (setq inc "Y"))
        )
      )
      (if (= inc "Y")
        ;; 递增：原生COPY式拖动（带实时预览）
        (PdfLayout_QuickCopyIncDrag ss base)
        ;; 不递增：原数量式（几列 + 列距）
        (progn
          (setq n (getint "\n复制成几列(含原对象，默认2)? "))
          (if (not n) (setq n 2))
          (setq dx (getdist "\n列间距(直接输入数字或点取两点): "))
          (if (not dx) (setq dx 0))
          (if (or (< n 2) (<= dx 0))
            (princ "\n列数需 ≥2 且间距 >0，已取消。")
            (progn
              (vl-catch-all-apply (quote vla-StartUndoMark) (list (vla-get-ActiveDocument (vlax-get-acad-object))))
              (setq k 1)
              (while (< k n)
                (command "._COPY" ss "" base (list (+ (car base) (* k dx)) (cadr base) 0.0))
                (setq k (1+ k))
              )
              (vl-catch-all-apply (quote vla-EndUndoMark) (list (vla-get-ActiveDocument (vlax-get-acad-object))))
              (princ (strcat "\n已复制成 " (itoa n) " 列，列间距 " (rtos dx 2 2)
                             "（以文字中心为基准，不递增编号）。"))
            )
          )
        )
      )
    )
  )
  (princ)
)

;;;-------------------------------------------------------------
;;; 刷内容 PDFBRUSH —— 选一个源文字，把其他文字的内容刷成它
;;;   可刷：多行文字(MTEXT)、单行文字(TEXT)、块属性值(ATTRIB)、
;;;         尺寸标注文字(DIMENSION)、多重引线(MULTILEADER)、
;;;         旧式引线(LEADER)、形位公差(TOLERANCE)、表格单元格(ACAD_TABLE)
;;;   不刷：块定义里的文字（块内文字），点选到只提示并跳过
;;;   整轮刷内容合成一次撤销，输入 U 一次全撤
;;;-------------------------------------------------------------
(setq *PdfLayout_BrushMode* "1")   ; 1=只刷内容  2=连外观一起刷(样式/字高/颜色)
(setq *PdfLayout_BrushPure* nil)   ; nil=原样复制(保留 MTEXT 格式码)  T=剥成纯文本

(defun PdfLayout_BrushType (en / ed)
  ;; 取实体类型名；取不到返回 nil
  (setq ed (vl-catch-all-apply 'entget (list en)))
  (if (or (null ed) (vl-catch-all-error-p ed))
    nil
    (cdr (assoc 0 ed))
  )
)

(defun PdfLayout_BrushTypeName (typ)
  ;; 类型名转成给用户看的中文
  (if (null typ)
    "非文字对象"
    (cond
      ((= typ "TEXT") "单行文字")
      ((= typ "MTEXT") "多行文字")
      ((= typ "ATTRIB") "块属性")
      ((= typ "ATTDEF") "属性定义")
      ((= typ "DIMENSION") "尺寸标注")
      ((= typ "MULTILEADER") "多重引线")
      ((= typ "LEADER") "引线")
      ((= typ "TOLERANCE") "形位公差")
      ((= typ "ACAD_TABLE") "表格")
      ((= typ "INSERT") "块参照")
      (t "非文字对象")
    )
  )
)

(defun PdfLayout_BrushUsableP (en / typ)
  ;; 这个对象能不能读写文字内容
  (setq typ (PdfLayout_BrushType en))
  (if (member typ '("TEXT" "MTEXT" "ATTRIB" "ATTDEF" "DIMENSION" "MULTILEADER" "LEADER" "TOLERANCE" "ACAD_TABLE"))
    T
    nil
  )
)

(defun PdfLayout_BrushOwnerIsInsertP (en / ed own ownE od)
  ;; 判断实体是不是挂在块参照上的属性值
  ;; 不同版本 nentsel 返回的可能是 ATTRIB，也可能是属性定义 ATTDEF，用 330 属主区分
  (setq ed (vl-catch-all-apply 'entget (list en)))
  (if (or (null ed) (vl-catch-all-error-p ed))
    nil
    (progn
      (setq own (cdr (assoc 330 ed)))
      ;; 330 一般是句柄字符串；有的环境给的是实体名，类型不对就直接放弃判断
      (if (/= (type own) 'STR)
        nil
        (progn
          (setq ownE (vl-catch-all-apply 'handent (list own)))
          (if (or (null ownE) (vl-catch-all-error-p ownE))
            nil
            (progn
              (setq od (vl-catch-all-apply 'entget (list ownE)))
              (if (or (null od) (vl-catch-all-error-p od))
                nil
                (= (cdr (assoc 0 od)) "INSERT")
              )
            )
          )
        )
      )
    )
  )
)

(defun PdfLayout_BrushNestedBlockedP (pick / typ)
  ;; 块内文字不支持：nentsel 给出了变换矩阵（点到的是块里的东西），
  ;; 而它不是块属性值时，判为块内文字，跳过
  (if (not (nth 2 pick))
    nil
    (progn
      (setq typ (PdfLayout_BrushType (car pick)))
      (if (null typ)
        T
        (if (= typ "ATTRIB")
          nil
          (if (PdfLayout_BrushOwnerIsInsertP (car pick)) nil T)
        )
      )
    )
  )
)

(defun PdfLayout_BrushStripCodes (s / n i j c nxt out stop k lim)
  ;; 把 MTEXT 的内联格式码剥掉，得到能安全写进 TEXT / 标注文字的纯文本
  ;;   \P \~ -> 空格；\{ \} \\ 还原；\A1; \f...; \H...; \C1; \p...; 等丢弃；
  ;;   \S1/2; 堆叠分数 -> 1/2；未转义的 { } 分组符号去掉
  ;;   普通文字整段拷贝，避免逐字符拼接把双字节汉字切断
  (if (null s) (setq s ""))
  (setq n (strlen s) i 1 out "")
  (while (<= i n)
    (setq c (substr s i 1))
    (cond
      ((= c "\\")
       (setq nxt (substr s (1+ i) 1))
       (cond
         ((= nxt "") (setq i (1+ i)))
         ((= nxt "\\") (setq out (strcat out "\\") i (+ i 2)))
         ((or (= nxt "{") (= nxt "}")) (setq out (strcat out nxt) i (+ i 2)))
         ((or (= nxt "P") (= nxt "~")) (setq out (strcat out " ") i (+ i 2)))
         ((= nxt "S")
          (setq i (+ i 2) k "" stop nil lim 0)
          (while (and (<= i n) (not stop) (< lim 128))
            (if (= (substr s i 1) ";")
              (setq stop T i (1+ i))
              (progn
                (if (/= (substr s i 1) "^") (setq k (strcat k (substr s i 1))))
                (setq i (1+ i) lim (1+ lim))
              )
            )
          )
          (setq out (strcat out k))
         )
         ((or (and (>= (ascii nxt) 65) (<= (ascii nxt) 90))
              (and (>= (ascii nxt) 97) (<= (ascii nxt) 122)))
          (if (member (strcase nxt) '("L" "O" "K" "N" "X"))
            ;; 无参数开关码：只吃掉反斜杠和这一个字母
            (setq i (+ i 2))
            ;; 带参数的格式码：一直吃到分号
            (progn
              (setq i (+ i 2) stop nil lim 0)
              (while (and (<= i n) (not stop) (< lim 128))
                (if (= (substr s i 1) ";")
                  (setq stop T i (1+ i))
                  (setq i (1+ i) lim (1+ lim))
                )
              )
            )
          )
         )
         (t (setq i (1+ i)))
       )
      )
      ((or (= c "{") (= c "}")) (setq i (1+ i)))
      (t
       (setq j (1+ i))
       (while (and (<= j n)
                   (/= (substr s j 1) "\\")
                   (/= (substr s j 1) "{")
                   (/= (substr s j 1) "}"))
         (setq j (1+ j))
       )
       (setq out (strcat out (substr s i (- j i))))
       (setq i j)
      )
    )
  )
  out
)

(defun PdfLayout_BrushDxf304 (ed / s v)
  ;; 多重引线/引线的文字存在 304 组码里（可能多条），逐条拼起来
  (setq s "")
  (if (or (null ed) (vl-catch-all-error-p ed))
    s
    (progn
      (foreach v ed
        (if (= (car v) 304) (setq s (strcat s (cdr v))))
      )
      s
    )
  )
)

(defun PdfLayout_BrushSetDxf304 (en s / ed out hit res)
  ;; 写 304 组码（引线的文字）：保留其它组码，只替换第一条文字，多余的行去掉
  (setq ed (entget en) out nil hit nil)
  (if (null ed)
    nil
    (progn
      (foreach v ed
        (if (= (car v) 304)
          (if (not hit) (setq out (append out (list (cons 304 s))) hit T))
          (setq out (append out (list v)))
        )
      )
      (if (not hit) (setq out (append out (list (cons 304 s)))))
      (setq res (vl-catch-all-apply 'entmod (list out)))
      (if (vl-catch-all-error-p res)
        nil
        (progn (vl-catch-all-apply 'entupd (list en)) T)
      )
    )
  )
)

(defun PdfLayout_BrushDxf1 (en / ed s s3 v)
  ;; 兜底读取：DXF 组码 1（多行文字超过 250 字符时，前面还有若干组码 3）
  (setq ed (vl-catch-all-apply 'entget (list en)))
  (if (or (null ed) (vl-catch-all-error-p ed))
    nil
    (progn
      (setq s3 "")
      (foreach v ed
        (if (= (car v) 3) (setq s3 (strcat s3 (cdr v))))
      )
      (setq s (cdr (assoc 1 ed)))
      (strcat s3 (if s s ""))
    )
  )
)

(defun PdfLayout_BrushSetDxf1 (en s / ed res out v)
  ;; 兜底写入：直接改组码 1；超过 250 字符要分组写入，这里只处理 250 以内
  (setq ed (vl-catch-all-apply 'entget (list en)))
  (if (or (null ed) (vl-catch-all-error-p ed) (> (strlen s) 250))
    nil
    (progn
      ;; 多行文字超长时的组码 3 分块要先去掉，再整段写进组码 1
      (if (assoc 3 ed)
        (progn
          (setq out nil)
          (foreach v ed
            (if (/= (car v) 3) (setq out (append out (list v))))
          )
          (setq ed out)
        )
      )
      (if (assoc 1 ed)
        (setq ed (subst (cons 1 s) (assoc 1 ed) ed))
        (setq ed (append ed (list (cons 1 s))))
      )
      (setq res (vl-catch-all-apply 'entmod (list ed)))
      (if (vl-catch-all-error-p res)
        nil
        (progn (vl-catch-all-apply 'entupd (list en)) T)
      )
    )
  )
)

(defun PdfLayout_BrushTableRCRaw (en pt / obj ip rawdir dir dx dy u v i acc w col j row h n)
  ;; 由拾取点算表格单元格的行列号（都是 0 基）；点在表外或接口不支持时返回 nil
  (setq obj (vl-catch-all-apply 'vlax-ename->vla-object (list en)))
  (if (vl-catch-all-error-p obj) (setq obj nil))
  (if (and obj pt)
    (progn
      (setq ip (vl-catch-all-apply 'vla-get-InsertionPoint (list obj)))
      (if (vl-catch-all-error-p ip) (setq ip nil))
      (setq rawdir (vl-catch-all-apply 'vla-get-Direction (list obj)))
      (if (vl-catch-all-error-p rawdir) (setq rawdir 0.0))
      (cond
        ((numberp rawdir) (setq dir rawdir))
        ((and (listp rawdir) (cadr rawdir) ip)
         (setq dir (angle (list (car ip) (cadr ip) 0.0) (list (car rawdir) (cadr rawdir) 0.0))))
        (t (setq dir 0.0))
      )
      (if (null ip)
        nil
        (progn
          (setq dx (- (car pt) (car ip)) dy (- (cadr pt) (cadr ip)))
          (setq u (+ (* dx (cos dir)) (* dy (sin dir))))
          (setq v (+ (* (- dx) (sin dir)) (* dy (cos dir))))
          (setq i 0 acc 0.0 col nil n 0)
          (while (and (null col) (< n 200))
            (setq w (vl-catch-all-apply 'vla-GetColumnWidth (list obj i)))
            (if (or (vl-catch-all-error-p w) (null w) (not (numberp w)) (<= w 0.0))
              (setq n 200)
              (if (and (>= u acc) (< u (+ acc w)))
                (setq col i)
                (setq acc (+ acc w) i (1+ i) n (1+ n))
              )
            )
          )
          (setq j 0 acc 0.0 row nil n 0)
          (while (and (null row) (< n 200))
            (setq h (vl-catch-all-apply 'vla-GetRowHeight (list obj j)))
            (if (or (vl-catch-all-error-p h) (null h) (not (numberp h)) (<= h 0.0))
              (setq n 200)
              (if (and (>= v acc) (< v (+ acc h)))
                (setq row j)
                (setq acc (+ acc h) j (1+ j) n (1+ n))
              )
            )
          )
          (if (and row col) (cons row col) nil)
        )
      )
    )
    nil
  )
)

(defun PdfLayout_BrushTableRC (en pt / rc pt2)
  ;; 拾取点的坐标系（UCS/WCS）各版本不一致，两种都试一遍
  (setq rc (if pt (PdfLayout_BrushTableRCRaw en pt) nil))
  (if (and (null rc) pt)
    (progn
      (setq pt2 (vl-catch-all-apply 'trans (list pt 1 0)))
      (if (not (vl-catch-all-error-p pt2))
        (setq rc (PdfLayout_BrushTableRCRaw en pt2))
      )
    )
  )
  rc
)

(defun PdfLayout_BrushStrP (v)
  ;; 从接口返回值里取一个能用的字符串：nil / 错误对象 / 空串 / 非字符串 都算没有
  (if (null v)
    nil
    (if (vl-catch-all-error-p v)
      nil
      (if (eq (type v) 'STR)
        (if (= v "") nil v)
        nil
      )
    )
  )
)

(defun PdfLayout_BrushDimBlockText (en / ed bname blk e typ s v)
  ;; 标注没设文字替代时（显示的是测量值），退一步读标注几何块里那行实际显示的文字
  (setq ed (vl-catch-all-apply 'entget (list en)))
  (if (or (null ed) (vl-catch-all-error-p ed))
    nil
    (progn
      (setq bname (cdr (assoc 2 ed)))
      (setq blk (if bname (tblsearch "BLOCK" bname) nil))
      (setq e (if blk (cdr (assoc -2 blk)) nil))
      (setq s nil)
      (while (and e (null s))
        (setq typ (PdfLayout_BrushType e))
        (if (null typ)
          nil
          (if (or (= typ "MTEXT") (= typ "TEXT"))
            (setq s (PdfLayout_BrushStrP (PdfLayout_BrushDxf1 e)))
          )
        )
        (setq e (entnext e))
      )
      s
    )
  )
)

(defun PdfLayout_BrushGetContent (en pt / typ obj v rc)
  ;; 读一个文字对象的内容；不支持或读不到返回 nil
  (setq typ (PdfLayout_BrushType en))
  (cond
    ((member typ '("TEXT" "MTEXT" "ATTDEF" "ATTRIB" "TOLERANCE" "MULTILEADER"))
     (setq obj (vl-catch-all-apply 'vlax-ename->vla-object (list en)))
     (setq v (PdfLayout_BrushStrP
               (if (or (null obj) (vl-catch-all-error-p obj))
                 nil
                 (vl-catch-all-apply 'vla-get-TextString (list obj)))))
     (if (null v)
       ;; 接口取不到时兜底：直接读 DXF 组码
       (setq v (PdfLayout_BrushStrP
                 (if (= typ "MULTILEADER")
                   (PdfLayout_BrushDxf304 (vl-catch-all-apply 'entget (list en)))
                   (PdfLayout_BrushDxf1 en))))
     )
     v
    )
    ((= typ "DIMENSION")
     ;; 标注文字 = 文字替代(TextOverride / DXF 组码 1)；没设替代时读标注块里显示的文字
     (setq obj (vl-catch-all-apply 'vlax-ename->vla-object (list en)))
     (setq v (PdfLayout_BrushStrP
               (if (or (null obj) (vl-catch-all-error-p obj))
                 nil
                 (vl-catch-all-apply 'vla-get-TextOverride (list obj)))))
     (if (null v) (setq v (PdfLayout_BrushStrP (PdfLayout_BrushDxf1 en))))
     (if (null v) (setq v (PdfLayout_BrushStrP (PdfLayout_BrushDimBlockText en))))
     v
    )
    ((= typ "LEADER")
     (PdfLayout_BrushStrP (PdfLayout_BrushDxf304 (vl-catch-all-apply 'entget (list en)))))
    ((= typ "ACAD_TABLE")
     (setq rc (PdfLayout_BrushTableRC en pt))
     (if rc
       (progn
         (setq obj (vl-catch-all-apply 'vlax-ename->vla-object (list en)))
         (if (vl-catch-all-error-p obj)
           nil
           (progn
             (setq v (PdfLayout_BrushStrP
                       (vl-catch-all-apply 'vla-GetTextString (list obj (car rc) (cdr rc)))))
             v
           )
         )
       )
       nil
     )
    )
    (t nil)
  )
)

(defun PdfLayout_BrushSetContent (en pt s / typ obj res rc own)
  ;; 写一个文字对象的内容；成功返回 T
  (setq typ (PdfLayout_BrushType en))
  (cond
    ((member typ '("TEXT" "MTEXT" "ATTDEF" "ATTRIB" "TOLERANCE" "MULTILEADER"))
     (setq obj (vl-catch-all-apply 'vlax-ename->vla-object (list en)))
     (if (vl-catch-all-error-p obj)
       nil
       (progn
         ;; 单行文字、公差、标注不认 MTEXT 格式码，一律剥成纯文本
         (if (or (member typ '("TEXT" "TOLERANCE"))
                 (and *PdfLayout_BrushPure* (member typ '("MTEXT" "MULTILEADER"))))
           (setq s (PdfLayout_BrushStripCodes s))
         )
         (setq res (vl-catch-all-apply 'vla-put-TextString (list obj s)))
         (if (vl-catch-all-error-p res)
           ;; 接口写不进去时兜底：直接改 DXF 组码
           (if (= typ "MULTILEADER") (PdfLayout_BrushSetDxf304 en s) (PdfLayout_BrushSetDxf1 en s))
           (progn
             ;; 块属性改完要让所属的块参照一起刷新，否则有的 CAD 要等重生成才显示
             (if (= typ "ATTRIB")
               (progn
                 (setq own (cdr (assoc 330 (entget en))))
                 (if (= (type own) 'STR) (vl-catch-all-apply 'entupd (list (handent own))))
               )
             )
             (vl-catch-all-apply 'entupd (list en))
             T
           )
         )
       )
     )
    )
    ((= typ "DIMENSION")
     ;; 标注文字替代：先试接口，接口不行就直接改 DXF 组码 1
     (setq obj (vl-catch-all-apply 'vlax-ename->vla-object (list en)))
     (setq res (if (or (null obj) (vl-catch-all-error-p obj))
                nil
                (vl-catch-all-apply 'vla-put-TextOverride
                  (list obj (PdfLayout_BrushStripCodes s)))))
     (if (or (null res) (vl-catch-all-error-p res))
       (PdfLayout_BrushSetDxf1 en (PdfLayout_BrushStripCodes s))
       (progn (vl-catch-all-apply 'entupd (list en)) T)
     )
    )
    ((= typ "LEADER") (PdfLayout_BrushSetDxf304 en s))
    ((= typ "ACAD_TABLE")
     (setq rc (PdfLayout_BrushTableRC en pt))
     (if rc
       (progn
         (setq obj (vl-catch-all-apply 'vlax-ename->vla-object (list en)))
         (if (vl-catch-all-error-p obj)
           nil
           (progn
             (setq res (vl-catch-all-apply 'vla-SetTextString
                        (list obj (car rc) (cdr rc) s)))
             (if (vl-catch-all-error-p res)
               nil
               (progn (vl-catch-all-apply 'entupd (list en)) T)
             )
           )
         )
       )
       nil
     )
    )
    (t nil)
  )
)

(defun PdfLayout_BrushCopyAppearance (srcE dstE / sed ded typS typD grps entry res)
  ;; 连外观一起刷：把源文字的样式/字高/颜色（同为多行文字时还带背景和附着方式）复制到目标
  (setq sed (entget srcE) ded (entget dstE))
  (setq typS (cdr (assoc 0 sed)) typD (cdr (assoc 0 ded)))
  (if (and sed ded
           (member typS '("TEXT" "MTEXT" "ATTRIB" "ATTDEF"))
           (member typD '("TEXT" "MTEXT" "ATTRIB" "ATTDEF")))
    (progn
      (setq grps '(7 40 62 420))
      (if (and (= typS "MTEXT") (= typD "MTEXT"))
        (setq grps (append grps '(45 63 421 90 71 72 73)))
      )
      (foreach grp grps
        (setq entry (assoc grp sed))
        (if entry
          (if (assoc grp ded)
            (setq ded (subst entry (assoc grp ded) ded))
            (setq ded (append ded (list entry)))
          )
        )
      )
      (setq res (vl-catch-all-apply 'entmod (list ded)))
      (vl-catch-all-apply 'entupd (list dstE))
      T
    )
    nil
  )
)

(defun PdfLayout_BrushApply (en pt srcTxt srcE / ok)
  ;; 刷一个对象：先写内容，需要时再刷外观
  (setq ok (PdfLayout_BrushSetContent en pt srcTxt))
  (if (and ok (= *PdfLayout_BrushMode* "2") (not (equal en srcE)))
    (PdfLayout_BrushCopyAppearance srcE en)
  )
  ok
)

(defun PdfLayout_BrushPickNested (insE pt / r en typ)
  ;; 点到块参照时，用拾取点再看落在块内哪个子实体上：
  ;; 块属性值可以刷（只影响这一个块参照）；块内文字（非属性）交给上层跳过
  (setq r (vl-catch-all-apply 'nentselp (list pt)))
  (if (or (null r) (vl-catch-all-error-p r))
    (list insE pt nil)
    (progn
      (setq en (car r))
      ;; 多段线顶点之类会返回 (实体 . 序号)
      (if (and (listp en) (car en)) (setq en (car en)))
      (if (not (eq (type en) 'ENAME))
        (list insE pt nil)
        (progn
          (setq typ (PdfLayout_BrushType en))
          (if (null typ)
            (list insE pt nil)
            (if (= typ "INSERT")
              (list insE pt nil)
              (list en pt T)
            )
          )
        )
      )
    )
  )
)

(defun PdfLayout_BrushPick (msg / r en pt typ)
  ;; 单点拾取，返回 (实体 拾取点 是否块内)；
  ;; 用 entsel 而不是 nentsel：entsel 不会钻进标注的匿名块，标注/表格都能直接拾到本体
  (setq r (vl-catch-all-apply 'entsel (list msg)))
  (if (or (null r) (vl-catch-all-error-p r))
    nil
    (progn
      (setq en (car r) pt (cadr r))
      (if (not (and (listp pt) (car pt))) (setq pt nil))
      (setq typ (PdfLayout_BrushType en))
      (if (null typ)
        (list en pt nil)
        (if (not (= typ "INSERT"))
          (list en pt nil)
          (if (null pt)
            (list en pt nil)
            (PdfLayout_BrushPickNested en pt)
          )
        )
      )
    )
  )
)

(defun PdfLayout_BrushSummary (cnt skip)
  (princ (strcat "\n刷内容完成：已刷 " (itoa cnt) " 个"
                 (if (> skip 0) (strcat "，跳过 " (itoa skip) " 个") "") "。"))
  (princ "\n  撤销：输入 U 或 Ctrl+Z（整轮一次撤销）")
)

(defun PdfLayout_BrushRunPoint (srcE srcTxt / doc pick en pt cnt skip)
  ;; 逐点连续刷：点一个刷一个，回车/Esc 结束
  (setq cnt 0 skip 0)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (vl-catch-all-apply 'vla-EndUndoMark (list doc))
  (vl-catch-all-apply 'vla-StartUndoMark (list doc))
  (while
    (progn
      (setq pick (PdfLayout_BrushPick "\n点选要刷的文字 <回车或 Esc 结束>: "))
      (if (null pick)
        nil
        (progn
          (setq en (car pick) pt (cadr pick))
          (cond
            ((equal en srcE)
             (princ "\r  * 就是源文字本身，跳过                      "))
            ((PdfLayout_BrushNestedBlockedP pick)
             (setq skip (1+ skip))
             (princ "\r  * 该文字在块里（块内文字不支持），跳过        "))
            ((not (PdfLayout_BrushUsableP en))
             (setq skip (1+ skip))
             (princ (strcat "\r  * " (PdfLayout_BrushTypeName (PdfLayout_BrushType en)) "，不支持刷内容，跳过     ")))
            ((PdfLayout_BrushApply en pt srcTxt srcE)
             (setq cnt (1+ cnt))
             (princ (strcat "\r  * 已刷 " (itoa cnt) " 个"
                            (if (> skip 0) (strcat "，跳过 " (itoa skip) " 个") "") "            ")))
            (t
             (setq skip (1+ skip))
             (princ "\r  * 写入失败（图层锁定或只读），跳过          "))
          )
          T
        )
      )
    )
  )
  (vl-catch-all-apply 'vla-EndUndoMark (list doc))
  (PdfLayout_BrushSummary cnt skip)
  (princ)
)

(defun PdfLayout_BrushRunWindow (srcE srcTxt / doc ss i en cnt skip more)
  ;; 框选批量刷：整段文字类对象一次全刷；块参照和表格要按点逐个刷
  (setq cnt 0 skip 0 more T)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (vl-catch-all-apply 'vla-EndUndoMark (list doc))
  (vl-catch-all-apply 'vla-StartUndoMark (list doc))
  (princ "\n框选要刷的文字范围（块参照、表格请改用逐点点选）")
  (while more
    (princ "\n框选要刷的文字 <回车结束>: ")
    (setq ss (ssget '((0 . "TEXT,MTEXT,DIMENSION,MULTILEADER,LEADER,TOLERANCE"))))
    (if (null ss)
      (setq more nil)
      (progn
        (setq i 0)
        (while (< i (sslength ss))
          (setq en (ssname ss i))
          (if (not (equal en srcE))
            (if (PdfLayout_BrushApply en nil srcTxt srcE)
              (setq cnt (1+ cnt))
              (setq skip (1+ skip))
            )
          )
          (setq i (1+ i))
        )
        (princ (strcat "\r  * 已刷 " (itoa cnt) " 个"
                       (if (> skip 0) (strcat "，跳过 " (itoa skip) " 个") "") "            "))
      )
    )
  )
  (vl-catch-all-apply 'vla-EndUndoMark (list doc))
  (PdfLayout_BrushSummary cnt skip)
  (princ)
)

(defun c:pdfbrush (/ res doc)
  ;; 刷内容主命令：外面套一层保险，万一出错只提示一行，不抛到全局错误处理
  (vl-load-com)
  (PdfLayout_LoadSettings)
  (setq res (vl-catch-all-apply 'PdfLayout_BrushMain nil))
  (if (vl-catch-all-error-p res)
    (progn
      (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
      (vl-catch-all-apply 'vla-EndUndoMark (list doc))
      (princ (strcat "\n刷内容中断：" (vl-catch-all-error-message res)))
      (princ "\n  已刷上的部分可以输入 U 撤销。")
    )
  )
  (princ)
)

(defun PdfLayout_BrushMain (/ pick srcE srcTxt en kw running)
  ;; 选源文字 -> 选模式 -> 逐个点选或框选批量
  (princ "\n[PDFBRUSH 刷内容] 选一个源文字，再把其他文字的内容刷成它")
  (princ "\n  可刷: 多行/单行文字、块属性、标注文字、多重引线、引线、形位公差、表格单元格")
  (princ "\n  不刷: 块定义里的文字（块内文字）")
  (setq srcE nil)
  (while (null srcE)
    (setq pick (PdfLayout_BrushPick "\n选择源文字 <点选，回车取消>: "))
    (cond
      ((null pick)
       (princ "\n已取消。")
       (setq srcE 'cancel)
      )
      ((PdfLayout_BrushNestedBlockedP pick)
       (princ "\n  * 块内文字不支持刷内容（块属性可以刷），请重新选择。")
      )
      ((not (PdfLayout_BrushUsableP (car pick)))
       (princ (strcat "\n  * " (PdfLayout_BrushTypeName (PdfLayout_BrushType (car pick)))
                      " 不是可刷的文字对象，请重新选择。"))
      )
      (t
       (setq en (car pick))
       (setq srcTxt (PdfLayout_BrushGetContent en (cadr pick)))
       (if (and srcTxt (/= srcTxt ""))
         (progn
           (setq srcE en)
           (princ (strcat "\n源内容(" (PdfLayout_BrushTypeName (PdfLayout_BrushType en)) "): "
                          (PdfLayout_EllipsisMid srcTxt 60)))
         )
         (princ "\n  * 这个对象读不到文字内容（比如标注用的是测量值），请重新选择。")
       )
      )
    )
  )
  (if (eq srcE 'cancel)
    (princ "\n")
    (progn
      (setq running T)
      (while running
        (initget "W P K")
        (setq kw (getkword (strcat "\n[W]=框选批量刷  [P]=纯文本:"
                                   (if *PdfLayout_BrushPure* "开" "关")
                                   "  [K]=连外观一起刷:"
                                   (if (= *PdfLayout_BrushMode* "2") "开" "关")
                                   "  <回车=开始逐点连续刷>: ")))
        (cond
          ((null kw) (setq running nil) (PdfLayout_BrushRunPoint srcE srcTxt))
          ((= kw "P")
           (setq *PdfLayout_BrushPure* (not *PdfLayout_BrushPure*))
           (PdfLayout_SaveSettings))
          ((= kw "K")
           (setq *PdfLayout_BrushMode* (if (= *PdfLayout_BrushMode* "2") "1" "2"))
           (PdfLayout_SaveSettings))
          ((= kw "W") (setq running nil) (PdfLayout_BrushRunWindow srcE srcTxt))
          (t (setq running nil))
        )
      )
    )
  )
  (princ)
)
(defun c:pdfaddbuttons (/ app tb tbar t lst it)
  (vl-load-com)
  (setq app (vlax-get-acad-object))
  (setq tb (vl-catch-all-apply 'vla-get-Toolbars (list app)))
  (if (or (vl-catch-all-error-p tb) (null tb))
    (princ "\n当前 CAD 不支持经典工具栏(COM)，无法自动添加；请改用 CUI 文件方案。")
    (progn
      (setq tbar nil)
      (vlax-for t tb
        (if (member (vla-get-Name t) (list "MAP工具箱" "PDF工具")) (setq tbar t))
      )
      (if (not tbar)
        (setq tbar (vl-catch-all-apply 'vla-Add (list tb "MAP工具箱" 0)))
      )
      (if (and tbar (not (vl-catch-all-error-p tbar)))
        (progn
          (setq lst (list (cons "批量网格文字(Grid)" (strcat (chr 3) (chr 3) "pdfgrid "))
                          (cons "图纸/布局(Layout)" (strcat (chr 3) (chr 3) "pdflayout "))
                          (cons "快速复制(Copy)" (strcat (chr 3) (chr 3) "pdfquickcopy "))
                          (cons "顺序重命名(Rename)" (strcat (chr 3) (chr 3) "pdfrename "))
                          (cons "LBD识别(LBD)" (strcat (chr 3) (chr 3) "pdflbd "))
                          (cons "工具箱(Tool)" (strcat (chr 3) (chr 3) "pdftool "))))
          (foreach it lst
            (vl-catch-all-apply 'vla-AddToolbarButton
                                (list tbar -1 (car it) (car it) (cdr it)))
          )
          (vl-catch-all-apply 'vla-put-Visible (list tbar :vlax-true))
          (princ "\n已添加 \"MAP工具箱\" 工具栏。")
        )
        (princ "\n创建工具栏失败。")
      )
    )
  )
  (princ)
)



;;;-------------------------------------------------------------
;;; PDFTOOL：统一入口主菜单
;;;-------------------------------------------------------------
(defun PdfLayout_HubSetLbdHeight (/ v)
  (setq v (getreal (strcat "\n默认标签字高(模型单位, 当前 "
                           (rtos *PdfLayout_LbdTextHeight* 2 3)
                           ") <" (rtos *PdfLayout_LbdTextHeight* 2 3) ">: ")))
  (if v (setq *PdfLayout_LbdTextHeight* v))
  (PdfLayout_SaveSettings)
  (princ (strcat "\n默认字高=" (rtos *PdfLayout_LbdTextHeight* 2 3)))
  (princ)
)


(defun PdfLayout_HubShow (/ dclPath dclId result nd)
  (setq dclPath (PdfLayout_FindDcl))
  (if (not dclPath)
    nil
    (progn
      (setq dclId (load_dialog dclPath))
      (if (< dclId 0)
        nil
        (progn
          (setq nd (vl-catch-all-apply 'new_dialog (list "PdfHub" dclId)))
          (if (and nd (not (vl-catch-all-error-p nd)))
            (progn
              (setq *PdfLayout_HubAction* "NONE")
              (set_tile "hub_info" "提示: 命令行仍可直接输入原命令 (PDFLBD / PDFGRID / PDFLAYOUT / PDFRENAME / PDFQUICKCOPY / PDFBRUSH)")
              (action_tile "hub_lbd" "(setq *PdfLayout_HubAction* \"LBD\") (done_dialog 1)")
                            (action_tile "hub_grid" "(setq *PdfLayout_HubAction* \"GRID\") (done_dialog 1)")
              (action_tile "hub_layout" "(setq *PdfLayout_HubAction* \"LAYOUT\") (done_dialog 1)")
              (action_tile "hub_rename" "(setq *PdfLayout_HubAction* \"RENAME\") (done_dialog 1)")
              (action_tile "hub_lbdh" "(setq *PdfLayout_HubAction* \"LBDH\") (done_dialog 1)")
              (action_tile "hub_quickcopy" "(setq *PdfLayout_HubAction* \"QUICKCOPY\") (done_dialog 1)")
              (action_tile "hub_brush" "(setq *PdfLayout_HubAction* \"BRUSH\") (done_dialog 1)")
              (setq result (start_dialog))
              (unload_dialog dclId)
              (cond
                ((= *PdfLayout_HubAction* "LBD") (c:pdflbd))
                ((= *PdfLayout_HubAction* "GRID") (c:pdfgrid))
                ((= *PdfLayout_HubAction* "LAYOUT") (c:pdflayout))
                ((= *PdfLayout_HubAction* "RENAME") (c:pdfrename))
                ((= *PdfLayout_HubAction* "QUICKCOPY") (c:pdfquickcopy))
                ((= *PdfLayout_HubAction* "BRUSH") (c:pdfbrush))
                ((= *PdfLayout_HubAction* "LBDH") (PdfLayout_HubSetLbdHeight))
              )
            )
            nil
          )
        )
      )
    )
  )
  (princ)
)

(defun c:pdftool ()
  (vl-load-com)
  (PdfLayout_HubShow)
  (princ)
)


;;;@CUIX-BEGIN
;;;-------------------------------------------------------------
;;; PDF 工具栏：自动加载 CUIX 并显示工具栏（ZWCAD 中 COM 界面对象不可用，
;;; 改用标准 CUIX + CUILOAD，加载后自动调出 PDFTOOLS 工具栏）
;;;-------------------------------------------------------------
(defun PdfLayout_FileExistsEx (f / s)
  ;; 防止 findfile 受支持路径/受信路径影响而漏检：用 vl-file-size 直接探测真实磁盘。
  (and f (/= f "")
       (not (vl-catch-all-error-p (setq s (vl-catch-all-apply 'vl-file-size (list f)))))
       s)
)

(defun PdfLayout_FindCuix (/ roots r dir up cand found)
  ;; 1) 显式写死的绝对路径
  (if (and *PdfLayout_CuixPath*
           (/= *PdfLayout_CuixPath* "")
           (PdfLayout_FileExistsEx *PdfLayout_CuixPath*))
    *PdfLayout_CuixPath*
    ;; 2) 从 LSP 目录 / 当前图纸目录，逐级向上最多 4 层找 PdfLayout.cuix
    (progn
      (setq roots nil)
      (if (and *PdfLayout_LspDir* (/= *PdfLayout_LspDir* ""))
          (setq roots (cons *PdfLayout_LspDir* roots)))
      (if (and (getvar "DWGPREFIX") (/= (getvar "DWGPREFIX") "")
               (not (member (getvar "DWGPREFIX") roots)))
          (setq roots (cons (getvar "DWGPREFIX") roots)))
      (setq roots (reverse roots))
      (setq found nil)
      (foreach r roots
        (setq dir r up 0)
        (while (and dir (< up 4) (not found))
          (setq cand (strcat dir "PdfLayout.cuix"))
          (if (PdfLayout_FileExistsEx cand)
            (setq found cand)
            (progn
              (setq up (1+ up))
              (setq dir (vl-filename-directory (vl-string-right-trim "\\" dir)))))
        )
      )
      (if found found (findfile "PdfLayout.cuix"))
    )
  )
)


(defun PdfLayout_LoadToolbar (/ cuix)
  (vl-load-com)
  ;; cuix 已在 Workspace 挂载 Display=1，加载后即自动显示；
  ;; 不再 _menuload（ZWCAD 的 _menuload 是交互命令，会卡在"输入文件名"），
  ;; 只提示并引导用户手动加载
  (setq cuix (PdfLayout_FindCuix))
  (if cuix
    (princ (strcat "\nPDFLTOOL: 工具栏 [PDFTOOLS] 已随 cuix 加载并显示。"
                   "\n若未显示，请在命令行输入 MENULOAD 加载: " cuix))
    (princ (strcat "\nPDFLTOOL: 未找到 PdfLayout.cuix，请检查 *PdfLayout_CuixPath* 路径。"))
  )
  (princ)
)

(defun c:pdfloadtoolbar ()
  (PdfLayout_LoadToolbar)
  (princ)
)
;;;@CUIX-END

;;;-------------------------------------------------------------
;;; 在线更新
;;; 更新源 *PdfLayout_UpdateUrl* 支持四种写法：
;;;   "github:owner/repo@branch"   GitHub 仓库（推荐；自动多镜像回退）
;;;   "https://.../version.json"   任意 HTTP(S) 网址
;;;   "onedrive"                   在 OneDrive/Teams 同步目录里找 version.json
;;;   "D:\\path\\version.json"     本地磁盘 / UNC 共享路径
;;; 清单 version.json 由发布方 make_release.ps1 / publish_github.ps1 生成。
;;; 命令：PDFUPDATE 检查更新；PDFUPDATEDL 下载更新包；PDFUPDATEINST 下载并安装。
;;; 检测始终静默容错；下载与安装只有手动敲命令并回车确认后才会执行。
;;;-------------------------------------------------------------
(setq *PdfLayout_Version* "2.22")
(setq *PdfLayout_UpdateUrl* "github:cszmw2k6dk-design/MAP-CAD@main")
(setq *PdfLayout_CheckOnLoad* T)
(setq *PdfLayout_CheckedSession* nil)

;;; GitHub 镜像前缀：raw 直连不通时按顺序尝试（失效可自行增删）
(setq *PdfLayout_GhMirrors*
  (list "https://ghproxy.net/"
        "https://gh-proxy.com/"))

;;; 自动检查（安静模式）时最多尝试几个地址；nil = 全部尝试
(setq *PdfLayout_GhAttempts* nil)

;;; 更新包下载目录（留空 = 当前用户的 Downloads 目录）
(setq *PdfLayout_DownloadDir* "")

;;; 最近一次检查到的远端信息（供 PDFUPDATEDL / PDFUPDATEINST 复用）
(setq *PdfLayout_RemoteVer* nil)
(setq *PdfLayout_RemoteUrl* nil)
(setq *PdfLayout_RemoteMd5* nil)
(setq *PdfLayout_RemoteNote* nil)
(setq *PdfLayout_RemoteForce* nil)

;;; 版本号字符串 -> 数字列表，如 "2.18" -> (2 18)
(defun PdfLayout_SplitNum (s / ss res pos)
  (setq ss (vl-string-trim " " s) res nil pos (vl-string-search "." ss))
  (while pos
    (setq res (append res (list (atoi (substr ss 1 pos)))))
    (setq ss (substr ss (+ pos 2)))
    (setq pos (vl-string-search "." ss)))
  (append res (list (atoi ss))))

;;; 比较版本号：返回 1(a大) 0(相等) -1(b大)
(defun PdfLayout_CmpVer (a b / la lb i na nb r)
  (setq la (PdfLayout_SplitNum a) lb (PdfLayout_SplitNum b))
  (setq i 0 r 0)
  (while (and (= r 0) (< i (max (length la) (length lb))))
    (setq na (if (nth i la) (nth i la) 0))
    (setq nb (if (nth i lb) (nth i lb) 0))
    (cond ((< na nb) (setq r -1))
          ((> na nb) (setq r 1))
          (t (setq i (1+ i)))))
  r)

;;; 从 JSON 文本取 "key":"value" 的 value（适合纯 ASCII 值）
(defun PdfLayout_JsonVal (text key / pat p1 p2)
  (setq pat (strcat "\"" key "\":\""))
  (setq p1 (vl-string-search pat text))
  (if p1
    (progn
      (setq p1 (+ p1 (strlen pat)))
      (setq p2 (vl-string-search "\"" text p1))
      (if p2 (substr text (1+ p1) (- p2 p1)) nil))
    nil))

;;; 文件存在且非空（不依赖 findfile 搜索路径）
(defun PdfLayout_FileOK (f / s)
  (and f (/= f "")
       (not (vl-catch-all-error-p (setq s (vl-catch-all-apply 'vl-file-size (list f)))))
       (> s 0)))

;;; 目录存在判定
(defun PdfLayout_DirOK (d / l)
  (and d (/= d "")
       (not (vl-catch-all-error-p
              (setq l (vl-catch-all-apply 'vl-directory-files (list d nil -1)))))
       (listp l)))

;;; 临时目录（以反斜杠结尾）
(defun PdfLayout_TempDir (/ d)
  (setq d (vl-catch-all-apply 'getvar (list "TEMPPREFIX")))
  (if (or (vl-catch-all-error-p d) (null d) (= d ""))
    (setq d (strcat (getenv "TEMP") "\\")))
  d)

;;; 毫秒级等待（COM 不可用时退化为空转）
(defun PdfLayout_Sleep (ms / wsh n)
  (setq wsh (vl-catch-all-apply 'vlax-create-object (list "WScript.Shell")))
  (if (vl-catch-all-error-p wsh)
    (progn (setq n 0) (while (< n (* ms 50)) (setq n (1+ n))))
    (progn
      (vl-catch-all-apply 'vlax-invoke-method (list wsh 'Sleep ms))
      (vl-catch-all-apply 'vlax-release-object (list wsh))))
  T)

;;; 执行系统命令：隐藏窗口；wait=T 时同步等待并返回退出码，失败返回 nil
(defun PdfLayout_ShRun (cmd wait / wsh rc)
  (vl-load-com)
  (setq wsh (vl-catch-all-apply 'vlax-create-object (list "WScript.Shell")))
  (if (vl-catch-all-error-p wsh) (setq wsh nil))
  (setq rc nil)
  (if wsh
    (progn
      (setq rc (vl-catch-all-apply 'vlax-invoke-method (list wsh 'Run cmd 0 wait)))
      (if (vl-catch-all-error-p rc) (setq rc nil))
      (vl-catch-all-apply 'vlax-release-object (list wsh))))
  rc)

;;; 从右侧查找子串，返回 0 基下标（找不到返回 nil）
(defun PdfLayout_LastPos (pat s / i p out)
  (setq out nil p 0 i (vl-string-search pat s))
  (while i
    (setq out i)
    (setq p (1+ i))
    (setq i (vl-string-search pat s p)))
  out)

;;; 用 MSXML 请求文本（带超时），断网/异常都返回 nil，绝不抛出
(defun PdfLayout_HttpGetText (url / http res status)
  (vl-load-com)
  (setq http (vl-catch-all-apply 'vlax-create-object (list "MSXML2.XMLHTTP")))
  (if (vl-catch-all-error-p http) (setq http nil))
  (setq res nil)
  (if http
    (progn
      (vl-catch-all-apply
        '(lambda ()
           (vlax-invoke-method http 'setTimeouts 3000 3000 6000 12000)
           (vlax-invoke-method http 'open "GET" url :vlax-false)
           (vl-catch-all-apply 'vlax-invoke-method
             (list http 'setRequestHeader "User-Agent" "MAP-PdfLayout"))
           (vlax-invoke-method http 'send)
           (setq status (vlax-get-property http 'status))
           (if (= status 200)
             (setq res (vlax-get-property http 'responseText))))
        nil)
      (vl-catch-all-apply 'vlax-release-object (list http))))
  res)

;;; 读取本地/UNC 文件内容（用于共享盘更新源），失败返回 nil
(defun PdfLayout_ReadFile (path / p f line out)
  (setq p (vl-string-translate "\\" "/" path))
  (setq f nil out nil)
  (if (setq f (open p "r"))
    (progn
      (setq out "")
      (while (setq line (read-line f))
        (setq out (strcat out line "\n")))
      (close f)))
  out)

;;; ============ GitHub 更新源 ============

;;; 解析 "github:owner/repo[@branch][:path]" -> (owner repo branch path)，非法返回 nil
(defun PdfLayout_GhParse (s / pa pb rest owner repo branch path slash)
  (setq s (vl-string-trim " " s))
  (if (>= (strlen s) 7) (setq s (substr s 8)))     ; 去掉 "github:"
  (setq branch "main" path "version.json")
  (setq pa (vl-string-search "@" s))
  (if pa
    (progn
      (setq rest (substr s (+ pa 2)))
      (setq pb (vl-string-search ":" rest))
      (if pb
        (progn (setq branch (substr rest 1 pb))
               (setq path (substr rest (+ pb 2))))
        (setq branch rest))
      (setq s (substr s 1 (1- pa)))))
  (setq pb (vl-string-search ":" s))
  (if pb
    (progn (setq path (substr s (+ pb 2)))
           (setq s (substr s 1 (1- pb)))))
  (setq slash (vl-string-search "/" s))
  (if (and slash (> slash 0) (< slash (strlen s))
           (not (vl-string-search "/" (substr s (+ slash 2)))))
    (progn
      (setq owner (substr s 1 slash))
      (setq repo (substr s (+ slash 2)))
      (if (and (> (strlen owner) 0) (> (strlen repo) 0)
               (> (strlen branch) 0) (> (strlen path) 0))
        (list owner repo branch path)
        nil))
    nil))

;;; GitHub 文件的候选地址：raw 直连 -> jsDelivr CDN -> 各镜像代理
(defun PdfLayout_GhUrls (spec ts / p owner repo branch path raw cdn lst m)
  (setq p (PdfLayout_GhParse spec))
  (if (null p) nil
    (progn
      (setq owner (car p) repo (cadr p) branch (caddr p) path (cadddr p))
      (setq raw (strcat "https://raw.githubusercontent.com/"
                        owner "/" repo "/" branch "/" path))
      (setq cdn (strcat "https://cdn.jsdelivr.net/gh/"
                        owner "/" repo "@" branch "/" path))
      (setq lst (list (strcat raw "?t=" ts)))
      (setq lst (append lst (list (strcat cdn "?t=" ts))))
      (foreach m *PdfLayout_GhMirrors*
        (if m (setq lst (append lst (list (strcat m raw "?t=" ts))))))
      lst)))

;;; 更新包候选地址：release_url 直连 + GitHub 镜像代理前缀
(defun PdfLayout_AssetUrls (url / lst m lower)
  (setq lst nil)
  (if (and url (/= url ""))
    (progn
      (setq lst (list url))
      (setq lower (strcase url))
      (if (= (substr lower 1 19) "HTTPS://GITHUB.COM/")
        (foreach m *PdfLayout_GhMirrors*
          (if m (setq lst (append lst (list (strcat m url)))))))))
  lst)

;;; 收集 OneDrive/Teams 同步根目录
(defun PdfLayout_OnedriveRoots (/ roots v)
  (setq roots nil)
  (foreach v (list "OneDrive" "OneDriveCommercial" "OneDriveConsumer")
    (setq v (getenv v))
    (if (and v (/= v "") (not (member v roots)))
      (setq roots (append roots (list v)))))
  roots)

;;; 在 dir 及其子目录(最多 depth 层)中找 version.json，受全局预算限制
(defun PdfLayout_FindJsonIn (dir depth / sub found d)
  (if (or (<= depth 0) (<= *PdfLayout_ScanRemaining* 0) (null dir)) nil
    (progn
      (setq *PdfLayout_ScanRemaining* (1- *PdfLayout_ScanRemaining*))
      (setq found (findfile (strcat dir "\\version.json")))
      (if found found
        (progn
          (setq sub (vl-catch-all-apply 'vl-directory-files (list dir nil 1)))
          (if (listp sub)
            (foreach d sub
              (if (and (not found) (/= d ".") (/= d "..") (> *PdfLayout_ScanRemaining* 0))
                (setq found (PdfLayout_FindJsonIn (strcat dir "\\" d) (1- depth))))))
          found)))))

;;; 在 OneDrive 同步目录里寻找 version.json
(defun PdfLayout_FindOneDriveVersionJson (/ roots d found)
  (setq *PdfLayout_ScanRemaining* 600)
  (setq roots (PdfLayout_OnedriveRoots))
  (setq found nil)
  (foreach d roots
    (if (and (not found) (> *PdfLayout_ScanRemaining* 0))
      (setq found (PdfLayout_FindJsonIn d 4))))
  found)

;;; 按更新源读取 version.json 文本：github / http(s) / onedrive / 本地文件
(defun PdfLayout_GetSource (src / lower ts u txt n)
  (setq txt nil)
  (setq n 0)
  (if (and src (/= src ""))
    (progn
      (setq lower (strcase (vl-string-trim " " src)))
      (setq ts (rtos (getvar "DATE") 2 8))
      (cond
        ((= lower "ONEDRIVE")
         (setq txt (PdfLayout_ReadFile (PdfLayout_FindOneDriveVersionJson))))
        ((= (substr lower 1 7) "GITHUB:")
         (foreach u (PdfLayout_GhUrls src ts)
           (if (and u (not txt)
                    (or (null *PdfLayout_GhAttempts*) (< n *PdfLayout_GhAttempts*)))
             (progn
               (setq n (1+ n))
               (setq txt (PdfLayout_HttpGetText u))))))
        ((or (= (substr lower 1 7) "HTTP://")
             (= (substr lower 1 8) "HTTPS://"))
         (setq txt (PdfLayout_HttpGetText src)))
        (t (setq txt (PdfLayout_ReadFile src))))))
  txt)

;;; ============ 检查更新 ============

(defun PdfLayout_UpdateCheck (quiet / txt ver url notes md5 minv cur r force u i)
  (setq cur *PdfLayout_Version*)
  ;; 自动检查（安静模式）只试前两个地址，避免拖慢 CAD 启动
  (setq *PdfLayout_GhAttempts* (if quiet 2 nil))
  (if (or (null *PdfLayout_UpdateUrl*) (= *PdfLayout_UpdateUrl* "")
          (null cur) (= cur ""))
    (if (not quiet) (princ "\nPDFUPDATE: 未设置更新源地址(*PdfLayout_UpdateUrl*)。"))
    (progn
      (setq txt (PdfLayout_GetSource *PdfLayout_UpdateUrl*))
      (if txt
        (progn
          (setq ver (PdfLayout_JsonVal txt "version"))
          (setq url (PdfLayout_JsonVal txt "release_url"))
          (setq notes (PdfLayout_JsonVal txt "releasenote"))
          (setq md5 (PdfLayout_JsonVal txt "md5"))
          (setq minv (PdfLayout_JsonVal txt "min_version"))
          (setq r (if ver (PdfLayout_CmpVer ver cur) 0))
          (setq force (and minv (/= minv "")
                           (< (PdfLayout_CmpVer cur minv) 0)))
          (setq *PdfLayout_RemoteVer* ver
                *PdfLayout_RemoteUrl* url
                *PdfLayout_RemoteMd5* md5
                *PdfLayout_RemoteNote* notes
                *PdfLayout_RemoteForce* force)
          (if (and ver (> r 0))
            (progn
              (princ (strcat "\nPDFUPDATE: 发现新版本 v" ver "（当前 v" cur "）"
                             (if force "  [必需更新]" "")))
              (if notes (princ (strcat "\n  更新说明: " notes)))
              (if (and url (/= url ""))
                (progn
                  (princ (strcat "\n  更新包: " url))
                  (setq i 0)
                  (foreach u (cdr (PdfLayout_AssetUrls url))
                    (setq i (1+ i))
                    (if (<= i 2) (princ (strcat "\n  镜像" (itoa i) ": " u))))))
              (princ "\n  下载更新包: PDFUPDATEDL    自动安装: PDFUPDATEINST"))
            (if (not quiet) (princ (strcat "\nPDFUPDATE: 当前版本 v" cur " 已是最新。")))))
        (if (not quiet) (princ "\nPDFUPDATE: 检查更新失败，请检查网络或更新源地址。")))))
  (princ))

(defun c:pdfupdate () (PdfLayout_UpdateCheck nil) (princ))

;;; ============ 下载与安装 ============

;;; 更新包下载目录（以反斜杠结尾）
(defun PdfLayout_DownloadDirGet (/ d)
  (setq d *PdfLayout_DownloadDir*)
  (if (or (null d) (= d ""))
    (setq d (strcat (getenv "USERPROFILE") "\\Downloads")))
  (strcat (vl-string-right-trim "\\" d) "\\"))

;;; 从 URL 末段猜下载文件名，猜不出就用默认名
(defun PdfLayout_UrlFileName (url ver / s q i)
  (setq s (if url url ""))
  (setq q (vl-string-search "?" s))
  (if q (setq s (substr s 1 q)))
  (setq i (PdfLayout_LastPos "/" s))
  (if i (setq s (substr s (+ i 2))))
  (if (or (null s) (= s "") (vl-string-search ";" s))
    (setq s (strcat "MAP工具箱_v" ver ".zip")))
  (if (/= (strcase (substr s (max 1 (- (strlen s) 3)))) ".ZIP")
    (setq s (strcat s ".zip")))
  s)

;;; 下载二进制文件（MSXML + ADODB.Stream），成功返回 T
(defun PdfLayout_HttpDownload (url path / http st status)
  (vl-load-com)
  (vl-catch-all-apply 'vl-file-delete (list path))
  (setq http (vl-catch-all-apply 'vlax-create-object (list "MSXML2.XMLHTTP")))
  (if (vl-catch-all-error-p http) (setq http nil))
  (if http
    (progn
      (vl-catch-all-apply
        '(lambda ()
           (vlax-invoke-method http 'setTimeouts 6000 6000 20000 600000)
           (vlax-invoke-method http 'open "GET" url :vlax-false)
           (vl-catch-all-apply 'vlax-invoke-method
             (list http 'setRequestHeader "User-Agent" "MAP-PdfLayout"))
           (vlax-invoke-method http 'send)
           (setq status (vlax-get-property http 'status))
           (if (= status 200)
             (progn
               (setq st (vlax-create-object "ADODB.Stream"))
               (vlax-put-property st 'Type 1)
               (vlax-invoke-method st 'Open)
               (vlax-invoke-method st 'Write (vlax-get-property http 'responseBody))
               (vlax-invoke-method st 'SaveToFile path 2)
               (vlax-invoke-method st 'Close)
               (vl-catch-all-apply 'vlax-release-object (list st)))))
        nil)
      (vl-catch-all-apply 'vlax-release-object (list http)))
    (princ "\n  无法创建下载组件(MSXML2.XMLHTTP)。"))
  (PdfLayout_FileOK path))

;;; 依次尝试多个 URL 下载到 path
(defun PdfLayout_DownloadAny (urls path / done u)
  (setq done nil)
  (foreach u urls
    (if (and u (not done))
      (progn
        (princ (strcat "\n  尝试: " u))
        (if (PdfLayout_HttpDownload u path) (setq done T)))))
  done)

;;; 计算文件 MD5（小写 32 位），失败返回 nil
(defun PdfLayout_Md5File (path / out cmd n s)
  (setq out (strcat (PdfLayout_TempDir) "pdfl_md5.txt"))
  (vl-catch-all-apply 'vl-file-delete (list out))
  (setq cmd (strcat "powershell -NoProfile -ExecutionPolicy Bypass -Command \""
                    "(Get-FileHash -LiteralPath '" path "' -Algorithm MD5).Hash"
                    " | Out-File -Encoding ascii -LiteralPath '" out "'\""))
  (PdfLayout_ShRun cmd T)
  (setq n 0)
  (while (and (< n 60) (not (PdfLayout_FileOK out)))
    (PdfLayout_Sleep 200)
    (setq n (1+ n)))
  (setq s (PdfLayout_ReadFile out))
  (vl-catch-all-apply 'vl-file-delete (list out))
  (if s
    (progn
      (setq s (vl-string-trim " \t\r\n" s))
      (if (= (strlen s) 32) (strcase s) nil))
    nil))

;;; 解压 zip 到 dest（PowerShell 优先，失败退回 Shell.Application）
(defun PdfLayout_Unzip (zip dest / cmd ok sh src dst)
  (setq ok nil)
  (if (PdfLayout_FileOK zip)
    (progn
      (setq cmd (strcat "powershell -NoProfile -ExecutionPolicy Bypass -Command \""
                        "Expand-Archive -LiteralPath '" zip "' -DestinationPath '"
                        dest "' -Force\""))
      (PdfLayout_ShRun cmd T)
      (setq ok (PdfLayout_DirOK dest))
      (if (not ok)
        (progn
          (vl-load-com)
          (setq sh (vl-catch-all-apply 'vlax-create-object (list "Shell.Application")))
          (if (not (vl-catch-all-error-p sh))
            (progn
              (vl-catch-all-apply
                '(lambda ()
                   (setq src (vlax-invoke-method sh 'NameSpace zip))
                   (setq dst (vlax-invoke-method sh 'NameSpace dest))
                   (vlax-invoke-method dst 'CopyHere (vlax-get-property src 'Items) 20)
                   (vl-catch-all-apply 'vlax-release-object (list dst))
                   (vl-catch-all-apply 'vlax-release-object (list src))
                   (vl-catch-all-apply 'vlax-release-object (list sh)))
                nil)
              (PdfLayout_Sleep 2000)
              (setq ok (PdfLayout_DirOK dest))))))))
  ok)

;;; 在目录树里找指定名字的文件（最多 depth 层）
(defun PdfLayout_FindInTree (dir name depth / f subs d found)
  (if (or (null dir) (<= depth 0)) nil
    (progn
      (setq f (findfile (strcat dir "\\" name)))
      (if f f
        (progn
          (setq subs (vl-catch-all-apply 'vl-directory-files (list dir nil -1)))
          (if (listp subs)
            (foreach d subs
              (if (and (not found) (/= d ".") (/= d ".."))
                (setq found (PdfLayout_FindInTree (strcat dir "\\" d) name (1- depth))))))
          found)))))

;;; 递归复制目录
(defun PdfLayout_CopyTree (src dst / files subs f d)
  (vl-catch-all-apply 'vl-mkdir (list dst))
  (setq files (vl-catch-all-apply 'vl-directory-files (list src nil 1)))
  (if (listp files)
    (foreach f files
      (if (PdfLayout_FileOK (strcat src "\\" f))
        (vl-catch-all-apply 'vl-file-copy
          (list (strcat src "\\" f) (strcat dst "\\" f) nil)))))
  (setq subs (vl-catch-all-apply 'vl-directory-files (list src nil -1)))
  (if (listp subs)
    (foreach d subs
      (if (and (/= d ".") (/= d ".."))
        (PdfLayout_CopyTree (strcat src "\\" d) (strcat dst "\\" d)))))
  T)

;;; 当前插件安装目录（PdfLayout.lsp 所在目录，以反斜杠结尾）；取不到返回 nil
(defun PdfLayout_InstallDir (/ d f)
  (setq d (if (and *PdfLayout_LspDir* (/= *PdfLayout_LspDir* "")) *PdfLayout_LspDir* nil))
  (if (or (null d) (not (PdfLayout_FileOK (strcat d "\\PdfLayout.lsp"))))
    (progn
      (setq f (findfile "PdfLayout.lsp"))
      (if (and f (PdfLayout_FileOK f)) (setq d (vl-filename-directory f)))))
  (if (and d (/= d "")) (strcat (vl-string-right-trim "\\" d) "\\") nil))

;;; 备份 dst 目录下与 src 同名的文件到 dst\_update_backup\v<cur>_<时间>，返回备份目录
(defun PdfLayout_BackupFiles (src dst cur / stamp bak files f)
  (setq stamp (vl-string-translate "." "_" (rtos (getvar "CDATE") 2 6)))
  (setq bak (strcat dst "_update_backup\\v" cur "_" stamp "\\"))
  (vl-catch-all-apply 'vl-mkdir (list (strcat dst "_update_backup")))
  (vl-catch-all-apply 'vl-mkdir (list bak))
  (setq files (vl-catch-all-apply 'vl-directory-files (list src nil 1)))
  (if (listp files)
    (foreach f files
      (if (PdfLayout_FileOK (strcat dst f))
        (vl-catch-all-apply 'vl-file-copy (list (strcat dst f) (strcat bak f) nil)))))
  bak)

;;; 下载 + 校验 + 解压 + 备份 + 覆盖；成功返回 T
(defun PdfLayout_ApplyUpdate (ver url md5 / tmp zip ext srcFile srcDir dst upx ok)
  (setq ok nil)
  (setq dst (PdfLayout_InstallDir))
  (if (null dst)
    (princ "\nPDFUPDATE: 找不到当前 PdfLayout.lsp 所在目录，无法自动安装；请手动解压覆盖。")
    (progn
      (setq tmp (strcat (PdfLayout_TempDir) "pdfl_upd_" ver "\\"))
      (setq zip (strcat tmp "package.zip"))
      (setq ext (strcat tmp "extract"))
      (vl-catch-all-apply 'vl-mkdir (list tmp))
      (princ (strcat "\nPDFUPDATE: 开始下载 v" ver " ..."))
      (if (PdfLayout_DownloadAny (PdfLayout_AssetUrls url) zip)
        (progn
          (princ (strcat "\n  已下载: " zip))
          (if (and md5 (/= md5 ""))
            (progn
              (setq upx (PdfLayout_Md5File zip))
              (cond
                ((null upx)
                 (princ "\n  警告: 无法计算 MD5，跳过校验。")
                 (setq ok T))
                ((/= (strcase upx) (strcase md5))
                 (princ (strcat "\n  校验失败: MD5 不一致，已停止安装。"
                                "\n    期望 " md5 "\n    实际 " upx)))
                (t
                 (princ "\n  MD5 校验通过。")
                 (setq ok T))))
            (setq ok T))
          (if ok
            (progn
              (princ "\n  正在解压...")
              (setq ok (PdfLayout_Unzip zip ext))
              (if (not ok)
                (princ "\n  解压失败，已停止安装。")
                (progn
                  (setq srcFile (PdfLayout_FindInTree ext "PdfLayout.lsp" 4))
                  (if (null srcFile)
                    (progn
                      (setq ok nil)
                      (princ "\n  更新包里没找到 PdfLayout.lsp，已停止安装。"))
                    (progn
                      (setq srcDir (strcat (vl-filename-directory srcFile) "\\"))
                      (princ (strcat "\n  已备份旧文件: "
                                     (PdfLayout_BackupFiles srcDir dst *PdfLayout_Version*)))
                      (PdfLayout_CopyTree srcDir dst)
                      (setq upx (PdfLayout_FindInTree ext "PackageContents.xml" 3))
                      (if (and upx (PdfLayout_FileOK (strcat dst "..\\PackageContents.xml")))
                        (progn
                          (vl-catch-all-apply 'vl-file-copy
                            (list upx (strcat dst "..\\PackageContents.xml") nil))
                          (princ "\n  PackageContents.xml 已更新。")))
                      (princ (strcat "\n  v" ver " 已覆盖安装到: " dst))))))))
        (princ "\nPDFUPDATE: 下载失败（网络不通或地址失效），可挂代理后重试。")))))
  (if ok (vl-catch-all-apply 'vl-file-delete (list zip)))
  ok)

;;; 下载更新包到本地（不安装），返回下载到的文件路径
(defun PdfLayout_DownloadOnly (ver url md5 / dir file path upx)
  (setq dir (PdfLayout_DownloadDirGet))
  (setq file (PdfLayout_UrlFileName url ver))
  (setq path (strcat dir file))
  (vl-catch-all-apply 'vl-mkdir (list dir))
  (princ (strcat "\nPDFUPDATE: 下载 v" ver " 到 " path))
  (if (PdfLayout_DownloadAny (PdfLayout_AssetUrls url) path)
    (progn
      (princ (strcat "\n  已保存: " path))
      (if (and md5 (/= md5 ""))
        (progn
          (setq upx (PdfLayout_Md5File path))
          (cond
            ((null upx)
             (princ "\n  警告: 无法计算 MD5，跳过校验。"))
            ((/= (strcase upx) (strcase md5))
             (princ (strcat "\n  校验失败: MD5 不一致，文件可能损坏。"
                            "\n    期望 " md5 "\n    实际 " upx)))
            (t
             (princ "\n  MD5 校验通过。")))))
      (princ "\n  手动安装：解压后覆盖插件目录；自动安装：输入 PDFUPDATEINST。")
      (vl-catch-all-apply 'PdfLayout_ShRun (list (strcat "explorer \"" dir "\"") nil))
      path)
    (progn
      (princ "\nPDFUPDATE: 下载失败，请检查网络后重试。")
      nil)))

;;; 取最近一次检查到的新版本信息；没有就现查一次
(defun PdfLayout_RemoteReady ()
  (if (null *PdfLayout_RemoteVer*)
    (PdfLayout_UpdateCheck T))
  (if (and *PdfLayout_RemoteVer*
           (> (PdfLayout_CmpVer *PdfLayout_RemoteVer* *PdfLayout_Version*) 0))
    T
    (progn
      (princ (strcat "\nPDFUPDATE: 当前没有可用的新版本信息（当前 v"
                     *PdfLayout_Version* "）。"))
      nil)))

(defun c:pdfupdatedl ()
  (if (PdfLayout_RemoteReady)
    (PdfLayout_DownloadOnly *PdfLayout_RemoteVer* *PdfLayout_RemoteUrl*
                            *PdfLayout_RemoteMd5*))
  (princ))

(defun c:pdfupdateinst (/ ans)
  (if (PdfLayout_RemoteReady)
    (progn
      (if (and *PdfLayout_RemoteNote* (/= *PdfLayout_RemoteNote* ""))
        (princ (strcat "\n  更新说明: " *PdfLayout_RemoteNote*)))
      (initget "Y N")
      (setq ans (getkword (strcat "\n确认把 v" *PdfLayout_RemoteVer*
                                  " 覆盖安装到当前插件目录？[是(Y)/否(N)] <N>: ")))
      (if (= ans "Y")
        (progn
          (if (PdfLayout_ApplyUpdate *PdfLayout_RemoteVer* *PdfLayout_RemoteUrl*
                                     *PdfLayout_RemoteMd5*)
            (progn
              (setq *PdfLayout_Version* *PdfLayout_RemoteVer*)
              (vl-catch-all-apply 'load
                (list (strcat (PdfLayout_InstallDir) "PdfLayout.lsp")))
              (princ (strcat "\nPDFUPDATE: 已更新到 v" *PdfLayout_RemoteVer*
                             "，建议重启 CAD 以确保工具栏与命令完全生效。")))
            (princ "\nPDFUPDATE: 安装未完成，原文件未被破坏。")))
        (princ "\nPDFUPDATE: 已取消。"))))
  (princ))

;;; 加载完成后静默自动检查（一次会话只查一次）
(defun PdfLayout_UpdateAutoCheck ()
  (if (and *PdfLayout_CheckOnLoad* (not *PdfLayout_CheckedSession*))
    (progn
      (setq *PdfLayout_CheckedSession* T)
      (vl-catch-all-apply '(lambda () (PdfLayout_UpdateCheck T)) nil)))
  (princ))

;;;@CUIX-BEGIN
(PdfLayout_LoadToolbar)
;;;@CUIX-END

;;; 加载完成后自动检查更新
(PdfLayout_UpdateAutoCheck)
