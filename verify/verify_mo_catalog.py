#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""一次性验证：游戏内置语言包的 en-US/*.mo 是二进制 MO（GNU gettext 编译格式），
且包含 HaxePort/source/ngettext/Catalog.hx 装进来的键值（msgctxt\\x04msgid 约定）。

背景：Catalog.hx 的 load() 原本只解析 .po 文本，对二进制 .mo 解析出 0 条翻译，
导致全游戏本地化查表失败（语言名下拉显示 zh-Hans(zh-hans)、切语言无效）。
本脚本按 MO 格式规范（magic 0x950412de + revision + N + origOffset + transOffset
+ hashSize + hashOffset，随后 N 个 (length, offset) 对构成原串表/翻译表）独立解析，
作为 Haxe 侧实现的参照实现与验收依据。

键编码约定（必须与 Catalog.hx / LanguagePack.TryGetString* 的查表一致）：
  * 原串表读出的 msgid 原样作为键：
      - 带上下文的条目，msgid 即 "msgctxt\\x04msgid"（二进制里就是这样存的）；
      - 复数条目的 msgid 即 "singular\\x00plural"。
  * 翻译表读出的 msgstr：单数条目直接存值；复数条目按 "\\x00" 拆成复数形式数组。

用法（在仓库根目录执行）：
    python HaxePort/verify/verify_mo_catalog.py
    python HaxePort/verify/verify_mo_catalog.py --data-dir HaxePort/assets/Localization/source
"""

from __future__ import annotations

import argparse
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))

MO_MAGIC_LE = 0x950412DE  # 文件头四字节为 DE 12 04 95
MO_MAGIC_BE = 0xDE120495  # 文件头四字节为 95 04 12 DE

# 期望出现的语言名条目（LanguageManager.GetLanguageName 的查表路径）
EXPECT_CONTEXT = "language_name"
EXPECT_MSGID = "中文"
EXPECT_MSGSTR = "English (United States)"


class MoFormatError(Exception):
    pass


def parse_mo(data: bytes):
    """解析二进制 .mo，返回 (entries, stats)。

    entries: list of (msgid_raw, msgstr_raw)，msgid_raw/msgstr_raw 均为按 \\x04/\\x00
    分隔约定拼接前的原始字符串（键即 msgid_raw 原样）。
    """
    if len(data) < 28:
        raise MoFormatError("文件过短，连 MO 头都放不下（%d 字节）" % len(data))

    magic = struct.unpack_from("<I", data, 0)[0]
    if magic == MO_MAGIC_LE:
        endian = "<"
    else:
        magic_be = struct.unpack_from(">I", data, 0)[0]
        if magic_be == MO_MAGIC_BE:
            endian = ">"
        else:
            raise MoFormatError(
                "magic 不匹配：读到 0x%08X（既不是小端 0x950412de 也不是大端 0xde120495）" % magic
            )

    def u32(off: int) -> int:
        return struct.unpack_from(endian + "I", data, off)[0]

    revision = u32(4)
    if revision != 0:
        raise MoFormatError("不支持的 MO revision %d" % revision)

    n = u32(8)
    orig_offset = u32(12)
    trans_offset = u32(16)
    hash_size = u32(20)
    hash_offset = u32(24)

    if n == 0:
        raise MoFormatError("MO 头声称 0 个条目")

    def table_entries(table_offset: int):
        for i in range(n):
            length = u32(table_offset + 8 * i)
            str_offset = u32(table_offset + 8 * i + 4)
            if str_offset + length > len(data):
                raise MoFormatError(
                    "第 %d 个串越界（offset=%d length=%d，文件仅 %d 字节）"
                    % (i, str_offset, length, len(data))
                )
            yield data[str_offset : str_offset + length].decode("utf-8")

    orig_strings = list(table_entries(orig_offset))
    trans_strings = list(table_entries(trans_offset))
    if len(orig_strings) != n or len(trans_strings) != n:
        raise MoFormatError("原串表/翻译表条目数与头部 N=%d 不一致" % n)

    entries = list(zip(orig_strings, trans_strings))

    stats = {
        "revision": revision,
        "endian": "little" if endian == "<" else "big",
        "hash_size": hash_size,
        "hash_offset": hash_offset,
        "total": n,
        "context": 0,
        "plural": 0,
        "header": 0,
        "untranslated": 0,
    }
    for msgid, msgstr in entries:
        if "\x00" in msgid:
            stats["plural"] += 1
        if "\x04" in msgid:
            stats["context"] += 1
        if msgid == "":
            stats["header"] += 1
        if msgstr == "":
            stats["untranslated"] += 1
    return entries, stats


def key_of(msgid_raw: str) -> str:
    """复现 HaxePort Catalog 的键编码：msgid 原样即键（\\x04 前缀即 msgctxt）。"""
    return msgid_raw


def verify_file(path: str, expect_language_name: bool) -> int:
    with open(path, "rb") as f:
        data = f.read()

    print("=" * 78)
    print("文件: %s（%d 字节）" % (os.path.relpath(path, ROOT), len(data)))
    entries, stats = parse_mo(data)

    print(
        "  字节序=%s revision=%d N=%d hash(size=%d, offset=%d)"
        % (stats["endian"], stats["revision"], stats["total"], stats["hash_size"], stats["hash_offset"])
    )
    print(
        "  条目: 共 %d（含头部 %d、上下文 %d、复数 %d、未翻译 %d）"
        % (stats["total"], stats["header"], stats["context"], stats["plural"], stats["untranslated"])
    )

    assert stats["total"] > 0, "解析出 0 条翻译 —— MO 解析失败"
    assert stats["endian"] == "little", "本仓库内置 .mo 是小端（DE 12 04 95）"

    table = {key_of(msgid): msgstr for msgid, msgstr in entries}
    assert len(table) == len(entries), "msgid 键出现重复：%d != %d" % (len(table), len(entries))

    # 打印前几条样例，便于人工核对键编码。
    shown = 0
    for msgid, msgstr in entries:
        if msgid == "" or msgstr == "":
            continue
        key = key_of(msgid)
        if "\x04" in key or "\x00" in key:
            pretty_key = key.replace("\x04", "\\x04").replace("\x00", "\\x00")
            print("  样例 %-46s -> %s" % (pretty_key[:46], msgstr.split("\x00")[0][:40]))
            shown += 1
            if shown >= 3:
                break

    if expect_language_name:
        want_key = EXPECT_CONTEXT + "\x04" + EXPECT_MSGID
        assert want_key in table, (
            "缺少语言名条目：msgctxt=%r msgid=%r（键 %r 不在表里，共 %d 键）"
            % (EXPECT_CONTEXT, EXPECT_MSGID, want_key, len(table))
        )
        got = table[want_key]
        assert got == EXPECT_MSGSTR, "语言名条目值不对：期望 %r，实际 %r" % (EXPECT_MSGSTR, got)
        print("  [OK] msgctxt=%r msgid=%r -> %r" % (EXPECT_CONTEXT, EXPECT_MSGID, got))
        # 复数条目抽查：键应为 singular\\x00plural，值按 \\x00 拆成形式数组。
        plural_examples = [(k, v) for k, v in table.items() if "\x00" in k and "\x04" not in k]
        if plural_examples:
            k, v = plural_examples[0]
            forms = v.split("\x00")
            print(
                "  [OK] 复数条目样例: %r -> %d 种形式 %r"
                % (k.replace("\x00", "\\x00"), len(forms), [f[:30] + ("…" if len(f) > 30 else "") for f in forms])
            )
            assert len(forms) >= 1, "复数条目没有翻译形式"

    print("  [OK] 解析出 %d 条翻译" % stats["total"])
    return stats["total"]


def main() -> int:
    parser = argparse.ArgumentParser(description="验证内置语言包 en-US/*.mo 的二进制解析")
    parser.add_argument(
        "--data-dir",
        default=os.path.join("HaxePort", "assets", "Localization", "pack", "assets", "mvz2", "en-US"),
        help="包含 *.mo 的目录（默认：内置语言包 assets/mvz2/en-US）",
    )
    args = parser.parse_args()

    data_dir = args.data_dir
    if not os.path.isabs(data_dir):
        data_dir = os.path.join(ROOT, data_dir)

    failures = 0
    for name in ("general.mo", "almanac.mo", "talk.mo"):
        path = os.path.join(data_dir, name)
        if not os.path.isfile(path):
            print("跳过（不存在）: %s" % os.path.relpath(path, ROOT))
            continue
        try:
            verify_file(path, expect_language_name=(name == "general.mo"))
        except AssertionError as e:
            failures += 1
            print("  [FAIL] %s" % e)
        except MoFormatError as e:
            failures += 1
            print("  [FAIL] MO 格式错误: %s" % e)

    print("=" * 78)
    if failures:
        print("失败 %d 个文件" % failures)
        return 1
    print("全部通过")
    return 0


if __name__ == "__main__":
    sys.exit(main())
