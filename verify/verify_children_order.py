#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""一次性对账：scene_prefabs（/model_prefabs）JSON 的 children 顺序 == Unity prefab 的 m_Children 顺序。

背景：`tools_build/build_models.py::build_node_graph` 曾按 YAML 文档序追加 children，而运行期
`ScenePrefabLoader.hx` / `ModelPrefabLoader.hx` 按节点下标升序 SetParent（shim 的
`Transform.SetParent` 是 push 到父级 children 末尾），兄弟节点的入表顺序即渲染 z-order
（`UiRenderer.walk` 按 children 顺序遍历）。修复后 children 按父 Transform 的 m_Children
数组顺序生成，nodes 按 DFS 先序重排（父下标 < 全部子下标）。

本脚本**不复用** build_node_graph：只用 build_models 的 prefab 合并层（YAML 解析 / 嵌套
PrefabInstance / 变体覆盖 / 引用解析）拿到 objects 表，再按约定语义独立重建期望树：

  * 父级归属 = 子节点自己 Transform 的 m_Father（解析不到 -> 孤儿根）；
  * 兄弟顺序 = 父 Transform 的 m_Children 数组顺序（m_Children 里找不到的子节点按
     objects 表文档序垫尾）；
  * 孤儿根 >1 时按导出器规则挂回主根（带 *Model 组件的根优先，否则子树最大）。

然后与 HaxePort/assets/scene_prefabs/**.json 逐文件对账：

  1. nodes 数组的**名字序列** == 期望 DFS 先序名字序列（同时覆盖 sibling 顺序、
     父子归属、数组顺序三条不变量）；
  2. roots 指向根节点；每个父节点下标 < 其全部子节点下标；
  3. 引用编码：JSON 里全部 {"n"[, "c"]} / {"asset"} 构成的多重集 == 按 objects 表
     独立算出的期望多重集（验证重排后 node_index_of_go / object_owner 的同步）。

用法（在仓库根目录执行）：
    python HaxePort/verify/verify_children_order.py                        # 对账全部 scene_prefabs
    python HaxePort/verify/verify_children_order.py --only Init/Titlescreen Mainmenu/Mainmenu
    python HaxePort/verify/verify_children_order.py --models               # 顺带对账 model_prefabs
    python HaxePort/verify/verify_children_order.py --data-dir <目录>      # 只对账某个目录
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from collections import Counter, OrderedDict

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(HERE, "..", "tools_build"))

import build_models as bm   # noqa: E402
import build_scene as bs    # noqa: E402


# --------------------------------------------------------------------------------------
# 独立重建期望树（刻意不复用 build_node_graph）
# --------------------------------------------------------------------------------------

def _transform_tables(objects):
    """(go key -> Transform rec) 与 (transform key -> go key)。"""
    transform_of_go = OrderedDict()
    transform_keys = {}
    for key, rec in objects.items():
        if rec["class"] not in ("Transform", "RectTransform"):
            continue
        go_key = bm._ref_key_of(rec["data"].get("m_GameObject"))
        if go_key is None:
            continue
        transform_keys[key] = go_key
        transform_of_go.setdefault(go_key, rec)
    return transform_of_go, transform_keys


def _expected_primary_root(roots, objects, transform_of_go, children, project):
    """复刻 build_models._primary_root：优先带 *Model 组件的根，否则子树最大。"""
    def model_root(index_key):
        rec = objects.get(index_key)
        if rec is None:
            return False
        for entry in rec["data"].get("m_Component") or []:
            comp_key = bm._ref_key_of(entry.get("component"))
            comp = objects.get(comp_key)
            if comp is None or comp["class"] != "MonoBehaviour":
                continue
            guid = bm._script_guid(comp["data"])
            script = project.script_index.get(guid) if guid else None
            if script and script["fullName"].split(".")[-1].endswith("Model"):
                return True
        return False

    for key in roots:
        if model_root(key):
            return key

    def subtree_size(key):
        total = 1
        for child in children.get(key, []):
            total += subtree_size(child)
        return total

    return max(roots, key=subtree_size) if roots else None


def build_expected(objects, project):
    """objects 表 -> (names_dfs, roots_dfs, expected_index, notes)。

    names_dfs      期望 DFS 先序的节点名序列（直接与 nodes 数组的 name 对比）
    roots_dfs      期望根节点下标（升序）
    expected_index GameObject key -> 期望节点下标
    notes          数据异常（孤儿根挂载等）
    """
    transform_of_go, transform_keys = _transform_tables(objects)
    go_order = [k for k, r in objects.items() if r["class"] == "GameObject"]
    go_rank = {k: i for i, k in enumerate(go_order)}
    notes = []

    # 父级归属：子 Transform 的 m_Father（与导出器一致；解析不到留作孤儿根）。
    parent_of = {}
    for go_key in go_order:
        tr = transform_of_go.get(go_key)
        if tr is None:
            continue
        parent_go = transform_keys.get(bm._ref_key_of(tr["data"].get("m_Father")))
        if parent_go in go_rank and parent_go != go_key:
            parent_of[go_key] = parent_go

    # children 顺序：父 Transform 的 m_Children（文档序垫底，稳定排序）。
    children = {}
    for go_key in go_order:  # 文档序收集
        children.setdefault(parent_of.get(go_key), []).append(go_key)
    for go_key in go_order:
        tr = transform_of_go.get(go_key)
        rank = {}
        if tr is not None:
            for pos, child in enumerate(tr["data"].get("m_Children") or []):
                child_go = transform_keys.get(bm._ref_key_of(child))
                if child_go not in go_rank or child_go == go_key or child_go in rank:
                    continue
                rank[child_go] = pos
        kids = children.get(go_key)
        if kids:
            kids.sort(key=lambda k: rank.get(k, len(rank)))

    # 孤儿根挂回主根（导出器默认行为）。
    roots = list(children.get(None, []))
    if len(roots) > 1:
        primary = _expected_primary_root(roots, objects, transform_of_go, children, project)
        if primary is not None:
            for key in roots:
                if key == primary:
                    continue
                parent_of[key] = primary
                children.setdefault(primary, []).append(key)
                notes.append("孤儿根 %s 挂回主根 %s" % (objects[key]["data"].get("m_Name"),
                                                       objects[primary]["data"].get("m_Name")))
            children[None] = [primary]
            roots = [primary]

    # DFS 先序（沿修正后的 children）。
    order = []
    stack = list(reversed(roots))
    while stack:
        key = stack.pop()
        order.append(key)
        stack.extend(reversed(children.get(key, [])))
    if len(order) < len(go_order):  # 不可达节点（数据损坏的环）按文档序兜底
        seen = set(order)
        order.extend(k for k in go_order if k not in seen)
        notes.append("有 %d 个节点从根不可达（疑似环）" % (len(go_order) - len(order)))

    expected_index = {k: i for i, k in enumerate(order)}
    names = [objects[k]["data"].get("m_Name") or "" for k in order]
    roots_dfs = sorted(i for i, k in enumerate(order) if parent_of.get(k) is None)
    return names, roots_dfs, expected_index, notes


# --------------------------------------------------------------------------------------
# 引用编码对账
# --------------------------------------------------------------------------------------

def _expected_object_owner(objects):
    """复刻导出的 object_owner：对象 key -> (GameObject key, 组件下标)。

    Transform -> (go, 0)；components[k] -> (go, k+1)；不在任何 m_Component 里的
    游离组件 -> (go, None)（编码时按 0 处理）。
    """
    owner = {}
    for key, rec in objects.items():
        if rec["class"] in ("Transform", "RectTransform"):
            owner[key] = (bm._ref_key_of(rec["data"].get("m_GameObject")), 0)
    for key, rec in objects.items():
        if rec["class"] != "GameObject":
            continue
        idx = 0
        for entry in rec["data"].get("m_Component") or []:
            comp_key = bm._ref_key_of(entry.get("component"))
            comp = objects.get(comp_key)
            if comp is None or comp["class"] in ("Transform", "RectTransform"):
                continue
            idx += 1
            owner[comp_key] = (key, idx)
    for key, rec in objects.items():
        if rec["class"] in ("GameObject", "Transform", "RectTransform"):
            continue
        if key not in owner:
            owner[key] = (bm._ref_key_of(rec["data"].get("m_GameObject")), None)
    return owner


def _iter_source_refs(value):
    """遍历投影后字段里的 {"$refkey": k} / {"$asset": {...}}。"""
    if isinstance(value, dict):
        if "$refkey" in value:
            yield ("refkey", value["$refkey"])
            return
        if "$asset" in value:
            yield ("asset", value["$asset"])
            return
        for v in value.values():
            yield from _iter_source_refs(v)
    elif isinstance(value, list):
        for v in value:
            yield from _iter_source_refs(v)


def expected_refs(objects, project, expected_index, projector, unmapped):
    """按 objects 表独立计算期望的引用编码多重集（元素与 JSON 里的形状一一对应）。"""
    owner = _expected_object_owner(objects)

    def encode(key):
        if key in expected_index:
            return ("n", expected_index[key], None)
        entry = owner.get(key)
        if entry is None or entry[0] is None:
            return None
        go_key, comp_idx = entry
        node = expected_index.get(go_key)
        if node is None:
            return None
        return ("n", node, comp_idx if comp_idx is not None else 0)

    out = Counter()
    for key, rec in objects.items():
        if rec["class"] != "GameObject":
            continue
        for entry in rec["data"].get("m_Component") or []:
            comp_key = bm._ref_key_of(entry.get("component"))
            comp = objects.get(comp_key)
            if comp is None or comp["class"] in ("Transform", "RectTransform"):
                continue
            projected = projector(comp["class"], comp["data"], project, unmapped)
            fields = projected[1]
            for kind, payload in _iter_source_refs(fields):
                if kind == "refkey":
                    enc = encode(payload)
                    if enc is not None:
                        out[enc] += 1
                else:
                    file_id = payload.get("fileID")
                    out[("asset", payload.get("guid"),
                         str(file_id) if file_id is not None else None)] += 1
    return out


def actual_refs(nodes):
    """从导出 JSON 收集引用编码多重集。"""
    out = Counter()

    def walk(v):
        if isinstance(v, dict):
            keys = set(v.keys())
            if keys == {"n"} and isinstance(v["n"], int) and not isinstance(v["n"], bool):
                out[("n", v["n"], None)] += 1
            elif keys == {"n", "c"} and isinstance(v["n"], int) and not isinstance(v["n"], bool):
                out[("n", v["n"], v["c"])] += 1
            elif keys == {"asset"} and isinstance(v["asset"], dict):
                out[("asset", v["asset"].get("guid"), v["asset"].get("fileID"))] += 1
            else:
                for x in v.values():
                    walk(x)
        elif isinstance(v, list):
            for x in v:
                walk(x)

    for node in nodes:
        walk(node.get("components"))
        walk(node.get("transform"))
    return out


# --------------------------------------------------------------------------------------
# 对账
# --------------------------------------------------------------------------------------

def verify_json(json_path, project, projector, unmapped):
    """对账单个导出文件。返回 (ok, problems)。"""
    problems = []
    with open(json_path, "r", encoding="utf-8") as f:
        payload = json.load(f)
    nodes = payload.get("nodes") or []
    source = payload.get("source")
    if not source:
        return False, ["JSON 缺少 source 字段"], []
    abs_path = os.path.join(project.root, source)
    if not os.path.exists(abs_path):
        return False, ["源文件不存在：%s" % source], []

    resolved = project.resolve_prefab(abs_path)
    objects = resolved["objects"]
    names, roots_dfs, expected_index, notes = build_expected(objects, project)
    problems = []

    actual_names = [n.get("name") or "" for n in nodes]
    if actual_names != names:
        for i, (a, e) in enumerate(zip(actual_names, names)):
            if a != e:
                problems.append(
                    "nodes[%d] 名字 %r != 期望 DFS 先序 %r（期望前缀 ...%s）"
                    % (i, a, e, names[max(0, i - 2):i + 6]))
                break
        else:
            problems.append("节点数 %d != 期望 %d" % (len(actual_names), len(names)))

    if list(payload.get("roots") or []) != roots_dfs:
        problems.append("roots=%s != 期望 %s" % (payload.get("roots"), roots_dfs))

    for i, node in enumerate(nodes):
        parent = node.get("parent")
        if parent is not None and not (0 <= parent < i):
            problems.append("nodes[%d](%s) parent=%s 违反父下标<子下标"
                            % (i, node.get("name"), parent))
            break
        for child in node.get("children") or []:
            if not child > i:
                problems.append("nodes[%d](%s) child=%s 违反父下标<子下标"
                                % (i, node.get("name"), child))
                break

    exp_refs = expected_refs(objects, project, expected_index, projector, unmapped)
    act_refs = actual_refs(nodes)
    if exp_refs != act_refs:
        missing = list((exp_refs - act_refs).elements())[:4]
        extra = list((act_refs - exp_refs).elements())[:4]
        problems.append("引用多重集不一致（缺 %s 项 %s；多 %s 项 %s）"
                        % (sum((exp_refs - act_refs).values()), missing,
                           sum((act_refs - exp_refs).values()), extra))

    return (not problems), problems, notes


def iter_json_files(data_dir):
    for dirpath, dirnames, filenames in os.walk(data_dir):
        dirnames.sort()
        for name in sorted(filenames):
            if name.endswith(".json"):
                yield os.path.join(dirpath, name)


def _scene_projector(doc_class, body, project, unmapped):
    return bs.project_component_scene(doc_class, body, project, unmapped)


def _model_projector(doc_class, body, project, unmapped):
    return bm.project_component(doc_class, body, project)


def run(data_dir, project, projector, only=None, label=""):
    unmapped = Counter()
    total = ok = noted = 0
    failures = []
    for path in iter_json_files(data_dir):
        rel = os.path.relpath(path, data_dir).replace("\\", "/")
        if only and not any(token in rel for token in only):
            continue
        total += 1
        try:
            good, problems, notes = verify_json(path, project, projector, unmapped)
        except Exception as exc:  # noqa: BLE001
            good, problems, notes = False, ["%s: %s" % (type(exc).__name__, exc)], []
        if good:
            ok += 1
            if notes:
                noted += 1
                print("  [OK*]  %s%s（%d 个孤儿根挂回主根，属导出器既定兜底）" % (label, rel, len(notes)))
            else:
                print("  [OK]   %s%s" % (label, rel))
        else:
            failures.append((rel, problems))
            print("  [FAIL] %s%s" % (label, rel))
            for p in problems[:6]:
                print("         - %s" % p)
    print("%s对账：一致 %d / %d（%.1f%%；其中 %d 个文件含孤儿根挂载提示，非差异）"
          % (label, ok, total, 100.0 * ok / total if total else 0.0, noted))
    return total, ok, failures


def check_titlescreen_dialog(project):
    """特别校验：Titlescreen.json 的 Dialog 节点 children == [Background, TitleArea, MainElements]。"""
    path = os.path.join(ROOT, "HaxePort", "assets", "scene_prefabs", "Prefabs", "Init",
                        "Titlescreen.json")
    if not os.path.exists(path):
        print("特别校验：Titlescreen.json 不存在（%s）" % path)
        return False
    with open(path, "r", encoding="utf-8") as f:
        nodes = json.load(f)["nodes"]

    def find(name, parent=None):
        for i, n in enumerate(nodes):
            if (n.get("name") or "") != name:
                continue
            if parent is None or n.get("parent") == parent:
                return i
        return None

    language_dialog = find("LanguageDialog")
    if language_dialog is None:
        print("特别校验：未找到 LanguageDialog 节点")
        return False
    dialog = find("Dialog", parent=language_dialog)
    if dialog is None:
        print("特别校验：未找到 LanguageDialog/Dialog 节点")
        return False
    children = [nodes[c].get("name") for c in nodes[dialog].get("children") or []]
    expected = ["Background", "TitleArea", "MainElements"]
    good = children == expected
    print("特别校验：Titlescreen.json Dialog children = %s %s（期望 %s）"
          % (children, "==" if good else "!=", expected))
    return good


def main(argv=None):
    parser = argparse.ArgumentParser(description="对账 scene_prefabs 的 children 顺序与 m_Children")
    parser.add_argument("--data-dir", default=os.path.join(ROOT, "HaxePort", "assets", "scene_prefabs"),
                        help="要对账的导出数据目录（默认 HaxePort/assets/scene_prefabs）")
    parser.add_argument("--models", action="store_true",
                        help="顺带对账 HaxePort/assets/model_prefabs")
    parser.add_argument("--only", nargs="*", default=None,
                        help="只对账路径包含这些子串的文件（如 Init/Titlescreen Mainmenu）")
    args = parser.parse_args(argv)
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except (AttributeError, ValueError):
        pass

    print("加载 Unity 工程索引（%s）……" % ROOT)
    project = bm.UnityProject(ROOT)

    total = ok = 0
    failures = []
    t, o, f = run(args.data_dir, project, _scene_projector, args.only, label="")
    total += t
    ok += o
    failures += f
    if args.models:
        t, o, f = run(os.path.join(ROOT, "HaxePort", "assets", "model_prefabs"), project,
                      _model_projector, args.only, label="model_prefabs/")
        total += t
        ok += o
        failures += f

    print()
    dialog_ok = check_titlescreen_dialog(project)
    print()
    print("总计：一致 %d / %d（%.1f%%）；Titlescreen Dialog 特别校验：%s"
          % (ok, total, 100.0 * ok / total if total else 0.0,
             "通过" if dialog_ok else "未通过"))
    return 0 if (ok == total and dialog_ok) else 1


if __name__ == "__main__":
    raise SystemExit(main())
