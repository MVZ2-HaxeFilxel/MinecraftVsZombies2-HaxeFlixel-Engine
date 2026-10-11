#!/usr/bin/env bash
# .mo 二进制语言包解析验证（不参与游戏构建，不产出构建文件、不碰 obj 目录）：
#   1. Python 参照实现独立解析三份内置 .mo，核对键编码约定（msgctxt\x04msgid）与语言名条目；
#   2. Haxe 冒烟测试以 --interp 解释执行（纯语法+运行期自查，无输出目录），走与
#      ZipArchiveHelper.ReadCatalog 相同的 MemoryStream -> new Catalog 构造路径。
#
#   bash HaxePort/tools_build/check_mo_catalog.sh
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT_DIR="$(cd "$HERE/.." && pwd)"

cd "$PORT_DIR" || exit 1

echo '== Python 参照实现（独立 MO 解析）=='
python verify/verify_mo_catalog.py || exit 1

echo
echo '== Haxe 冒烟测试（--interp，无构建产物）=='
haxe -cp source -cp verify --interp -main mocatalog.MoCatalogSmokeTest
