// PdfLayout.dcl
// MAP文件工具箱 v2.16 - 对话框定义

PdfLayout : dialog {
  label = "MAP文件工具箱 v2.16";
  width = 62;

  : boxed_column {
    label = "图纸识别（竖线标记模式）";
    : row {
      : popup_list {
        label = "竖线块名:";
        key = "marker_name";
        edit_width = 22;
      }
    }
    : button {
      label = "仅自动排序已导入的PDF(不建布局)";
      key = "btn_arrange";
      width = 32;
    }
    : text {
      key = "found_info";
      label = " ";
      width = 55;
    }
    : text {
      label = "提示: 先用 PDFATTACH 导入PDF，再运行本命令自动排列底图并创建布局；竖线标记块默认名pdf";
      width = 55;
    }
  }

  : boxed_column {
    label = "布局";
    : popup_list {
      label = "模板布局(含图框):";
      key = "tmpl_layout";
      edit_width = 26;
    }
    : row {
      : edit_box { label = "布局名来自Excel分表:"; key = "names_xlsx"; edit_width = 16; }
      : button { label = "选择..."; key = "btn_names_xlsx"; width = 10; }
    }
    : text { label = "填Excel后按分表顺序命名布局(数量=分表数)；留空用下方规则"; width = 55; }
    : row {
      : edit_box {
        label = "复制数量:";
        key = "count";
        edit_width = 6;
        value = "0";
        allow_accept = true;
      }
      : toggle {
        label = "覆盖同名布局";
        key = "overwrite";
        value = "0";
      }
    }
  }

  : boxed_column {
    label = "命名规则";
    : edit_box {
      label = "规则:";
      key = "rule";
      edit_width = 34;
      value = "INV{G2}{L}{N2}";
      allow_accept = true;
    }
    : row {
      : edit_box {
        label = "字母列表:";
        key = "letters";
        edit_width = 10;
        value = "AB";
        allow_accept = true;
      }
      : edit_box {
        label = "每组张数:";
        key = "per_group";
        edit_width = 5;
        value = "6";
        allow_accept = true;
      }
      : edit_box {
        label = "编号起始:";
        key = "g_start";
        edit_width = 5;
        value = "1";
        allow_accept = true;
      }
    }
    : text {
      label = "占位符: {G2}=编号(2位)  {L}=字母循环  {N2}=组内序号(2位)";
      width = 58;
    }
    : text {
      label = "例: INV{G2}{L}{N2} + 字母AB + 每组6张 -> INV01A01..A06, INV01B01..B06, INV02A01..";
      width = 58;
    }
    : list_box {
      label = "名称预览:";
      key = "preview";
      height = 9;
    }
  }

  : boxed_column {
    label = "视口";
    : edit_box {
      label = "模板无视口时按边距创建(mm):";
      key = "margin";
      edit_width = 6;
      value = "5";
      allow_accept = true;
    }
    : toggle {
      label = "锁定视口显示(防误缩放)";
      key = "lock_vp";
      value = "0";
    }
  }

  ok_cancel;
}

PdfRenamePreview : dialog {
  label = "多行文字命名方案";
  : boxed_column {
    label = "方案预设";
    : row {
      : popup_list { label = "方案:"; key = "prof_list"; edit_width = 18; }
    }
    : row {
      : edit_box { label = "方案名:"; key = "prof_name"; edit_width = 12; }
      : button { label = "保存为方案"; key = "btn_saveprof"; width = 14; }
      : button { label = "删除方案"; key = "btn_delprof"; width = 14; }
    }
  }
  : boxed_radio_column {
    label = "名称来源";
    : radio_button { label = "自动生成（前缀+编号）"; key = "srcauto"; value = "1"; }
    : radio_button { label = "从CSV文件导入"; key = "srcfile"; }
    : radio_button { label = "从CSV导入(LBD标签两列)"; key = "srcfile2"; }
  }
  : row {
    : edit_box { label = "文件:"; key = "file_path"; edit_width = 22; }
    : button { label = "选择..."; key = "btn_file"; width = 10; }
  }
  : row {
    : edit_box { label = "前缀:"; key = "prefix"; edit_width = 8; }
    : edit_box { label = "起始编号:"; key = "start"; edit_width = 5; }
    : edit_box { label = "位数(0=不补零):"; key = "digits"; edit_width = 4; }
  }
  : boxed_column {
    label = "文字背景";
    : radio_row {
      : radio_button { label = "保持现状"; key = "bgkeep"; value = "1"; }
      : radio_button { label = "开启填充"; key = "bgon"; }
      : radio_button { label = "关闭填充"; key = "bgoff"; }
    }
    : row {
      : edit_box { label = "颜色(ACI):"; key = "bg_color"; edit_width = 4; }
      : edit_box { label = "缩放系数:"; key = "bg_scale"; edit_width = 4; }
    }
  }
  : boxed_radio_column {
    label = "排序方式";
: radio_button { label = "1 列优先: 左→右列、列内上→下"; key = "ord1"; value = "1"; }
: radio_button { label = "2 行优先: 上→下行、行内左→右"; key = "ord2"; }
    : radio_button { label = "3 右->左/上->下"; key = "ord3"; }
    : radio_button { label = "4 下->上/左->右"; key = "ord4"; }
    : radio_button { label = "5 左->右/下->上"; key = "ord5"; }
    : radio_button { label = "6 右->左/下->上"; key = "ord6"; }
    : radio_button { label = "7 上->下/右->左"; key = "ord7"; }
    : radio_button { label = "8 下->上/右->左"; key = "ord8"; }
  }
  : row {
    : edit_box { label = "分行容差%(越大越并成一行):"; key = "row_tol"; edit_width = 5; value = "10"; }
  }
  : boxed_column {
    label = "方案预览（左=顺序 右=名称）";
    : row {
      : list_box { key = "scheme_grid"; height = 8; width = 26; }
      : list_box { key = "name_list"; height = 8; width = 22; }
    }
  }
  : text { key = "info_text"; label = " "; width = 60; }
  ok_cancel;
}
