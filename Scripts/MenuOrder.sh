#!/bin/bash

replace_luci_app_belong() {
    local appname="$1"         # 如 luci-app-socat
    local find_dir="$2"        # 如 package
    local search="$3"          # 被替换的内容
    local replace="$4"         # 替换为的内容
    shift 4
    local files=("$@")         # 相对路径列表

    for relative_path in "${files[@]}"; do
        local full_path

        # 自动查找目录前缀
        full_path=$(find "$find_dir" -type f -path "*/$appname/$relative_path" | head -n 1)

        if [[ -n "$full_path" && -f "$full_path" ]]; then
            echo "[Info] Found: $full_path"
            sed -i "s/$search/$replace/g" "$full_path"
            echo "[OK] Replaced '$search' -> '$replace' in $full_path"
        else
            echo "[Skip] File not found: */$appname/$relative_path"
        fi
    done
}

# OpenAppFilter更换到network
echo -e "\n OpenAppFilter menu!"
replace_luci_app_belong \
  "luci-app-oaf" \
  "package" \
  "services" \
  "network" \
  "luasrc/controller/appfilter.lua" \
  "luasrc/model/cbi/appfilter/dev_status.lua" \
  "luasrc/view/admin_network/app_filter.htm"

echo -e "\n socat menu!"
# socat 更换到 services
replace_luci_app_belong \
  "luci-app-socat" \
  "package" \
  "network" \
  "services" \
  "luasrc/controller/socat.lua" \
  "luasrc/model/cbi/socat/index.lua" \
  "luasrc/model/cbi/socat/config.lua" \
  "luasrc/view/socat/list_status.htm"