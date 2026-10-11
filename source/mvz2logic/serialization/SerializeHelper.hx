// Ported from: Assets/Scripts/Logic/Serialization/SerializeHelper.cs
// PORT-NOTE: 原文件完全依赖 MongoDB.Bson 的序列化框架（BsonSerializer / BsonClassMap / ConventionRegistry /
// IBsonSerializer / IBsonReader），Haxe + lime/openfl 没有对应库。按 PORTING.md 的“等价实现 + PORT-NOTE”处理：
//   * init() 保留原有的注册次序与类型清单（以 C# 全限定类型名字符串登记，避免依赖不存在的 BSON 序列化器类）；
//   * 文件读写（Write/Read/压缩读写）用 sys.io.File + haxe.io + 手工 gzip 容器等价实现；
//   * ToBson/FromBson 用 haxe.Json 等价实现（不再是 BSON，字段映射规则见 CustomClassMapConvention 的说明）；
//   * BSON 专属的 API（JsonWriterSettings、IBsonReader、BsonClassMap 反射映射）无法表达，逐条加 TODO-PORT。
package mvz2logic.serialization;

import haxe.io.Bytes;
import haxe.io.BytesOutput;
import sys.io.File;
import unity.Debug;

class SerializeHelper
{
	public static function init(defaultNsp:String):Void
	{
		if (isInited)
			return;
		// 序列化器（C# 均为 Tools / PVZEngine 提供的 IBsonSerializer 实现）
		// TODO-PORT: Haxe 无 BSON 序列化器，改为按类型名字符串登记，供等价实现（Json 转换）使用。
		RegisterSerializerType("Tools.Unity.Serializers.Vector2Serializer");
		RegisterSerializerType("Tools.Unity.Serializers.Vector3Serializer");
		RegisterSerializerType("Tools.Unity.Serializers.Vector4Serializer");
		RegisterSerializerType("Tools.Unity.Serializers.Vector2IntSerializer");
		RegisterSerializerType("Tools.Unity.Serializers.ColorSerializer");
		RegisterSerializerType("Tools.RNG.RandomGeneratorSerializer");
		RegisterSerializerType("MVZ2Logic.Serialization.SpriteReferenceSerializer");
		RegisterSerializerType("PVZEngine.NamespaceIDSerializer");
		RegisterSerializerType("PVZEngine.Level.PropertyBlockSerializer");

		// Tools
		RegisterClassByName("Tools.FrameTimer");
		RegisterClassByName("Tools.RandomGenerator");

		// PVZEngine.Base
		RegisterClassByName("PVZEngine.NamespaceID");
		RegisterClassByName("PVZEngine.SerializablePropertyDictionary");
		RegisterClassByName("PVZEngine.SerializablePropertyDictionaryString");

		// PVZEngine.Level
		RegisterClassByName("PVZEngine.Entities.EntitySourceReference");
		RegisterClassByName("MVZ2Logic.Artifacts.ArtifactSourceReference");
		RegisterClassByName("PVZEngine.Entities.EntityID");
		RegisterClassByName("PVZEngine.Entities.Hitboxes.SerializableEntityCollider");
		RegisterClassByName("PVZEngine.Collisions.Level.SerializableBuiltinCollisionSystem");
		RegisterClassByName("PVZEngine.Collisions.Level.SerializableBuiltinCollisionSystemEntity");

		RegisterClassByName("PVZEngine.Buffs.BuffReference");
		RegisterClassByName("PVZEngine.Buffs.BuffReferenceEntity");
		RegisterClassByName("PVZEngine.Buffs.BuffReferenceArmor");
		RegisterClassByName("PVZEngine.Buffs.BuffReferenceLevel");
		RegisterClassByName("PVZEngine.Buffs.BuffReferenceClassicSeedPack");
		RegisterClassByName("PVZEngine.Buffs.BuffReferenceConveyorSeedPack");
		RegisterClassByName("PVZEngine.Buffs.BuffReferenceLawnGrid");

		RegisterClassByName("PVZEngine.Entities.SerializableEntity");
		RegisterClassByName("PVZEngine.Armors.SerializableArmor");
		RegisterClassByName("PVZEngine.Buffs.SerializableBuff");
		RegisterClassByName("PVZEngine.Buffs.SerializableBuffList");
		RegisterClassByName("PVZEngine.Grids.SerializableGrid");
		RegisterClassByName("PVZEngine.Level.SerializableLevel");
		RegisterClassByName("PVZEngine.Level.SerializableDelayedEnergy");
		RegisterClassByName("PVZEngine.Level.SerializableLevelOption");
		RegisterClassByName("PVZEngine.SeedPacks.SerializableClassicSeedPack");
		RegisterClassByName("PVZEngine.SeedPacks.SerializableConveyorSeedPack");
		RegisterClassByName("PVZEngine.Level.SerializableConveyorSeedSpendRecords");
		RegisterClassByName("PVZEngine.Level.SerializableConveyorSeedSendRecordEntry");


		RegisterClassByName("PVZEngine.Damages.DamageResultValues");

		RegisterClassByName("PVZEngine.Damages.SerializableDeathInfo");
		RegisterClassByName("PVZEngine.Damages.SerializableDamageResult");
		RegisterClassByName("PVZEngine.Damages.SerializableArmorDamageResult");
		RegisterClassByName("PVZEngine.Damages.SerializableBodyDamageResult");
		RegisterClassByName("PVZEngine.Entities.SerializableEntitySourceReference");
		RegisterClassByName("MVZ2Logic.Artifacts.SerializableArtifactSourceReference");
		RegisterClassByName("PVZEngine.Entities.SerializableGridSourceReference");


		// MVZ2.Logic
		RegisterClassByName("MVZ2Logic.ShakeInt");
		RegisterClassByName("MVZ2Logic.ShakeFloat");
		RegisterClassByName("MVZ2Logic.Saves.SerializableModSaveData");
		RegisterClassByName("MVZ2Logic.Saves.SerializableUserStats");
		RegisterClassByName("MVZ2Logic.Saves.SerializableUserStatCategory");
		RegisterClassByName("MVZ2Logic.Saves.SerializableUserStatEntry");
		RegisterClassByName("MVZ2Logic.Saves.SerializableEndlessRecord");
		RegisterClassByName("MVZ2Logic.Saves.SerializableLevelDifficultyRecord");

		isInited = true;
	}
	public static function IsGZipCompressed(filePath:String):Bool
	{
		var gzipFirstByte = 0x1F;
		var gzipSecondByte = 0x8B;
		var deflateMethod = 0x08;

		try
		{
			// C#: using var file = File.OpenRead(filePath); if (file.Length < 3) return false;
			if (sys.FileSystem.stat(filePath).size < 3) return false; // 文件太小

			var file = File.read(filePath);
			var header = Bytes.alloc(3);
			var bytesRead = file.readBytes(header, 0, 3);
			file.close();

			return bytesRead == 3 &&
				   header.get(0) == gzipFirstByte &&
				   header.get(1) == gzipSecondByte &&
				   header.get(2) == deflateMethod;
		}
		catch (e:Dynamic)
		{
			return false; // 文件访问错误
		}
	}
	// PORT-NOTE: 用 raw DEFLATE（windowBits = -15）手工拼装/拆解 gzip 容器。
	// 原因：C# 用 GZipStream（gzip 容器），而 Haxe 的 haxe.zip.Compress/Uncompress 默认输出/输入
	// zlib 容器（78 9C / 78 DA 开头）。旧实现直接写 zlib，读端却靠 IsGZipCompressed 的 gzip 魔数判定，
	// 于是 ReadStringFile 误走明文分支，把 zlib 头当成文本 → "Invalid char 120 at position 0"。
	private static inline var GZIP_HEADER_SIZE = 10;
	private static inline var GZIP_TRAILER_SIZE = 8;
	private static inline var RAW_DEFLATE_WINDOW_BITS = -15;
	private static function DeflateRaw(data:Bytes):Bytes
	{
		var zlib = haxe.zip.Compress.run(data, 9);
		// 去掉 2 字节 zlib 头与 4 字节 adler32 尾，只留 raw deflate 负载。
		return zlib.sub(2, zlib.length - 6);
	}
	private static function InflateRaw(payload:Bytes):Bytes
	{
		var uncompress = new haxe.zip.Uncompress(RAW_DEFLATE_WINDOW_BITS);
		uncompress.setFlushMode(haxe.zip.FlushMode.SYNC);
		var buffer = Bytes.alloc(1 << 16);
		var output = new haxe.io.BytesBuffer();
		var position = 0;
		while (true)
		{
			var result = uncompress.execute(payload, position, buffer, 0);
			output.addBytes(buffer, 0, result.write);
			position += result.read;
			if (result.done) break;
			if (result.read == 0 && result.write == 0) break; // 防御：负载截断时避免死循环
		}
		uncompress.close();
		return output.getBytes();
	}
	// PORT-NOTE: 等价 C# GZipStream 的 gzip 容器：10 字节固定头 + raw deflate + CRC32 + ISIZE。
	// 非 private：同文件的 GZipWriteStream 需要调用（Haxe 同文件不同类仍受 private 约束）。
	public static function EncodeGZip(data:Bytes):Bytes
	{
		var deflated = DeflateRaw(data);
		var output = new BytesOutput();
		output.writeByte(0x1F); // ID1
		output.writeByte(0x8B); // ID2
		output.writeByte(0x08); // CM = deflate
		output.writeByte(0x00); // FLG
		output.writeInt32(0);   // MTIME（C# GZipStream 同样写 0）
		output.writeByte(0x00); // XFL
		output.writeByte(0xFF); // OS = unknown
		output.writeBytes(deflated, 0, deflated.length);
		var crc = haxe.crypto.Crc32.make(data);
		output.writeInt32(crc);
		output.writeInt32(data.length);
		return output.getBytes();
	}
	// PORT-NOTE: 读取端兼容三种来源：gzip（C#/本实现）、zlib（旧 Haxe 实现写出的存档）、裸 DEFLATE。
	private static function DecodeCompressed(bytes:Bytes):Bytes
	{
		if (bytes.length >= GZIP_HEADER_SIZE + GZIP_TRAILER_SIZE &&
			bytes.get(0) == 0x1F && bytes.get(1) == 0x8B && bytes.get(2) == 0x08)
		{
			return InflateRaw(bytes.sub(GZIP_HEADER_SIZE, bytes.length - GZIP_HEADER_SIZE - GZIP_TRAILER_SIZE));
		}
		// zlib 容器：CMF 低 4 位必须是 deflate(8)，且 (CMF*256+FLG) % 31 == 0。
		if (bytes.length >= 6 && (bytes.get(0) & 0x0F) == 0x08 && ((bytes.get(0) << 8) + bytes.get(1)) % 31 == 0)
		{
			return haxe.zip.Uncompress.run(bytes);
		}
		return InflateRaw(bytes);
	}
	public static function WriteCompressedStringFile(path:String, json:String):Void
	{
		try
		{
			// C#: using var stream = OpenCompressedWrite(path); using var textWriter = new StreamWriter(stream); textWriter.Write(json);
			File.saveBytes(path, EncodeGZip(Bytes.ofString(json)));
		}
		catch (e:Dynamic)
		{
			Debug.LogError('Failed to write compressed string to file ${path}: ${e}');
		}
	}
	// PORT-NOTE: C# 返回 Stream（GZipStream）；Haxe 改为返回系统 shim 的 Stream，
	// 内容在 Dispose/Flush 时才真正落盘（与 GZipStream 的缓冲写入语义一致）。
	public static function OpenCompressedWrite(path:String):system.io.Stream
	{
		return new GZipWriteStream(path);
	}
	public static function ReadCompressed(path:String):String
	{
		return DecodeCompressed(File.getBytes(path)).toString();
	}
	// PORT-NOTE: C# 返回 MemoryStream；Haxe 改为返回系统 shim 的 MemoryStream（可直接 Seek/ReadToEnd）。
	public static function OpenCompressedRead(path:String):system.io.MemoryStream
	{
		return new system.io.MemoryStream(DecodeCompressed(File.getBytes(path)));
	}
	public static function Write(path:String, json:String):Void
	{
		try
		{
			var output = File.write(path, false);
			output.writeString(json);
			output.close();
		}
		catch (e:Dynamic)
		{
			Debug.LogError('Failed to write string to file ${path}: ${e}');
		}
	}
	// PORT-NOTE: C# 返回 Stream；Haxe 改为返回系统 shim 的 Stream（内容在 Dispose/Flush 时落盘）。
	public static function OpenWrite(path:String):system.io.Stream
	{
		return new PlainWriteStream(path);
	}
	public static function Read(path:String):String
	{
		return File.getContent(path);
	}
	// PORT-NOTE: C# 返回 MemoryStream；Haxe 改为返回系统 shim 的 MemoryStream。
	public static function OpenRead(path:String):system.io.MemoryStream
	{
		return new system.io.MemoryStream(File.getBytes(path));
	}
	// PORT-NOTE: C# 扩展方法 ToBson 使用 MongoDB.Bson 的 ToJson；Haxe 用 haxe.Json 等价实现。
	// MVZ2-DEBUG-BSON: 降级计数（收尾时移除）。
	public static function ToBson(obj:Dynamic, readFriendly:Bool = false):String
	{
		// PORT-NOTE: haxe.Json 的 JsonPrinter 不认 cpp.Int64（Type.getClass 返回 null，
		// classString 里 getInstanceFields(null) 直接段错误）。存档结构
		// （SerializableModSaveData 的 stats / playTimeMilliseconds，C# 的 long）大量使用
		// Int64，序列化前统一深拷贝转成 Float（JSON 数字；毫秒/计数值远小于 2^53，无损）。
		// TODO-PORT: CustomClassMapConvention（只映射字段、忽略默认值）无法在 Haxe 中复现，
		// 序列化结果与 BSON 不同，字段/默认值处理规则见 CustomClassMapConvention。
		var converted = convertForJson(obj, 0);
		return haxe.Json.stringify(converted, readFriendly ? "  " : null);
	}
	public static function RegisterSerializer<T>(serializer:T):Void
	{
		// TODO-PORT: Haxe 无 BSON 序列化器注册机制，仅记录类型名。
		RegisterSerializerType(Type.getClassName(Type.getClass(serializer)));
	}
	public static function RegisterSerializerType(typeName:String):Void
	{
		if (!serializerTypes.contains(typeName))
			serializerTypes.push(typeName);
	}
	public static function RegisterClass<T>(type:Class<T>):Void
	{
		var typeName = Type.getClassName(type);
		if (!registeredClasses.contains(typeName))
			registeredClasses.push(typeName);
	}
	public static function RegisterClassByName(typeName:String):Void
	{
		if (!registeredClasses.contains(typeName))
			registeredClasses.push(typeName);
	}
	// C#: public static void RegisterClass(Type t)
	public static function RegisterClassByType(t:Class<Dynamic>):Void
	{
		RegisterClass(t);
	}
	public static var isInited(default, null):Bool = false;
	// TODO-PORT: C# 的 JsonWriterSettings readFriendlyWriterSettings = { Indent = true }，Haxe 无对应类型。
	public static var readFriendlyWriterSettings:Dynamic = { indent: true };
	static var serializerTypes:Array<String> = [];
	static var registeredClasses:Array<String> = [];
}

/// <summary>
/// 自定义类映射规则
/// 只映射字段，忽略属性
/// </summary>
// TODO-PORT: C# 实现 IClassMapConvention（BSON 类映射约定），使用反射遍历字段/属性；
// Haxe 无 BSON 与等价的类映射 API，此处仅保留类型与说明，实际映射由 haxe.Json 的默认行为承担。
class CustomClassMapConvention // C#: implements IClassMapConvention
{
	public function new()
	{
	}
	// C#: public string Name { get; } = "FieldOnlyClassMapConvention";
	public var Name:String = "FieldOnlyClassMapConvention";
	public function Apply(classMap:Dynamic):Void
	{
		// TODO-PORT: BsonClassMap 反射映射无法移植。
	}
}

// C#: public delegate void SerializableRegister<T>();
typedef SerializableRegister<T> = Void->Void;

// PORT-NOTE: C# 的 OpenWrite/OpenCompressedWrite 返回真正的 Stream（FileStream / GZipStream），
// 由 StreamWriter 写入、Dispose 时落盘。Haxe 侧用一个内存缓冲的 Stream 子类复刻该时序：
// 只有 Dispose/Flush 才把字节写到磁盘，避免写入方尚未写完就被截断。
class BufferedWriteStream extends system.io.Stream
{
	private var path:String;
	private var buffer:BytesOutput;
	private var flushed:Bool = false;

	public function new(path:String)
	{
		super();
		this.path = path;
		this.buffer = new BytesOutput();
	}
	override public function Write(source:Bytes, offset:Int, count:Int):Void
	{
		buffer.writeBytes(source, offset, count);
		Position += count;
		Length = Position;
	}
	// 子类覆写本方法决定落盘格式（明文 / gzip）。
	function encode(data:Bytes):Bytes return data;
	override public function Flush():Void
	{
		if (flushed) return;
		flushed = true;
		sys.io.File.saveBytes(path, encode(buffer.getBytes()));
	}
	override public function Close():Void Flush();
	override public function Dispose():Void Flush();
}
class PlainWriteStream extends BufferedWriteStream
{
	public function new(path:String)
	{
		super(path);
	}
}
class GZipWriteStream extends BufferedWriteStream
{
	public function new(path:String)
	{
		super(path);
	}
	override function encode(data:Bytes):Bytes return SerializeHelper.EncodeGZip(data);
}
