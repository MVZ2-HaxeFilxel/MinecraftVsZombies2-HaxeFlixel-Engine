// PORT-NOTE: 本文件是移植层新增的编译期宏，没有 C# 对应源码。
//
// `unity.Application.version` 原先硬编码 "0.0.0"，而真实版本号写在 HaxePort 的 `Project.xml`
// （注意文件名是大写 P，Linux 上大小写敏感）第 5 行的应用定义里：
//   <app title="..." file="MVZ2" main="Main" package="..." version="0.4.5" company="..." />
// 这个文件是 lime 的工程定义，也是发布产物的版本号来源，因此 version 只应从这里取。
//
// 本宏在**编译期**把它读出来并注入为字符串字面量（运行期零 IO），由 `unity.Application`
// 的 `@:build` 调用（先例：`system.reflection.DefinitionRegistry` + DefinitionRegistryMacro.hx）。
// 找不到 Project.xml 或解析不出 version 时只发警告并保留字段声明初值 "0.0.0"，不阻断构建。
package unity;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import sys.FileSystem;
import sys.io.File;
#end

class ApplicationVersionMacro {
	#if macro
	/** `unity.Application` 的 `@:build` 入口：把 `version` 字段的初值换成 Project.xml 里的版本号。 */
	public static function build():Array<Field> {
		var fields = Context.getBuildFields();
		var version = readVersion();
		if (version == null) {
			Context.warning("ApplicationVersionMacro：未能从 Project.xml 读到 version，"
				+ "unity.Application.version 保留声明初值 0.0.0。", Context.currentPos());
			return fields;
		}
		var replaced = false;
		for (field in fields) {
			var access = field.access;
			if (field.name != "version" || access == null || access.indexOf(AStatic) < 0)
				continue;
			switch (field.kind) {
				case FVar(t, _):
					field.kind = FVar(t, macro $v{version});
					replaced = true;
				default:
			}
		}
		if (!replaced)
			Context.warning("ApplicationVersionMacro：unity.Application 上没找到静态字段 version，版本号未注入。",
				Context.currentPos());
		return fields;
	}

	/** 依次尝试候选路径，返回第一个能解析出 version 的结果；全部失败返回 null。 */
	static function readVersion():Null<String> {
		for (path in candidatePaths()) {
			if (!FileSystem.exists(path))
				continue;
			var text:Null<String> = null;
			try {
				text = File.getContent(path);
			} catch (e:Dynamic) {
				continue;
			}
			var version = parseAppVersion(text);
			if (version != null)
				return version;
		}
		return null;
	}

	/**
	 * Project.xml 的候选路径。
	 * cwd 视调用方而定（工程根或 HaxePort 子目录），再加上从 classpath 推出的 source 根的上一级。
	 */
	static function candidatePaths():Array<String> {
		var bases:Array<String> = [];
		// PORT-NOTE: 宏里没有 Context.getCwd()（`haxe.macro.Context` 无此方法），用 Sys.getCwd()。
		var cwd = Sys.getCwd();
		pushBase(bases, cwd);
		pushBase(bases, cwd + "/HaxePort");
		var sourceRoot = findSourceRoot();
		if (sourceRoot != null) {
			var i = sourceRoot.lastIndexOf("/");
			if (i > 0)
				pushBase(bases, sourceRoot.substr(0, i));
		}
		var paths:Array<String> = [];
		for (base in bases) {
			// 文件名大小写两种拼写都试（Windows 无所谓，Linux 只有一种能命中）。
			paths.push(base + "/Project.xml");
			paths.push(base + "/project.xml");
		}
		return paths;
	}

	static function pushBase(bases:Array<String>, dir:String):Void {
		var normalized = StringTools.replace(dir, "\\", "/");
		while (StringTools.endsWith(normalized, "/"))
			normalized = normalized.substr(0, normalized.length - 1);
		if (normalized != "" && bases.indexOf(normalized) < 0)
			bases.push(normalized);
	}

	/** 定位工程的 source 根（含 system/reflection/DefinitionRegistry.hx 的那个 classpath 项）。 */
	static function findSourceRoot():Null<String> {
		for (cp in Context.getClassPath()) {
			var normalized = StringTools.replace(cp, "\\", "/");
			if (StringTools.endsWith(normalized, "/"))
				normalized = normalized.substr(0, normalized.length - 1);
			if (FileSystem.exists(normalized + "/system/reflection/DefinitionRegistry.hx")
				&& FileSystem.exists(normalized + "/Main.hx"))
				return normalized;
		}
		return null;
	}

	/** 取第一个带 version 属性的 `<app ...>` 元素（= 应用定义那一行；preloader 那条没有 version）。 */
	static function parseAppVersion(text:String):Null<String> {
		var re = ~/version\s*=\s*"([^"]*)"/;
		for (line in text.split("\n")) {
			if (line.indexOf("<app") < 0)
				continue;
			if (re.match(line))
				return re.matched(1);
		}
		return null;
	}
	#end
}
