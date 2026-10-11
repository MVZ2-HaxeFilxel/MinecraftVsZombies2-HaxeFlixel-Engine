#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""MVZ2 Unity -> HaxeFlixel 移植：模型（prefab）转换器（工作包 ⑤）

把 Unity 工程里的模型 prefab（`Assets/**/*.prefab`，Unity YAML + 嵌套 PrefabInstance +
Prefab 变体继承）解析成扁平、可直接实例化的节点图，供 Haxe 侧
`mvz2.models.ModelPrefabLoader` / `ModelFactory` 在运行期构造 `unity.GameObject` 层级。

## 为什么需要这个脚本

C# 侧模型来自 Unity 资产：`ModelBuilder.Build()` 调 `ResourceManager.GetModel(modelMeta.Path)`
（Addressables 标签 `Model`）拿到 prefab，`GameObject.Instantiate` 克隆整棵层级，再
`model.Init(...)`。Haxe 侧没有 Unity prefab 资产，所以本脚本把 prefab 的「合并结果」
（包含全部嵌套 prefab 实例、变体属性覆盖、被删除的组件/对象）导出为 JSON，运行期按节点表重建。

Unity prefab 合并规则（本脚本实现的部分，对应 Unity 编辑器保存 prefab 时的行为）：
  1. 文件内非 `stripped` 的文档 = 本 prefab 自己新增的对象（GameObject/组件）。
  2. `PrefabInstance`（classID 1001）文档 = 对另一个 prefab 资产（`m_SourcePrefab.guid`）的实例化，
     其 `m_Modification` 里的 `m_TransformParent` 指定挂在哪个变换下（实例根 Transform 会挂过去，
     漏掉这一步会让所有子实例变成顶层节点）。
  3. `stripped` 文档 = 该实例里被修改过（或需要被引用）的源对象的覆盖数据，用
     `m_CorrespondingSourceObject: {fileID, guid}` 指回源 prefab 中的对象。
  4. `m_Modifications[].{target, propertyPath, value|objectReference}` = 对源对象字段的覆盖，
     支持 `a.b.c`、`list.Array.size`、`list.Array.data[i]` 三种路径形态。
  5. `m_RemovedComponents` / `m_RemovedGameObjects` = 从实例中删除的组件 / 对象（含子树）。
  6. `m_AddedComponents` / `m_AddedGameObjects` = 实例中新增的对象 / 组件（引用本文件的文档）。
     其中「新增的组件」要并进目标 GameObject 的 m_Component 列表——源 prefab 的列表里没有它，
     只有实例文件里有（Unity 也会把这类组件记在 m_AddedGameObjects 的 addedObject 里）。

## 已知的源工程数据问题（本脚本的处理方式）

Unity 生成的这批模型 prefab 里有相当数量的**悬空引用**：文件里写的 `{fileID, guid}` 在源 prefab
文件里根本没有对应对象（全工程搜索不到该 fileID 的锚点，在 Unity 里同样无法解析）。实测这些引用
要么是冗余覆盖（把 LocalPosition 归零、m_Name 设成原值、把列表重新指向本文件的副本），要么指向
源 prefab 中唯一符合条件的组件。因此：

  * 精确匹配失败时做**保守回退**（同类、MonoBehaviour 再要求同脚本、且候选唯一）——记为 recovered；
  * 仍无法解析的修改整条**跳过**（保留源 prefab 的值）而不是写入 null——记为 danglingRefs；
  * 悬空挂载点导致的「孤儿根」默认挂回资产根（Unity 的 prefab 只有一个根；运行时
    EntityController 只移动模型根，零件留在模型根之外会不跟随模型）——记为 strayRootsMounted；
    用 `--strays=detach` 可保留多个根以便对照。

以上三类计数都写进 models_manifest.json（工程级 stats + 每个模型各自的字段）。
彻底解决需要 Unity 侧导出一次 ground truth（用 PrefabUtility 加载 prefab 后把合并结果序列化成
JSON），本脚本的输出格式可以直接对拍。

## 与原始工程的对应关系（逐字段比对过的消费方）

  EntityModel.prefab / AreaModel.prefab / GridModel.prefab / UIModel.prefab：模型根 prefab
      （`Assets/Scripts/View/Models/Entity/EntityModel.cs` 等要求根上有 ModelGroupEntity/
      SortingGroup/Collider2D/ModelBone 组件）。
  ModelAnchor.prefab 组件（`Assets/Scripts/View/Models/ModelAnchor.cs`）：`key` 字段即
      `Model.GetAnchor(name)` 查找的锚点名；`Assets/GameContent/.../metas/models.xml` 的
      `<armorconfig><armor><anchor>` 与 `ModelInsertion.anchorName` 都引用这些 key。
  MonoBehaviour `MVZ2.Models.*Element`（GraphicElement/RendererElement/AnimatorElement/
      TransformElement/SortingGroupElement/ParticlePlayer...）：`excludedInGroup`、
      `elementName`、`lockToGround` 等序列化字段是运行期直接读取的数据。
  `ModelGroup`/`ModelGroupRenderer`/`ModelGroupEntity` 的 `modelAnchors` / `animators` /
      `renderers` / `particles` / `transforms` / `subSortingGroups` 列表：编辑器
      （`Assets/Scripts/Editor/Menus/ModelMenu.cs`）计算并写回 prefab，运行期直接使用
      （`ModelGroup.UpdateAnimations` 等遍历它们），所以这里必须按 prefab 里保存的顺序导出。
  `EntityModel.modelCollider` / `bone` / `group` / `sortingGroup`：同理来自 prefab 序列化字段。

## 输出

  <out>/models_manifest.json        索引：model id（NamespaceID）-> 元数据 + 分文件路径
  <out>/models/<model id path>.json 每个模型一棵节点树

单文件结构（Haxe 侧 `mvz2.models.ModelPrefabData` 一一对应）：
{
  "version": 1,
  "asset": "Assets/GameContent/Assets/mvz2/models/contraption/prologue/dispenser.prefab",
  "guid": "44cdfd7f2b25992498a3440f8b99e6da",
  "roots": [0],                       # 顶层节点（Unity prefab 应有且仅有一个）
  "nodes": [                         # DFS 先序（父下标 < 全部子下标；兄弟顺序 == m_Children 顺序）
    {
      "name": "dispenser",            # GameObject.m_Name
      "active": true,                 # m_IsActive
      "layer": 0,                     # m_Layer
      "parent": null,                 # 父节点下标
      "children": [1, 2],             # 子节点下标（m_Children 顺序）
      "transform": {"pos":[x,y,z], "rot":[x,y,z,w], "scale":[x,y,z], "hint":[x,y,z]},
      "components": [                 # 不含 Transform（Transform 由 transform 字段给出）
        {"type": "SpriteRenderer", "fields": {...}},
        {"type": "MonoBehaviour", "script": "MVZ2.Models.ModelAnchor",
         "haxe": "mvz2.models.ModelAnchor", "scriptGuid": "...", "fields": {"key": "head"}}
      ]
    }
  ],
  "warnings": ["..."]                 # 合并过程中的异常（运行期也会带进日志）
}

字段值的编码约定（与 Haxe 侧 ModelPrefabData 一致）：
  * 标量 / 字符串 / 布尔 = JSON 原生值
  * Unity 结构体 = {"t": "Vector3", "x":..., "y":..., "z":...} 等；仅保留实际用到的字段
  * 对图内对象的引用 = {"$n": 节点下标, "$c": 组件下标}
        $c 缺省 = 该节点的 GameObject 本身；$c == 0 = 该节点的 Transform；
        $c == k+1 = 该节点 components[k]
  * 对图外资产（贴图/材质/动画控制器/字体/FBX 等）的引用 =
        {"$asset": {"guid": ..., "fileID": ..., "path": "相对 HaxePort/assets 的路径",
                    "source": "Unity 工程内路径", "address": "Addressables 地址或 null",
                    "kind": "Image/Model/Other..."}}
  * null 引用（fileID: 0）= null

依赖：PyYAML（Unity 的 `!u!` 标签用 multi-constructor 处理）。缺库时脚本会给出提示。

用法（在仓库根目录执行）：
    python HaxePort/tools_build/build_models.py                # 全量转换
    python HaxePort/tools_build/build_models.py --report       # 只打印统计，不写文件
    python HaxePort/tools_build/build_models.py --only mvz2:contraption/prologue/dispenser
"""

from __future__ import annotations

import argparse
import copy
import json
import os
import re
import sys
import xml.etree.ElementTree as ET
from collections import Counter, OrderedDict

try:
    import yaml
except ImportError:  # pragma: no cover
    sys.stderr.write(
        "本脚本需要 PyYAML（pip install pyyaml）。Unity 的 prefab YAML 含自定义 !u! 标签，"
        "不能直接用 json/ini 解析。\n"
    )
    raise SystemExit(2)


# --------------------------------------------------------------------------------------
# 常量
# --------------------------------------------------------------------------------------

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DEFAULT_PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, "..", ".."))
DEFAULT_OUT_DIR = os.path.abspath(os.path.join(SCRIPT_DIR, "..", "assets"))

MODELS_XML = os.path.join("Assets", "GameContent", "Assets", "mvz2", "metas", "models.xml")
ASSET_GROUPS_DIR = os.path.join("Assets", "AddressableAssetsData", "AssetGroups")
# 每个模型的分文件目录（相对 <out>）。刻意不叫 models：assets/Models 是 Unity FBX 目录，
# Windows 不区分大小写，会写串。
MODEL_OUT_DIR_NAME = "model_prefabs"

DEFAULT_NAMESPACE = "mvz2"

# 文档头：`--- !u!<classID> &<fileID>[ stripped]`（fileID 可能为负）。
DOC_RE = re.compile(r"^--- !u!(-?\d+) &(-?\d+)( stripped)?$")
GUID_RE = re.compile(r"^guid: ([0-9a-f]{32})", re.M)
NAMESPACE_RE = re.compile(r"^\s*namespace\s+([A-Za-z_][\w.]*)", re.M)

UNITY_HEADER_FIELDS = {
    "m_ObjectHideFlags",
    "m_CorrespondingSourceObject",
    "m_PrefabInstance",
    "m_PrefabAsset",
    "m_GameObject",
    "m_Enabled",
    "m_EditorHideFlags",
    "m_Script",
    "m_Name",
    "m_EditorClassIdentifier",
    "serializedVersion",
}

# GameObject 里与运行期无关的编辑器字段。
GAMEOBJECT_DROP_FIELDS = {
    "m_ObjectHideFlags",
    "m_CorrespondingSourceObject",
    "m_PrefabInstance",
    "m_PrefabAsset",
    "m_Component",
    "m_Icon",
    "m_NavMeshLayer",
    "m_StaticEditorFlags",
    "m_TagString",
    "serializedVersion",
}

# SpriteRenderer 的白名单（Unity 的 SpriteRenderer 有 40+ 个渲染管线字段，移植层只需要这些）。
SPRITE_RENDERER_FIELDS = [
    ("m_Enabled", "enabled"),
    ("m_SortingLayerID", "sortingLayerID"),
    ("m_SortingLayer", "sortingLayer"),
    ("m_SortingOrder", "sortingOrder"),
    ("m_Sprite", "sprite"),
    ("m_Color", "color"),
    ("m_FlipX", "flipX"),
    ("m_FlipY", "flipY"),
    ("m_DrawMode", "drawMode"),
    ("m_Size", "size"),
    ("m_AdaptiveModeThreshold", "adaptiveModeThreshold"),
    ("m_SpriteTileMode", "spriteTileMode"),
    ("m_MaskInteraction", "maskInteraction"),
    ("m_SpriteSortPoint", "spriteSortPoint"),
    ("m_Materials", "materials"),
    ("m_RenderingLayerMask", "renderingLayerMask"),
]

# ParticleSystem：只取移植层 `unity.ParticleSystem` shim 暴露的字段（其余为渲染细节，见 TODO）。
PARTICLE_TOP_FIELDS = [
    ("looping", "loop"),
    ("prewarm", "prewarm"),
    ("playOnAwake", "playOnAwake"),
    ("lengthInSec", "duration"),
    ("moveWithTransform", "moveWithTransform"),
    ("scalingMode", "scalingMode"),
    ("simulationSpace", "simulationSpace"),
    ("randomSeed", "randomSeed"),
    ("useAutoRandomSeed", "useAutoRandomSeed"),
    ("stopAction", "stopAction"),
    ("cullingMode", "cullingMode"),
]

PARTICLE_INITIAL_FIELDS = [
    ("startDelay", "startDelay"),
    ("startLifetime", "startLifetime"),
    ("startSpeed", "startSpeed"),
    ("startSize", "startSize"),
    ("startRotation", "startRotation"),
    ("startColor", "startColor"),
    ("gravityModifier", "gravityModifier"),
    ("simulationSpeed", "simulationSpeed"),
    ("maxNumParticles", "maxParticles"),
]

PARTICLE_EMISSION_FIELDS = [
    ("enabled", "enabled"),
    ("rateOverTime", "rateOverTime"),
    ("rateOverDistance", "rateOverDistance"),
    ("m_Bursts", "bursts"),
]

PARTICLE_UV_FIELDS = [
    ("enabled", "enabled"),
    ("mode", "mode"),
    ("sprites", "sprites"),
    ("numTilesX", "numTilesX"),
    ("numTilesY", "tilesY"),
]

PARTICLE_SHAPE_FIELDS = [
    ("enabled", "enabled"),
    ("type", "shapeType"),
    ("radius", "radius"),
    ("radiusThickness", "radiusThickness"),
    ("angle", "angle"),
    ("arc", "arc"),
    ("position", "position"),
    ("rotation", "rotation"),
    ("scale", "scale"),
]

PARTICLE_RENDERER_FIELDS = [
    ("renderMode", "renderMode"),
    ("sortingOrder", "sortingOrder"),
    ("sortingLayerID", "sortingLayerID"),
    ("m_Materials", "materials"),
    ("material", "material"),
]

# PrefabInstance / stripped 文档里不参与合并的字段。
INSTANCE_HEADER_FIELDS = {
    "m_CorrespondingSourceObject",
    "m_PrefabInstance",
    "m_PrefabAsset",
    "m_ObjectHideFlags",
}


# --------------------------------------------------------------------------------------
# Unity YAML 解析
# --------------------------------------------------------------------------------------

class _UnityLoader(yaml.SafeLoader):
    pass


def _unity_tag_constructor(loader, tag_suffix, node):
    if isinstance(node, yaml.MappingNode):
        return loader.construct_mapping(node, deep=True)
    if isinstance(node, yaml.SequenceNode):
        return loader.construct_sequence(node, deep=True)
    return loader.construct_scalar(node)


_UnityLoader.add_multi_constructor("tag:unity3d.com,2011:", _unity_tag_constructor)


class Doc:
    """一个 Unity YAML 文档（= 一个序列化对象）。"""

    __slots__ = ("class_id", "file_id", "stripped", "class_name", "body")

    def __init__(self, class_id, file_id, stripped, class_name, body):
        self.class_id = class_id
        self.file_id = file_id
        self.stripped = stripped
        self.class_name = class_name
        self.body = body


def parse_unity_file(path):
    """解析 Unity YAML 文件为 Doc 列表。

    Unity 只在第一个文档前写 `%TAG !u! ...` 指令，后续文档直接用 `!u!`，
    而 YAML 规范要求每个文档各自声明指令，所以这里预处理文本逐文档补上指令。
    """
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()

    chunks = []  # (class_id, file_id, stripped, class_name, body_text)
    header = None
    lines = []
    for line in text.splitlines():
        m = DOC_RE.match(line)
        if m:
            if header is not None:
                chunks.append((header, lines))
            header = (int(m.group(1)), int(m.group(2)), bool(m.group(3)))
            lines = []
            continue
        if line.startswith("%YAML") or line.startswith("%TAG"):
            continue
        if header is not None:
            lines.append(line)
    if header is not None:
        chunks.append((header, lines))

    docs = []
    for (class_id, file_id, stripped), body_lines in chunks:
        body_text = "\n".join(body_lines)
        if not body_text.strip():
            continue
        tagged = "%TAG !u! tag:unity3d.com,2011:\n--- !u!" + str(class_id) + " &" + str(file_id) + "\n" + body_text
        data = yaml.load(tagged, Loader=_UnityLoader)
        if not isinstance(data, dict) or len(data) != 1:
            raise ValueError("意外的文档结构：%s &%d" % (path, file_id))
        class_name, body = next(iter(data.items()))
        docs.append(Doc(class_id, file_id, stripped, class_name, body or {}))
    return docs


# --------------------------------------------------------------------------------------
# 工程索引
# --------------------------------------------------------------------------------------

class UnityProject:
    """提供 GUID 索引、Addressables 索引、prefab 合并（含缓存）。"""

    def __init__(self, root):
        self.root = os.path.abspath(root)
        self.assets_dir = os.path.join(self.root, "Assets")
        self._guid_index = None
        self._addressables = None
        self._prefab_cache = {}
        self._resolved_cache = {}
        self._script_index = None
        self.warnings = []
        # 悬空引用统计（见 resolve_prefab 第 3 步的 PORT-NOTE）。
        self.dangling = 0
        self.recovered = 0
        # 通过 m_TransformParent 挂回实例根的次数（第 3.5 步）。
        self.mounted = 0
        # 并进目标 GameObject 的「新增组件」数量（第 4.5 步）。
        self.added_components = 0

    def warn(self, message):
        self.warnings.append(message)

    # -- 索引 ---------------------------------------------------------------

    @property
    def guid_index(self):
        """guid -> Unity 工程内的绝对路径（由 *.meta 建立，覆盖所有资产类型）。"""
        if self._guid_index is None:
            index = {}
            for dirpath, _dirnames, filenames in os.walk(self.assets_dir):
                for name in filenames:
                    if not name.endswith(".meta"):
                        continue
                    meta_path = os.path.join(dirpath, name)
                    try:
                        with open(meta_path, "r", encoding="utf-8", errors="replace") as f:
                            head = f.read(256)
                    except OSError:
                        continue
                    m = GUID_RE.search(head)
                    if not m:
                        continue
                    index.setdefault(m.group(1), meta_path[:-5])
            self._guid_index = index
        return self._guid_index

    @property
    def addressables(self):
        """address -> {guid, path, labels, group}（等价于运行期 Addressables 目录）。"""
        if self._addressables is None:
            index = OrderedDict()
            groups_dir = os.path.join(self.root, ASSET_GROUPS_DIR)
            if not os.path.isdir(groups_dir):
                self.warn("找不到 Addressables 分组目录：%s" % groups_dir)
                self._addressables = index
                return index
            for name in sorted(os.listdir(groups_dir)):
                if not name.endswith(".asset"):
                    continue
                group = name[:-6]
                path = os.path.join(groups_dir, name)
                current = None
                labels = []
                guid = None
                address = None

                def flush():
                    if address is None or guid is None:
                        return
                    index[address] = {
                        "guid": guid,
                        "path": self.guid_index.get(guid),
                        "labels": list(labels),
                        "group": group,
                    }

                with open(path, "r", encoding="utf-8", errors="replace") as f:
                    for raw in f:
                        line = raw.rstrip("\n")
                        stripped = line.strip()
                        if stripped.startswith("- m_GUID: "):
                            flush()
                            guid = stripped[len("- m_GUID: "):].strip()
                            address = None
                            labels = []
                        elif stripped.startswith("m_Address: "):
                            address = stripped[len("m_Address: "):].strip()
                        elif stripped.startswith("- "):
                            if address is not None and guid is not None:
                                labels.append(stripped[2:].strip())
                flush()
            self._addressables = index
        return self._addressables

    @property
    def script_index(self):
        """脚本 guid -> {path, namespace, class}（从 *.cs.meta + .cs 文件解析）。"""
        if self._script_index is None:
            index = {}
            for guid, path in self.guid_index.items():
                if not path.endswith(".cs"):
                    continue
                try:
                    with open(path, "r", encoding="utf-8", errors="replace") as f:
                        text = f.read()
                except OSError:
                    continue
                m = NAMESPACE_RE.search(text)
                namespace = m.group(1) if m else ""
                class_name = os.path.splitext(os.path.basename(path))[0]
                index[guid] = {
                    "path": os.path.relpath(path, self.root).replace("\\", "/"),
                    "namespace": namespace,
                    "class": class_name,
                    "fullName": (namespace + "." + class_name) if namespace else class_name,
                }
            self._script_index = index
        return self._script_index

    def rel_path(self, abs_path):
        """Unity 工程内路径 -> 相对 HaxePort/assets 的镜像路径。"""
        if abs_path is None:
            return None
        rel = os.path.relpath(abs_path, self.assets_dir).replace("\\", "/")
        return rel

    # -- prefab -------------------------------------------------------------

    def load_prefab(self, abs_path):
        """按绝对路径读取 prefab 文件（带缓存）。"""
        cached = self._prefab_cache.get(abs_path)
        if cached is not None:
            return cached
        docs = parse_unity_file(abs_path)
        guid = None
        meta_path = abs_path + ".meta"
        if os.path.exists(meta_path):
            with open(meta_path, "r", encoding="utf-8", errors="replace") as f:
                m = GUID_RE.search(f.read(256))
            guid = m.group(1) if m else None
        prefab = {"path": abs_path, "guid": guid, "docs": {d.file_id: d for d in docs}}
        self._prefab_cache[abs_path] = prefab
        return prefab

    def resolve_prefab(self, abs_path, stack=()):
        """把 prefab 文件解析成对象表（合并全部嵌套实例 / 覆盖 / 删除）。"""
        abs_path = os.path.abspath(abs_path)
        cached = self._resolved_cache.get(abs_path)
        if cached is not None:
            return cached
        if abs_path in stack:
            raise RuntimeError("prefab 循环引用：%s" % " -> ".join(list(stack) + [abs_path]))

        prefab = self.load_prefab(abs_path)
        if prefab["guid"] is None:
            raise RuntimeError("prefab 缺少 .meta / guid：%s" % abs_path)
        file_guid = prefab["guid"]
        docs = prefab["docs"]

        objects = OrderedDict()   # key -> {"class", "origin", "data"}
        doc_index = {}            # (guid, fileID) -> key（origin 索引，含深层 prefab 的对象）

        def local_key(file_id):
            return "%s#%d" % (file_guid, file_id)

        # 1) 本文件自有对象（GameObject / 组件）。
        local_docs = [d for d in docs.values() if not d.stripped and d.class_name != "PrefabInstance"]
        for doc in local_docs:
            key = local_key(doc.file_id)
            objects[key] = {
                "class": doc.class_name,
                "origin": (file_guid, doc.file_id),
                "data": copy.deepcopy(doc.body),
            }
            doc_index[(file_guid, doc.file_id)] = key

        # 2) 导入嵌套 prefab 实例（先导入全部，保证 stripped 文档能互相引用）。
        instances = [d for d in docs.values() if d.class_name == "PrefabInstance"]
        instances.sort(key=lambda d: d.file_id)
        instance_info = []   # (doc, prefix, src, src_guid, src_doc_index)
        for doc in instances:
            source = (doc.body.get("m_SourcePrefab") or {}).get("guid")
            if not source:
                self.warn("%s: PrefabInstance &%d 没有 m_SourcePrefab" % (self.rel_path(abs_path), doc.file_id))
                continue
            src_path = self.guid_index.get(source)
            if src_path is None or not src_path.endswith(".prefab"):
                self.warn("%s: 源 prefab guid=%s 无法解析" % (self.rel_path(abs_path), source))
                continue
            src = self.resolve_prefab(src_path, stack + (abs_path,))
            prefix = local_key(doc.file_id) + "/"
            for src_key, rec in src["objects"].items():
                new_key = prefix + src_key
                objects[new_key] = {
                    "class": rec["class"],
                    "origin": rec["origin"],
                    "data": _prefix_refs(rec["data"], prefix),
                }
            for origin, src_key in src["doc_index"].items():
                new_key = prefix + src_key
                if origin in doc_index and doc_index[origin] != new_key:
                    self.warn("%s: 源对象 %s&%d 被多次实例化，引用解析取先出现者"
                              % (self.rel_path(abs_path), origin[0], origin[1]))
                    continue
                doc_index[origin] = new_key
            candidates = _build_candidates(src["objects"])
            instance_info.append((doc, prefix, src, source, src["doc_index"], candidates,
                                  [prefix + k for k in src["root_transforms"]]))

        # 3) stripped 文档：把覆盖字段并回实例中的源对象，并建立「本文件 fileID -> 键」映射。
        #
        # PORT-NOTE: 生成的预制体里存在「指不回去的对应源对象」——Unity 写在文件里的
        # {fileID, guid} 在源 prefab 文件里根本没有对应对象（全工程搜索不到该 fileID 的锚点）。
        # 这类引用在 Unity 里同样是悬空的（无法解析），但实测它们要么是冗余覆盖（把
        # LocalPosition 归零、m_Name 设成原值、把列表重新指向本文件的副本），要么指向源
        # prefab 中唯一符合条件的组件（例如唯一的 Animator 的控制器）。因此这里做**保守回退**：
        # 只有在「源 prefab 中同类（MonoBehaviour 还要求同脚本）且尚未被占用的候选恰好只有一个」
        # 时才采用该候选，并在清单里记为 recovered；否则原样丢弃并记为 dangling（不猜）。
        stripped_docs = [d for d in docs.values() if d.stripped]
        stripped_docs.sort(key=lambda d: d.file_id)
        used_fallbacks = set()
        # PORT-NOTE: 同一个源 prefab 可以在本文件里被实例化**多次**（地图模型 castle.prefab 就把
        # MapButton.prefab 实例化了 22 次）。doc_index 以 (源 guid, 源 fileID) 为键，同一个源对象
        # 只能保存一条映射，于是所有 stripped 文档都会解析到「先出现的那个实例」——
        # 实测表现为地图上 22 个关卡按钮全部指向同一个 MapButton 节点。
        # 这里按 stripped 文档自己的 m_PrefabInstance 找到所属实例，在**该实例的**源对象表里解析。
        instance_by_id = {}
        for info in instance_info:
            instance_by_id[info[0].file_id] = info
        for doc in stripped_docs:
            body = doc.body
            inst = (body.get("m_PrefabInstance") or {}).get("fileID")
            corr = body.get("m_CorrespondingSourceObject") or {}
            corr_guid = corr.get("guid")
            corr_file = corr.get("fileID")
            if not inst or not corr_guid or corr_file is None:
                self.warn("%s: stripped &%d 缺少对应源对象" % (self.rel_path(abs_path), doc.file_id))
                continue
            target_key = None
            owner = instance_by_id.get(inst)
            if owner is not None:
                owner_prefix = owner[1]
                owner_index = owner[4]
                base = owner_index.get((corr_guid, corr_file))
                if base is not None:
                    candidate = owner_prefix + base
                    if candidate in objects:
                        target_key = candidate
            if target_key is None:
                target_key = doc_index.get((corr_guid, corr_file))
            fallback = False
            if target_key is None or target_key not in objects:
                script_guid = (body.get("m_Script") or {}).get("guid")
                target_key = _fallback_candidate(
                    instance_info, inst, doc.class_name, script_guid, used_fallbacks)
                if target_key is None:
                    self.dangling += 1
                    self.warn("%s: stripped &%d 指回的对象 %s&%d 不在实例中（悬空引用）"
                              % (self.rel_path(abs_path), doc.file_id, corr_guid, corr_file))
                    continue
                fallback = True
            rec = objects[target_key]
            for field, value in body.items():
                if field in INSTANCE_HEADER_FIELDS:
                    continue
                # Unity 在 stripped 文档里会把「需要从源对象解析」的引用写成 {fileID: 0}；
                # 若源对象里该字段原本有有效引用则不覆盖（否则组件会丢掉所属 GameObject）。
                if _is_null_ref(value) and not _is_null_ref(rec["data"].get(field)):
                    continue
                rec["data"][field] = copy.deepcopy(value)
            doc_index[(file_guid, doc.file_id)] = target_key
            if fallback:
                self.recovered += 1

        # 3.5) 应用 PrefabInstance 的挂载父级（m_Modification.m_TransformParent）。
        #
        # PORT-NOTE: 这是嵌套 prefab 实例「挂在谁的下面」的唯一来源：实例内部对象的 m_Father 来自
        # 源 prefab（实例根没有父级），必须把实例的**根 Transform**（源 prefab 里 m_Father 为 0 的
        # Transform）挂到 m_TransformParent 指定的对象上。漏掉这一步会让每个子实例都变成顶层节点
        # （表现为模型零件全部脱离模型根）。
        for doc, prefix, _src, _guid, _index, _candidates, src_roots in instance_info:
            tp = ((doc.body.get("m_Modification") or {}).get("m_TransformParent")) or {}
            parent_file = tp.get("fileID")
            if not parent_file:
                continue
            parent_key = doc_index.get((file_guid, parent_file))
            if parent_key is None or parent_key not in objects:
                self.warn("%s: 实例 &%d 的挂载父级 fileID=%s 无法解析"
                          % (self.rel_path(abs_path), doc.file_id, parent_file))
                continue
            for key in src_roots:
                rec = objects.get(key)
                if rec is None or rec["class"] not in ("Transform", "RectTransform"):
                    continue
                if _ref_key_of(rec["data"].get("m_Father")) is not None:
                    continue
                rec["data"]["m_Father"] = {"$refkey": parent_key}
                self.mounted += 1

        # 4) 应用 m_Modifications（此时 doc_index 已包含本文件与外层实例的全部对象）。
        removed_components = []
        removed_objects = []
        for doc, prefix, src, src_guid, src_doc_index, candidates, _src_roots in instance_info:
            mod = doc.body.get("m_Modification") or {}
            for entry in mod.get("m_Modifications") or []:
                target = entry.get("target") or {}
                target_guid = target.get("guid")
                target_file = target.get("fileID")
                if target_file is None:
                    continue
                path = entry.get("propertyPath") or ""
                if target_guid:
                    # target.guid 指向源 prefab 文件；文件内的 fileID 用实例前缀映射。
                    base = src_doc_index.get((target_guid, target_file))
                    if base is None:
                        # 悬空引用回退：按 propertyPath 推断目标组件类型，取唯一候选。
                        key = _fallback_candidate2(
                            candidates, prefix, path, used_fallbacks)
                        if key is None:
                            self.dangling += 1
                            self.warn("%s: 修改目标 %s&%d（%s）无法解析"
                                      % (self.rel_path(abs_path), target_guid, target_file, path))
                            continue
                        self.recovered += 1
                    else:
                        key = prefix + base
                else:
                    key = doc_index.get((file_guid, target_file))
                if key is None or key not in objects:
                    self.dangling += 1
                    self.warn("%s: 修改目标 fileID=%s 不在对象表中" % (self.rel_path(abs_path), target_file))
                    continue
                # Unity 同时写 value 与 objectReference：objectReference 只在
                # 引用非 null（fileID != 0 或带 guid）时才是真正的赋值。
                ref = entry.get("objectReference")
                if _is_null_ref(ref) or ref is None:
                    value = entry.get("value")
                else:
                    value = ref
                # 值为对象引用时先解析成图内键：解析不了就**整条修改跳过**（保留源 prefab 的值），
                # 而不是写入 null——否则会把源 prefab 里本来正确的列表项清空。
                # Unity 对悬空引用也是「记一条警告并忽略这条修改」。
                if _is_ref_dict(value) and not (value.get("fileID") == 0 and not value.get("guid")):
                    ref_key = _lookup_target(doc_index, src_doc_index, prefix, file_guid,
                                             value.get("guid"), value.get("fileID"))
                    if ref_key is None or ref_key not in objects:
                        self.dangling += 1
                        self.warn("%s: 修改值（%s = %s）引用无法解析，已跳过该修改"
                                  % (self.rel_path(abs_path), path, value.get("fileID")))
                        continue
                    value = {"$refkey": ref_key}
                _apply_property(objects[key]["data"], path, value)

            for entry in mod.get("m_RemovedComponents") or []:
                guid = entry.get("guid")
                file_id = entry.get("fileID")
                key = _lookup_target(doc_index, src_doc_index, prefix, file_guid, guid, file_id)
                if key and key in objects:
                    removed_components.append(key)
                else:
                    self.dangling += 1
                    self.warn("%s: 删除的组件 %s&%s 无法解析" % (self.rel_path(abs_path), guid, file_id))

            for entry in mod.get("m_RemovedGameObjects") or []:
                guid = entry.get("guid")
                file_id = entry.get("fileID")
                key = _lookup_target(doc_index, src_doc_index, prefix, file_guid, guid, file_id)
                if key and key in objects:
                    removed_objects.append(key)
                else:
                    self.dangling += 1
                    self.warn("%s: 删除的对象 %s&%s 无法解析" % (self.rel_path(abs_path), guid, file_id))

            # 4.5) 实例里「新增的组件」要并进目标 GameObject 的 m_Component 列表。
            #
            # Unity 的语义：m_AddedComponents 把组件加到实例中的某个对象上；源 prefab 的
            # m_Component 列表里没有它，只有这份实例文件里有。不处理的话，prefab 里对它的引用
            # （例如 ModelGroupRenderer.renderers 指向新加的 RendererElement）就会指到对象上
            # 的 Transform 而不是组件（ModelMenu.UpdateModelElements 会给每个 Renderer 补一个
            # RendererElement，正是这种数据）。
            # 注意：Unity 也会把这类组件记在 m_AddedGameObjects 的 addedObject 里（addedObject
            # 为组件而不是 GameObject/Transform 时按组件处理）。
            added_entries = list(mod.get("m_AddedComponents") or [])
            for entry in mod.get("m_AddedGameObjects") or []:
                added_doc = docs.get((entry.get("addedObject") or {}).get("fileID"))
                if added_doc is not None and added_doc.class_name in ("GameObject", "Transform", "RectTransform"):
                    continue
                added_entries.append(entry)
            for entry in added_entries:
                target = entry.get("targetCorrespondingSourceObject") or {}
                added = entry.get("addedObject") or {}
                target_key = _lookup_target(doc_index, src_doc_index, prefix, file_guid,
                                            target.get("guid"), target.get("fileID"))
                comp_key = doc_index.get((file_guid, added.get("fileID")))
                if target_key is None or target_key not in objects or comp_key is None or comp_key not in objects:
                    if comp_key is not None or added.get("fileID"):
                        self.dangling += 1
                        self.warn("%s: 新增组件的目标 %s 或组件 %s 无法解析"
                                  % (self.rel_path(abs_path), target.get("fileID"), added.get("fileID")))
                    continue
                target_rec = objects[target_key]
                if target_rec["class"] != "GameObject":
                    continue
                comps = target_rec["data"].setdefault("m_Component", [])
                if any(_ref_key_of(c.get("component")) == comp_key for c in comps if isinstance(c, dict)):
                    continue
                comps.append({"component": {"$refkey": comp_key}})
                self.added_components += 1

        # 5) 删除组件 / 对象（含子树的 Transform 链）。
        for key in removed_components:
            for rec in objects.values():
                comps = rec["data"].get("m_Component")
                if isinstance(comps, list):
                    rec["data"]["m_Component"] = [
                        c for c in comps if _ref_key_of(c.get("component")) != key
                    ]
        for key in removed_objects:
            for dead in _collect_subtree(objects, key):
                objects.pop(dead, None)

        # 6) 引用解析（本文件作用域的裸 fileID 引用 + 外部资产引用）。
        for rec in objects.values():
            rec["data"] = _resolve_refs(rec["data"], file_guid, doc_index, self)

        # 本资产自己的顶层 Transform（m_Father 解析不到父级）：外层实例化它时，这些 Transform
        # 会被挂到 m_TransformParent 指定的对象上（见第 3.5 步）。正常情况下只有一个。
        root_transforms = [
            key for key, rec in objects.items()
            if rec["class"] in ("Transform", "RectTransform")
            and _ref_key_of(rec["data"].get("m_Father")) is None
        ]
        result = {"path": abs_path, "guid": file_guid, "objects": objects,
                  "doc_index": doc_index, "root_transforms": root_transforms}
        self._resolved_cache[abs_path] = result
        return result


def _lookup_target(doc_index, src_doc_index, prefix, file_guid, guid, file_id):
    if file_id is None:
        return None
    if guid:
        base = src_doc_index.get((guid, file_id))
        return prefix + base if base else None
    return doc_index.get((file_guid, file_id))


# --------------------------------------------------------------------------------------
# 悬空引用的保守回退
# --------------------------------------------------------------------------------------
#
# Unity 的 prefab 变体里存在无法从文件解析的 {fileID, guid} 引用（见 resolve_prefab 第 3 步
# 的 PORT-NOTE）。这里按「同类候选唯一」的规则做保守回退：候选 = 源 prefab 中的对象，
# 先按 Unity 类名过滤（MonoBehaviour 再按脚本 guid 过滤，Collider2D 家族合并），
# 只有恰好剩下一个候选时才采用。属性名到组件类型的映射只用于确定「要什么类型的目标」，
# 不做任何位置/顺序上的猜测。

# propertyPath 前缀 -> 目标 Unity 类名（None 表示不限定）；脚本类名用于 MonoBehaviour 再过滤。
PROPERTY_TARGET_HINTS = [
    (re.compile(r"^renderers\.Array"), "MonoBehaviour", "RendererElement"),
    (re.compile(r"^animators\.Array"), "MonoBehaviour", "AnimatorElement"),
    (re.compile(r"^particles\.Array"), "MonoBehaviour", "ParticlePlayer"),
    (re.compile(r"^modelAnchors\.Array"), "MonoBehaviour", "ModelAnchor"),
    (re.compile(r"^transforms\.Array"), "MonoBehaviour", "TransformElement"),
    (re.compile(r"^subSortingGroups\.Array"), "MonoBehaviour", "SortingGroupElement"),
    (re.compile(r"^bone$"), "MonoBehaviour", "ModelBone"),
    (re.compile(r"^group$"), "MonoBehaviour", "ModelGroupEntity"),
    (re.compile(r"^sortingGroup$"), "SortingGroup", None),
    (re.compile(r"^modelCollider$"), "Collider2D", None),
    (re.compile(r"^m_(Controller|UpdateMode|ApplyRootMotion|CullingMode|Avatar)$"), "Animator", None),
    (re.compile(r"^m_(Sprite|FlipX|FlipY|DrawMode|MaskInteraction|SpriteTileMode)$"), "SpriteRenderer", None),
    (re.compile(r"^m_(LocalPosition|LocalRotation|LocalScale|LocalEulerAnglesHint|Children|Father)"),
     "Transform", None),
    (re.compile(r"^m_(Name|Layer|IsActive|TagString)$"), "GameObject", None),
    (re.compile(r"^(looping|prewarm|playOnAwake|lengthInSec|moveWithTransform|scalingMode|"
                r"simulationSpace|randomSeed|useAutoRandomSeed|stopAction|cullingMode|"
                r"InitialModule\.|EmissionModule\.|ShapeModule\.|UVModule\.|ColorModule\.|"
                r"SizeModule\.|NoiseModule\.|CollisionModule\.|TriggerModule\.|RendererModule\.)"),
     "ParticleSystem", None),
]


def _class_matches(candidate_class, hint_class):
    if hint_class == "Collider2D":
        return candidate_class.endswith("Collider2D")
    return candidate_class == hint_class


def _script_guid(data):
    """从 MonoBehaviour 数据里取脚本 guid（兼容引用已解析/未解析两种形态）。"""
    ref = data.get("m_Script")
    if not isinstance(ref, dict):
        return None
    if "guid" in ref:
        return ref.get("guid")
    asset = ref.get("$asset")
    return asset.get("guid") if isinstance(asset, dict) else None


def _build_candidates(objects):
    """源 prefab 的对象按 (类名, 脚本 guid) 分组，供悬空引用回退使用。"""
    by_class = {}
    for key, rec in objects.items():
        script = _script_guid(rec["data"]) if rec["class"] == "MonoBehaviour" else None
        by_class.setdefault((rec["class"], script), []).append(key)
    return by_class


def _pick_candidate(candidates, hint_class, hint_script, used):
    """在候选表里挑出唯一的匹配项（已被占用或数量不是 1 时返回 None）。"""
    found = []
    for (cls, script), keys in candidates.items():
        if hint_class is not None and not _class_matches(cls, hint_class):
            continue
        if hint_script is not None and script != hint_script:
            continue
        found.extend(keys)
    found = [k for k in found if k not in used]
    if len(found) != 1:
        return None
    used.add(found[0])
    return found[0]


def _fallback_candidate(instance_info, instance_file_id, class_name, script_guid, used):
    """stripped 文档的悬空对应源对象：按 (类名, 脚本) 唯一回退。"""
    for doc, prefix, _src, _guid, _index, candidates, _roots in instance_info:
        if doc.file_id != instance_file_id:
            continue
        key = _pick_candidate(candidates, class_name, script_guid, used)
        return prefix + key if key is not None else None
    return None


def _fallback_candidate2(candidates, prefix, property_path, used):
    """修改项的悬空目标：按 propertyPath 推断类型后唯一回退。"""
    hint_class = None
    hint_script = None
    for pattern, cls, script_class in PROPERTY_TARGET_HINTS:
        if pattern.search(property_path or ""):
            hint_class = cls
            hint_script = script_class
            break
    if hint_class is None and hint_script is None:
        return None
    key = _pick_candidate(candidates, hint_class, hint_script, used)
    return prefix + key if key is not None else None


def _is_null_ref(value):
    return isinstance(value, dict) and value.get("fileID") == 0 and "guid" not in value


def _ref_key_of(value):
    """读取解析后的引用里记录的键（解析前/后都可能被调用）。"""
    if isinstance(value, dict):
        return value.get("$refkey")
    return None


def _prefix_refs(data, prefix):
    """把导入子 prefab 的数据里的对象引用键加上实例前缀。"""
    if isinstance(data, dict):
        if "$refkey" in data:
            return {"$refkey": prefix + data["$refkey"]}
        return {k: _prefix_refs(v, prefix) for k, v in data.items()}
    if isinstance(data, list):
        return [_prefix_refs(v, prefix) for v in data]
    return data


def _apply_property(data, path, value):
    """应用一条 prefab 修改（支持 a.b.c / list.Array.size / list.Array.data[i]）。"""
    if not path:
        return
    parts = path.split(".")
    target = data
    i = 0
    while i < len(parts):
        part = parts[i]
        is_last = i == len(parts) - 1
        if part == "Array":
            # list.Array.size / list.Array.data[i]
            nxt = parts[i + 1] if not is_last else None
            if nxt == "size":
                if value is not None:
                    _resize_list(target, int(value))
                return
            m = re.fullmatch(r"data\[(\d+)\]", nxt or "")
            if m:
                index = int(m.group(1))
                rest = parts[i + 2:]
                if rest:
                    if not isinstance(target, list):
                        return
                    while len(target) <= index:
                        target.append(None)
                    target[index] = _apply_property(target[index] if isinstance(target[index], dict) else {}, ".".join(rest), value)
                    return
                if isinstance(target, list):
                    while len(target) <= index:
                        target.append(None)
                    target[index] = value
                return
            return
        if is_last:
            if isinstance(target, dict):
                target[part] = value
            elif isinstance(target, list) and part.isdigit():
                idx = int(part)
                while len(target) <= idx:
                    target.append(None)
                target[idx] = value
            return
        if not isinstance(target, dict):
            return
        if part not in target or target[part] is None:
            target[part] = {}
        target = target[part]
        i += 1


def _resize_list(data, size):
    if not isinstance(data, list) or size < 0:
        return
    while len(data) > size:
        data.pop()
    while len(data) < size:
        data.append(None)


def _collect_subtree(objects, root_key):
    """收集被删除对象及其所有子对象（沿 Transform.m_Children）。"""
    dead = []
    stack = [root_key]
    seen = set()
    while stack:
        key = stack.pop()
        if key in seen:
            continue
        seen.add(key)
        rec = objects.get(key)
        if rec is None:
            continue
        dead.append(key)
        if rec["class"] == "GameObject":
            for entry in rec["data"].get("m_Component") or []:
                child_key = _ref_key_of(entry.get("component"))
                if child_key and child_key in objects:
                    stack.append(child_key)
        elif rec["class"] in ("Transform", "RectTransform"):
            for child in rec["data"].get("m_Children") or []:
                child_key = _ref_key_of(child)
                if child_key and child_key in objects:
                    stack.append(child_key)
            go_key = _ref_key_of(rec["data"].get("m_GameObject"))
            if go_key:
                stack.append(go_key)
    return dead


def _is_ref_dict(value):
    """判断是否为 Unity 的引用字典：{fileID[, guid][, type]}。"""
    if not isinstance(value, dict) or "fileID" not in value:
        return False
    return set(value.keys()) <= {"fileID", "guid", "type"}


def _resolve_refs(data, file_guid, doc_index, project):
    """把数据里的 Unity 引用（{fileID, guid}）转成内部键或外部资产描述。"""
    if isinstance(data, dict):
        if "$refkey" in data:
            return data
        if _is_ref_dict(data):
            file_id = data.get("fileID")
            guid = data.get("guid")
            if file_id == 0 and not guid:
                return None
            key = doc_index.get((guid or file_guid, file_id))
            if key is not None:
                return {"$refkey": key}
            if guid:
                path = project.guid_index.get(guid)
                return {
                    "$asset": {
                        "guid": guid,
                        "fileID": file_id,
                        "path": project.rel_path(path),
                        "source": (os.path.relpath(path, project.root).replace("\\", "/")
                                   if path else None),
                        "address": _address_of(project, guid),
                        "kind": _kind_of_asset(path),
                    }
                }
            # 本文件作用域内解析不到的裸 fileID（悬空引用）：按 null 处理。
            return None
        return {k: _resolve_refs(v, file_guid, doc_index, project) for k, v in data.items()}
    if isinstance(data, list):
        return [_resolve_refs(v, file_guid, doc_index, project) for v in data]
    return data


def _address_of(project, guid):
    for address, entry in project.addressables.items():
        if entry["guid"] == guid:
            return address
    return None


KIND_BY_EXT = {
    "png": "Image", "jpg": "Image", "jpeg": "Image", "tga": "Image", "psd": "Image",
    "bmp": "Image", "gif": "Image", "exr": "Image", "tif": "Image", "tiff": "Image",
    "ogg": "Audio", "wav": "Audio", "mp3": "Audio", "aiff": "Audio", "aif": "Audio",
    "fbx": "Model", "obj": "Model", "dae": "Model", "blend": "Model",
    "mat": "Material", "controller": "AnimatorController", "overridecontroller": "AnimatorController",
    "anim": "AnimationClip", "ttf": "Font", "otf": "Font", "shader": "Shader",
    "asset": "ScriptableObject", "prefab": "Prefab", "mixer": "AudioMixer",
}


def _kind_of_asset(path):
    if not path:
        return "Unknown"
    ext = os.path.splitext(path)[1].lstrip(".").lower()
    return KIND_BY_EXT.get(ext, "Other")


# --------------------------------------------------------------------------------------
# 组件字段投影
# --------------------------------------------------------------------------------------

def _struct_tag(keys):
    """按 Unity 结构体的字段集合判断类型（用于把 {x,y,z} 之类转成带类型标记的形式）。"""
    keys = set(keys)
    if keys == {"x", "y"}:
        return "Vector2", ("x", "y")
    if keys == {"x", "y", "z"}:
        return "Vector3", ("x", "y", "z")
    if keys == {"x", "y", "z", "w"}:
        return "Vector4", ("x", "y", "z", "w")
    if keys == {"r", "g", "b", "a"}:
        return "Color", ("r", "g", "b", "a")
    if keys == {"x", "y", "width", "height"}:
        return "Rect", ("x", "y", "width", "height")
    return None, None


def _convert_value(value, project):
    """把已经解析过引用的数据转成 JSON 可写形态。

    结构体统一编码为 {"t": <类型名>, "v": [按 Unity 字段顺序的分量]}，
    Haxe 侧 ModelPrefabContext 按 t 构造 unity.Vector2/Vector3/Vector4/Color/Rect。
    分量一律写成浮点字面量（0 -> 0.0）：Haxe 的 Array<Float> 在静态目标上需要 Float，
    JSON 里写成整数会被解析成 Int。
    """
    if isinstance(value, dict):
        if "$refkey" in value or "$asset" in value:
            return value
        tag, order = _struct_tag(value.keys())
        if tag is not None:
            return {"t": tag, "v": [_as_float(value[k]) for k in order]}
        return {k: _convert_value(v, project) for k, v in value.items()}
    if isinstance(value, list):
        return [_convert_value(v, project) for v in value]
    return value


def _as_float(value):
    """整数/浮点都转成浮点（JSON 里就是 0.0 这样的字面量）；其它类型原样返回。"""
    if isinstance(value, bool) or value is None:
        return value
    if isinstance(value, (int, float)):
        return float(value)
    return value


def _minmax_curve(value):
    """Unity ParticleSystem.MinMaxCurve -> 移植层 unity.ParticleSystem.MinMaxCurve 字段。

    minMaxState: 0=Constant 1=Curve 2=TwoConstants 3=TwoCurves（与 UnityEngine.ParticleSystemCurveMode 一致）。
    字段名对齐 untiy shim：mode/constant/constantMin/constantMax/curve/curveMin/curveMax。
    曲线只在关键帧多于两个（不是默认直线）时导出。
    """
    if not isinstance(value, dict):
        return value
    out = OrderedDict()
    out["mode"] = value.get("minMaxState", 0)
    for src, dst in (("scalar", "constant"), ("minScalar", "constantMin"), ("maxScalar", "constantMax")):
        if src in value:
            out[dst] = value[src]
    if "minScalar" not in value and "scalar" in value:
        out["constantMin"] = value["scalar"]
    for src, dst in (("maxCurve", "curveMax"), ("minCurve", "curveMin")):
        curve = value.get(src)
        if isinstance(curve, dict):
            keys = curve.get("m_Curve")
            if isinstance(keys, list) and len(keys) > 2:
                out[dst] = [{"time": k.get("time"), "value": k.get("value")} for k in keys]
    return out


def _minmax_gradient(value):
    """Unity ParticleSystem.MinMaxGradient -> unity.ParticleSystem.MinMaxGradient 字段。"""
    if not isinstance(value, dict):
        return value
    out = OrderedDict()
    out["mode"] = value.get("minMaxState", 0)
    for src, dst in (("minColor", "colorMin"), ("maxColor", "colorMax")):
        color = value.get(src)
        if isinstance(color, dict) and {"r", "g", "b", "a"} <= set(color.keys()):
            out[dst] = [color["r"], color["g"], color["b"], color["a"]]
    if "colorMin" in out:
        out["color"] = out["colorMin"]
    return out


def _particle_bursts(value):
    if not isinstance(value, list):
        return value
    out = []
    for burst in value:
        if not isinstance(burst, dict):
            continue
        out.append({
            "time": burst.get("time", 0),
            "count": _minmax_curve(burst.get("m_Count")),
            "cycleCount": burst.get("cycleCount", 1),
            "repeatInterval": burst.get("repeatInterval", 0),
            "probability": burst.get("probability", 1),
        })
    return out


def _particle_sprites(value):
    if not isinstance(value, list):
        return value
    out = []
    for entry in value:
        if not isinstance(entry, dict):
            continue
        out.append({
            "sprite": entry.get("sprite"),
            "renderMode": entry.get("renderMode", 0),
            "channel": entry.get("channel", 0),
        })
    return out


def _particle_shape(body):
    """ShapeModule -> unity.ParticleSystem.ShapeModule（radius 是 MultiModeParameter，取其 value）。"""
    out = OrderedDict()
    for src, dst in PARTICLE_SHAPE_FIELDS:
        if src not in body:
            continue
        value = body[src]
        if src == "radius" and isinstance(value, dict):
            value = value.get("value", 1)
        if src == "radiusThickness":
            continue
        out[dst] = value
    return out


def _field_map(body, spec):
    out = OrderedDict()
    for src, dst in spec:
        if src in body:
            out[dst] = body[src]
    return out


def _generic_fields(body):
    return OrderedDict(
        (k, v) for k, v in body.items() if k not in UNITY_HEADER_FIELDS
    )


def project_component(doc_class, body, project):
    """把组件文档投影成运行期字段集合。"""
    if doc_class == "SpriteRenderer":
        return "SpriteRenderer", _field_map(body, SPRITE_RENDERER_FIELDS)
    if doc_class == "Animator":
        fields = OrderedDict()
        if "m_Enabled" in body:
            fields["enabled"] = body["m_Enabled"]
        # 字段名对齐 unity.Animator shim：m_Controller -> runtimeAnimatorController（shim 的
        # controller 字段是 flixel 的 FlxAnimationController，不能塞资产对象）。
        for src, dst in (("m_Avatar", "avatar"), ("m_Controller", "runtimeAnimatorController"),
                         ("m_CullingMode", "cullingMode"), ("m_UpdateMode", "updateMode"),
                         ("m_ApplyRootMotion", "applyRootMotion"),
                         ("m_Speed", "speed"), ("m_LinearVelocityBlending", "linearVelocityBlending")):
            if src in body:
                fields[dst] = body[src]
        return "Animator", fields
    if doc_class == "ParticleSystem":
        fields = OrderedDict()
        fields.update(_field_map(body, PARTICLE_TOP_FIELDS))
        initial = body.get("InitialModule")
        if isinstance(initial, dict):
            out = OrderedDict()
            for src, dst in PARTICLE_INITIAL_FIELDS:
                if src not in initial:
                    continue
                value = initial[src]
                if src == "startColor":
                    value = _minmax_gradient(value)
                elif src in ("startLifetime", "startSpeed", "startSize", "startRotation",
                             "gravityModifier", "startDelay"):
                    value = _minmax_curve(value)
                out[dst] = value
            fields["initial"] = out
        emission = body.get("EmissionModule")
        if isinstance(emission, dict):
            out = OrderedDict()
            for src, dst in PARTICLE_EMISSION_FIELDS:
                if src not in emission:
                    continue
                value = emission[src]
                if src == "m_Bursts":
                    value = _particle_bursts(value)
                elif src in ("rateOverTime", "rateOverDistance"):
                    value = _minmax_curve(value)
                out[dst] = value
            fields["emission"] = out
        shape = body.get("ShapeModule")
        if isinstance(shape, dict):
            fields["shape"] = _particle_shape(shape)
        uv = body.get("UVModule")
        if isinstance(uv, dict):
            out = OrderedDict()
            for src, dst in PARTICLE_UV_FIELDS:
                if src not in uv:
                    continue
                value = uv[src]
                if src == "sprites":
                    value = _particle_sprites(value)
                out[dst] = value
            fields["textureSheetAnimation"] = out
        renderer = body.get("RendererModule")
        if isinstance(renderer, dict):
            fields["systemRenderer"] = _field_map(renderer, PARTICLE_RENDERER_FIELDS)
        if "enabled" not in fields:
            fields["enabled"] = body.get("m_Enabled", 1)
        # TODO-PORT: ParticleSystem 只导出移植层 shim 用到的模块字段；其余模块
        # （SizeOverLifetime / ColorBySpeed / Collision / Noise / Trails 等）未导出。
        return "ParticleSystem", fields
    if doc_class in ("BoxCollider2D", "CircleCollider2D", "CapsuleCollider2D",
                     "PolygonCollider2D", "EdgeCollider2D", "CompositeCollider2D", "Collider2D"):
        fields = OrderedDict()
        if "m_Enabled" in body:
            fields["enabled"] = body["m_Enabled"]
        for src, dst in (("m_IsTrigger", "isTrigger"), ("m_UsedByEffector", "usedByEffector"),
                         ("m_Offset", "offset"), ("m_Size", "size"), ("m_Radius", "radius"),
                         ("m_Direction", "direction"), ("m_Density", "density"),
                         ("m_Points", "points"), ("m_EdgeRadius", "edgeRadius"),
                         ("m_CallbackLayers", "callbackLayers")):
            if src in body:
                fields[dst] = body[src]
        return doc_class, fields
    if doc_class == "SortingGroup":
        fields = OrderedDict()
        if "m_Enabled" in body:
            fields["enabled"] = body["m_Enabled"]
        for src, dst in (("m_SortingLayerID", "sortingLayerID"), ("m_SortingLayer", "sortingLayer"),
                         ("m_SortingOrder", "sortingOrder"), ("m_SortAtRoot", "sortAtRoot")):
            if src in body:
                fields[dst] = body[src]
        return "SortingGroup", fields
    if doc_class in ("ParticleSystemRenderer", "MeshRenderer", "LineRenderer", "SpriteMask",
                     "TrailRenderer", "MeshRenderer2D"):
        # 字段名对齐 unity.Renderer shim（m_Enabled/m_Materials/m_SortingLayerID/m_SortingOrder）。
        fields = OrderedDict()
        if "m_Enabled" in body:
            fields["enabled"] = body["m_Enabled"]
        for src, dst in (("m_Materials", "materials"), ("m_SortingLayerID", "sortingLayerID"),
                         ("m_SortingLayer", "sortingLayer"), ("m_SortingOrder", "sortingOrder"),
                         ("renderMode", "renderMode"), ("m_MaskInteraction", "maskInteraction")):
            if src in body:
                fields[dst] = body[src]
        return doc_class, fields
    if doc_class == "MonoBehaviour":
        script_guid = _script_guid(body)
        script = project.script_index.get(script_guid) if script_guid else None
        fields = OrderedDict()
        if "m_Enabled" in body:
            fields["enabled"] = body["m_Enabled"]
        fields.update(_generic_fields(body))
        return "MonoBehaviour", fields, script
    # 其它组件：保留全部（去掉 Unity 头字段），运行期不认识的类型会跳过并计数。
    return doc_class, _generic_fields(body)


# --------------------------------------------------------------------------------------
# 节点图构建
# --------------------------------------------------------------------------------------

def _project_transform(doc_class, data):
    """Transform / RectTransform 文档 -> 节点上的变换数据（字段名对应 unity.Transform）。

    分量一律是浮点（JSON 写 0.0），原因是 Haxe 侧类型是 Array<Float>。
    """
    def vec(name, size, default):
        value = data.get(name)
        if isinstance(value, dict):
            order = ("x", "y", "z", "w")[:size]
            return [float(value.get(k, 0)) for k in order]
        return [float(v) for v in default]

    out = OrderedDict()
    out["pos"] = vec("m_LocalPosition", 3, [0, 0, 0])
    out["rot"] = vec("m_LocalRotation", 4, [0, 0, 0, 1])
    out["scale"] = vec("m_LocalScale", 3, [1, 1, 1])
    out["hint"] = vec("m_LocalEulerAnglesHint", 3, [0, 0, 0])
    if doc_class == "RectTransform":
        out["rect"] = {
            "anchoredPosition": vec("m_AnchoredPosition", 2, [0, 0]),
            "sizeDelta": vec("m_SizeDelta", 2, [0, 0]),
            "anchorMin": vec("m_AnchorMin", 2, [0.5, 0.5]),
            "anchorMax": vec("m_AnchorMax", 2, [0.5, 0.5]),
            "pivot": vec("m_Pivot", 2, [0.5, 0.5]),
        }
    return out


def build_node_graph(resolved, project):
    """把对象表转换成节点数组（GameObject 树）。"""
    objects = resolved["objects"]

    # 键 -> (节点下标, 组件下标)，用于把引用转成下标。
    go_by_key = {}
    for key, rec in objects.items():
        if rec["class"] == "GameObject":
            go_by_key[key] = rec

    node_index_of_go = {}
    nodes = []

    def node_of(key):
        return node_index_of_go.get(key)

    # 先建节点骨架（保持对象表中的顺序）。
    for key, rec in objects.items():
        if rec["class"] != "GameObject":
            continue
        node_index_of_go[key] = len(nodes)
        nodes.append({
            "key": key,
            "name": rec["data"].get("m_Name") or "",
            "active": rec["data"].get("m_IsActive", 1) != 0,
            "layer": rec["data"].get("m_Layer", 0),
            "parent": None,
            "children": [],
            "transform": None,
            "components": [],
        })

    # 反向映射：对象键 -> 所在节点 / 组件下标。
    object_owner = {}
    transform_keys = {}
    for key, rec in objects.items():
        if rec["class"] not in ("Transform", "RectTransform"):
            continue
        go_key = _ref_key_of(rec["data"].get("m_GameObject"))
        object_owner[key] = (go_key, 0)
        transform_keys[key] = go_key

    for key, rec in objects.items():
        if key in node_index_of_go or key in object_owner:
            continue
        go_key = _ref_key_of(rec["data"].get("m_GameObject"))
        object_owner[key] = (go_key, None)  # 组件下标稍后填

    warnings = []
    # 组件列出（按 GameObject.m_Component 顺序），同时记录组件下标。
    for key in list(node_index_of_go.keys()):
        node = nodes[node_index_of_go[key]]
        rec = objects[key]
        for entry in rec["data"].get("m_Component") or []:
            comp_key = _ref_key_of(entry.get("component"))
            if comp_key is None or comp_key not in objects:
                continue
            comp = objects[comp_key]
            if comp["class"] in ("Transform", "RectTransform"):
                node["transform"] = _project_transform(comp["class"], comp["data"])
                object_owner[comp_key] = (key, 0)
                continue
            projected = project_component(comp["class"], comp["data"], project)
            if len(projected) == 3:
                comp_type, fields, script = projected
            else:
                comp_type, fields = projected
                script = None
            entry_rec = {
                "type": comp_type,
                "fields": _convert_value(fields, project),
            }
            if script is not None:
                entry_rec["script"] = script["fullName"]
                entry_rec["scriptPath"] = script["path"]
                entry_rec["haxe"] = haxe_class_of(script["namespace"], script["class"])
            node["components"].append(entry_rec)
            object_owner[comp_key] = (key, len(node["components"]))
        if node["transform"] is None:
            warnings.append("节点 %s 没有 Transform" % node["name"])

    # 父子关系。
    #
    # PORT-NOTE: children 的顺序必须按**父 Transform 的 m_Children 数组顺序**生成，不能按
    # YAML 文档序追加。运行期两个加载器都按节点下标升序 SetParent（ScenePrefabLoader.hx 与
    # ModelPrefabLoader.hx 的「4) 恢复父子关系（按 m_Children 顺序）」），shim 的
    # Transform.SetParent 是 push 到父级 children 末尾——兄弟节点的入表顺序即渲染 z-order
    # （UiRenderer.walk 按 children 顺序遍历）。而 YAML 文档序与 m_Children 序无关：
    # Titlescreen 实例化 LanguageDialog 时，Dialog 的文档序是 MainElements/TitleArea/
    # Background，m_Children 却是 Background/TitleArea/MainElements，按文档序导出会让
    # Background 盖在标题和按钮上。
    # 父级归属仍由子节点自己的 m_Father 决定（解析不到时留作孤儿根，交给下面的兜底挂载）；
    # m_Children 只决定兄弟顺序，m_Children 里找不到的子节点按文档序排在末尾。

    # 每个节点下标 -> 其 Transform/RectTransform 对象记录。
    node_transform = {}
    for key, idx in node_index_of_go.items():
        for entry in objects[key]["data"].get("m_Component") or []:
            comp_key = _ref_key_of(entry.get("component"))
            comp = objects.get(comp_key)
            if comp is not None and comp["class"] in ("Transform", "RectTransform"):
                node_transform[idx] = comp
                break

    for idx, node in enumerate(nodes):
        tr = node_transform.get(idx)
        if tr is None:
            continue
        parent_go = transform_keys.get(_ref_key_of(tr["data"].get("m_Father")))
        if parent_go is None:
            continue
        parent_idx = node_index_of_go.get(parent_go)
        if parent_idx is not None:
            node["parent"] = parent_idx

    children_by_parent = {}
    for idx, node in enumerate(nodes):
        children_by_parent.setdefault(node["parent"], []).append(idx)
    for idx, node in enumerate(nodes):
        children = children_by_parent.get(idx)
        if not children:
            continue
        tr = node_transform.get(idx)
        if tr is not None:
            # m_Children 里的 child transform fileID -> GameObject key -> 节点下标；
            # 自引用与重复项取先出现的位置。
            rank = {}
            for pos, child in enumerate(tr["data"].get("m_Children") or []):
                child_go = transform_keys.get(_ref_key_of(child))
                child_idx = node_index_of_go.get(child_go) if child_go is not None else None
                if child_idx is None or child_idx == idx or child_idx in rank:
                    continue
                rank[child_idx] = pos
            # list.sort 稳定：不在 m_Children 里的子节点保持文档序、追加到末尾兜底。
            children.sort(key=lambda c: rank.get(c, len(rank)))
        node["children"] = children

    roots = [i for i, n in enumerate(nodes) if n["parent"] is None]

    # 一个 Unity prefab 资产只有一个根 GameObject。解析后若出现多个根，说明某些 m_Father /
    # m_TransformParent 在源文件里就是悬空引用（见脚本头部 PORT-NOTE），无法还原真实的挂载点。
    # 这种零件如果留在顶层，会挂到模型根之外（运行时 EntityController 只移动模型根，
    # 见 EntityController.cs:455 `model.transform.localPosition = modelPosition`），表现为
    # 零件不跟随模型。因此默认把它们挂回资产根（单一树），并记录数量与名字供后续核对；
    # 用 --strays=detach 可改回“保持多个根”。
    stray_count = 0
    if len(roots) > 1 and getattr(project, "mount_strays", True):
        primary = _primary_root(nodes, roots)
        if primary is not None:
            for index in roots:
                if index == primary:
                    continue
                node = nodes[index]
                node["parent"] = primary
                nodes[primary]["children"].append(index)
                stray_count += 1
                warnings.append("节点 %s 的挂载父级在 prefab 里无法解析，已挂回资产根" % node["name"])
            roots = [primary]
            warnings.append("悬空挂载点导致的孤儿根：%d 个" % stray_count)

    # 树建完后按 DFS 先序重排 nodes：父节点下标 < 其全部子节点下标，且兄弟节点的数组
    # 顺序 == children 顺序 == m_Children 顺序（运行期按数组顺序 SetParent，见上面
    # 父子关系处的 PORT-NOTE）。object_owner 的值存的是 GameObject key 而不是节点下标，
    # 不需要跟着重排更新；_encode_refs 走下标，所以重排必须发生在它之前。
    order = []
    seen = set()
    stack = list(reversed(roots))
    while stack:
        idx = stack.pop()
        if idx in seen:
            continue
        seen.add(idx)
        order.append(idx)
        stack.extend(reversed(nodes[idx]["children"]))
    if len(order) < len(nodes):  # 不可达节点（只有数据损坏的环才会出现）按原序兜底
        order.extend(i for i in range(len(nodes)) if i not in seen)
    new_index = {old: new for new, old in enumerate(order)}
    reordered = []
    for old_idx in order:
        node = nodes[old_idx]
        parent = node["parent"]
        node["parent"] = new_index[parent] if parent is not None else None
        node["children"] = [new_index[c] for c in node["children"]]
        reordered.append(node)
    nodes = reordered
    node_index_of_go = {node["key"]: i for i, node in enumerate(nodes)}

    # 引用 -> 下标（重排之后的最终下标）。
    for node in nodes:
        node["components"] = [_encode_refs(c, node_index_of_go, object_owner) for c in node["components"]]
        if node["transform"] is not None:
            node["transform"] = _encode_refs(node["transform"], node_index_of_go, object_owner)

    roots = [i for i, n in enumerate(nodes) if n["parent"] is None]

    for i, node in enumerate(nodes):
        node.pop("key", None)
    return nodes, roots, warnings, stray_count


def _primary_root(nodes, roots):
    """在多个根里挑出「资产根」：优先带 Model 组件（EntityModel/AreaModel/UIModel…）的节点。"""
    for index in roots:
        for comp in nodes[index]["components"]:
            script = comp.get("script")
            if script and script.split(".")[-1].endswith("Model"):
                return index
    # 退而求其次：子树最大的根。
    def subtree_size(index):
        total = 1
        for child in nodes[index]["children"]:
            total += subtree_size(child)
        return total
    return max(roots, key=subtree_size) if roots else None


def _encode_refs(value, node_index_of_go, object_owner):
    """把内部引用键转成节点下标，把外部资产引用转成 Haxe 侧可直接读的字段名。

    * 图内引用 -> {"n": 节点下标} / {"n": 节点下标, "c": 组件下标}
      （c 缺省 = GameObject；c == 0 = Transform；c == k+1 = components[k]）
    * 图外资产 -> {"asset": {"guid", "fileID"(字符串，避免 19 位整数在 JSON/浮点里丢精度),
                              "path", "source", "address", "kind"}}
    """
    if isinstance(value, dict):
        if "$refkey" in value:
            key = value["$refkey"]
            if key in node_index_of_go:
                return {"n": node_index_of_go[key]}
            owner = object_owner.get(key)
            if owner is None or owner[0] is None:
                return None
            go_key, comp_idx = owner
            node_idx = node_index_of_go.get(go_key)
            if node_idx is None:
                return None
            return {"n": node_idx, "c": comp_idx if comp_idx is not None else 0}
        if "$asset" in value:
            asset = value["$asset"]
            file_id = asset.get("fileID")
            return {"asset": {
                "guid": asset.get("guid"),
                "fileID": str(file_id) if file_id is not None else None,
                "path": asset.get("path"),
                "source": asset.get("source"),
                "address": asset.get("address"),
                "kind": asset.get("kind"),
            }}
        return {k: _encode_refs(v, node_index_of_go, object_owner) for k, v in value.items()}
    if isinstance(value, list):
        return [_encode_refs(v, node_index_of_go, object_owner) for v in value]
    return value


def haxe_class_of(namespace, class_name):
    """C# 命名空间 + 类名 -> Haxe 全限定类名（PORTING.md 的包映射规则）。"""
    if not namespace:
        return class_name
    package = namespace.lower()
    return package + "." + class_name


# --------------------------------------------------------------------------------------
# models.xml
# --------------------------------------------------------------------------------------

def parse_models_xml(path):
    """解析 metas/models.xml：模型元数据 + 护甲配置（对应 C# ModelMeta/ModelMetaList）。"""
    tree = ET.parse(path)
    root = tree.getroot()
    models = OrderedDict()
    armor_configs = []
    for node in root:
        if node.tag == "model":
            name = node.get("name") or ""
            type_name = node.get("type") or ""
            path_attr = node.get("path")
            path = None
            if path_attr:
                if ":" in path_attr:
                    path = path_attr
                else:
                    path = DEFAULT_NAMESPACE + ":" + path_attr
            params = []
            animator = node.find("animator")
            update_on_shot = False
            if animator is not None:
                update_on_shot = (animator.get("updateOnShot") or "false").lower() == "true"
                parameters = animator.find("parameters")
                if parameters is not None:
                    for child in parameters:
                        item = {"type": child.tag, "name": child.get("name")}
                        if child.get("value") is not None:
                            item["value"] = child.get("value")
                        params.append(item)
            properties = {}
            props_node = node.find("properties")
            if props_node is not None:
                for child in props_node:
                    properties[child.get("name") or child.tag] = child.get("value")
            armor = None
            armor_node = node.find("armorconfig")
            if armor_node is not None and armor_node.text:
                armor = armor_node.text.strip()
            models[path] = {
                "id": path,
                "type": type_name,
                "name": name,
                "metaId": (type_name + "/" + name) if type_name else name,
                "shot": (node.get("shot") or "true").lower() != "false",
                "width": int(node.get("width") or 64),
                "height": int(node.get("height") or 64),
                "xOffset": float(node.get("xOffset") or 0),
                "yOffset": float(node.get("yOffset") or 0),
                "armorConfig": armor,
                "animatorUpdateOnShot": update_on_shot,
                "animatorParameters": params,
                "properties": properties,
            }
        elif node.tag == "armorconfig":
            armor_configs.append(node.get("id"))
    return models, armor_configs


# --------------------------------------------------------------------------------------
# 输出
# --------------------------------------------------------------------------------------

def sanitize_model_file_path(model_id):
    """model id（NamespaceID）-> 输出文件相对路径。

    注意：输出目录名用 `model_prefabs`（而不是 `models`）——HaxePort/assets/Models 是镜像
    里的 Unity FBX 目录，Windows 文件系统不区分大小写，用 `models` 会写进那个目录里。
    """
    namespace, _, path = model_id.partition(":")
    safe = re.sub(r"[^A-Za-z0-9_.\-/]", "_", path)
    safe = safe.strip("/")
    if not safe:
        safe = "_"
    return os.path.join(MODEL_OUT_DIR_NAME, namespace, safe + ".json")


def build(args):
    project = UnityProject(args.project_root)
    project.mount_strays = args.strays == "root"
    models_xml = os.path.join(project.root, MODELS_XML)
    if not os.path.exists(models_xml):
        sys.stderr.write("找不到 %s\n" % models_xml)
        return 2
    model_metas, armor_configs = parse_models_xml(models_xml)

    stats = Counter()
    manifest_models = OrderedDict()
    written = 0

    for model_id, meta in model_metas.items():
        if args.only and model_id not in args.only:
            continue
        stats["total"] += 1
        entry = project.addressables.get(model_id)
        if entry is None:
            stats["missing_address"] += 1
            meta["error"] = "Addressables 中没有该地址"
            manifest_models[model_id] = meta
            continue
        source = entry["path"]
        if source is None:
            stats["missing_source"] += 1
            meta["error"] = "GUID %s 无法解析到文件" % entry["guid"]
            manifest_models[model_id] = meta
            continue
        if not source.endswith(".prefab"):
            stats["not_prefab"] += 1
            meta["error"] = "地址指向的不是 prefab：%s" % project.rel_path(source)
            manifest_models[model_id] = meta
            continue
        dangling_before = project.dangling
        recovered_before = project.recovered
        try:
            resolved = project.resolve_prefab(source)
            nodes, roots, node_warnings, stray_count = build_node_graph(resolved, project)
        except Exception as exc:  # noqa: BLE001 - 转换失败要记录到清单而不是中断
            stats["failed"] += 1
            meta["error"] = "%s: %s" % (type(exc).__name__, exc)
            manifest_models[model_id] = meta
            continue

        warnings = list(node_warnings)
        dangling = project.dangling - dangling_before
        recovered = project.recovered - recovered_before
        counts = Counter()
        for node in nodes:
            for comp in node["components"]:
                counts[comp["type"]] += 1
                if comp["type"] == "MonoBehaviour":
                    counts["script:" + (comp.get("script") or "unknown")] += 1
        stats["converted"] += 1
        stats["nodes"] += len(nodes)
        stats["danglingRefs"] += dangling
        stats["recoveredRefs"] += recovered
        stats["strayRootsMounted"] += stray_count
        if stray_count:
            stats["modelsWithStrayRoots"] += 1
        for key, value in counts.items():
            stats["component:" + key] += value

        out_rel = sanitize_model_file_path(model_id)
        meta["prefab"] = {
            "asset": project.rel_path(source),
            "source": os.path.relpath(source, project.root).replace("\\", "/"),
            "guid": resolved["guid"],
            "labels": entry["labels"],
            "group": entry["group"],
            "data": out_rel.replace("\\", "/"),
            "nodeCount": len(nodes),
            "componentCount": sum(len(n["components"]) for n in nodes),
            "rootCount": len(roots),
        }
        if dangling or recovered:
            meta["danglingRefs"] = dangling
            meta["recoveredRefs"] = recovered
        meta["unsupportedComponents"] = sorted(
            k for k in counts if _is_unsupported_component(k)
        )
        if warnings:
            meta["warnings"] = warnings
        if stray_count:
            meta["strayRoots"] = stray_count
        manifest_models[model_id] = meta

        if not args.report:
            payload = {
                "version": 1,
                "generatedBy": "HaxePort/tools_build/build_models.py",
                "model": model_id,
                "asset": project.rel_path(source),
                "source": os.path.relpath(source, project.root).replace("\\", "/"),
                "guid": resolved["guid"],
                "labels": entry["labels"],
                "roots": roots,
                "nodes": nodes,
                "warnings": warnings,
            }
            os.makedirs(os.path.join(args.out, os.path.dirname(out_rel)), exist_ok=True)
            with open(os.path.join(args.out, out_rel), "w", encoding="utf-8", newline="\n") as f:
                json.dump(payload, f, ensure_ascii=False, indent=None, sort_keys=False)
                f.write("\n")
            written += 1

    if not args.report:
        manifest = {
            "version": 1,
            "generatedBy": "HaxePort/tools_build/build_models.py",
            "note": ("模型 prefab 已合并嵌套实例/变体覆盖，导出为节点表；"
                     "运行期由 mvz2.models.ModelPrefabLoader 重建 GameObject 层级。"
                     "字段编码约定见脚本头部注释。"
                     "models 是数组（元素带 id 字段）：Haxe 侧从 JSON 解析只得到匿名对象，"
                     "Map 需要在运行期自行建立（见 ModelPrefabLoader）。"),
            "namespace": DEFAULT_NAMESPACE,
            "assetsRoot": "HaxePort/assets",
            "armorConfigs": armor_configs,
            "count": len([m for m in manifest_models.values() if "prefab" in m]),
            "models": list(manifest_models.values()),
            "stats": dict(sorted(stats.items())),
            "warnings": project.warnings[:200],
        }
        os.makedirs(args.out, exist_ok=True)
        with open(os.path.join(args.out, "models_manifest.json"), "w", encoding="utf-8", newline="\n") as f:
            json.dump(manifest, f, ensure_ascii=False, indent=1, sort_keys=False)
            f.write("\n")

    # 报告
    print("models.xml 条目：%d（护甲配置 %d）" % (len(model_metas), len(armor_configs)))
    for key in sorted(stats):
        if key.startswith("component:"):
            continue
        print("  %-22s %s" % (key, stats[key]))
    print("组件类型统计：")
    for key in sorted(k for k in stats if k.startswith("component:")):
        print("  %-46s %s" % (key[len("component:"):], stats[key]))
    print("工程级告警：%d 条（清单里只保留前 200 条）" % len(project.warnings))
    if written:
        print("已写出：%s/models_manifest.json，模型文件 %d 个" % (args.out, written))
    return 0


# 移植层有对应 Haxe 类的组件类型（与 mvz2.models.ModelPrefabComponentTypes 的映射同步维护）。
SUPPORTED_COMPONENT_TYPES = {
    "SpriteRenderer", "Animator", "ParticleSystem", "ParticleSystemRenderer",
    "MeshRenderer", "SortingGroup", "MonoBehaviour",
    "BoxCollider", "BoxCollider2D", "CircleCollider2D", "CapsuleCollider2D",
    "PolygonCollider2D", "EdgeCollider2D", "CompositeCollider2D", "Collider2D",
    "Rigidbody2D", "Light", "LineRenderer", "SpriteMask", "Camera", "AudioSource",
    "Canvas", "CanvasGroup", "CanvasRenderer", "TextMesh",
}


def _is_unsupported_component(component_type):
    """导出数据里出现、但移植层没有对应 Haxe 类的组件类型（例如 MeshFilter / TrailRenderer）。"""
    if component_type.startswith("script:"):
        return False
    return component_type not in SUPPORTED_COMPONENT_TYPES


def main(argv=None):
    parser = argparse.ArgumentParser(description="MVZ2 模型 prefab -> HaxeFlixel JSON 转换器")
    parser.add_argument("--project-root", default=DEFAULT_PROJECT_ROOT,
                        help="Unity 工程根目录（含 Assets/），默认仓库根目录")
    parser.add_argument("--out", default=DEFAULT_OUT_DIR,
                        help="输出目录（HaxePort/assets）")
    parser.add_argument("--report", action="store_true", help="只打印统计，不写文件")
    parser.add_argument("--only", action="append", default=None,
                        help="只转换指定 model id（可多次指定），便于排查单个模型")
    parser.add_argument("--strays", choices=["root", "detach"], default="root",
                        help="悬空挂载点导致的孤儿根如何处理：root=挂回资产根（默认，保持单根），"
                             "detach=保持多个根（便于对照 Unity 的原始数据）")
    args = parser.parse_args(argv)
    # Windows 控制台默认 GBK，报告里的中文会乱码。
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except (AttributeError, ValueError):
        pass
    return build(args)


if __name__ == "__main__":
    raise SystemExit(main())
