package system.io.compression;

import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import haxe.zip.Compress;
import haxe.zip.Entry;
import haxe.zip.Reader;
import haxe.zip.Writer;
import system.io.MemoryStream;
import system.io.Stream;

// Minimal System.IO.Compression.ZipArchive shim.
// PORT-NOTE: haxe.zip reads/writes whole archives instead of streaming; the shim keeps all
// entries in memory and writes the archive back when it is disposed.
class ZipArchive {
    public var Entries:Array<ZipArchiveEntry> = [];
    public var Mode(default, null):ZipArchiveMode;

    private var stream:Stream;
    private var loaded:Bool = false;

    public function new(?stream:Stream, ?mode:ZipArchiveMode) {
        this.stream = stream;
        this.Mode = mode != null ? mode : ZipArchiveMode.Read;
        // PORT-NOTE: 读/更新模式必须在构造时就把条目读进来：静态 Open/OpenRead 会调 load()，
        //   但直接 new ZipArchive(stream)（LanguageManager 的内置语言包 zip、SaveManager 的
        //   用户数据包导入都这么用）不会，Entries 会停在空数组，整个 zip 被当成空包。
        //   Create 模式下 load() 自行早退，不受影响。
        load();
    }

    public static function Open(stream:Stream, mode:ZipArchiveMode):ZipArchive {
        var archive = new ZipArchive(stream, mode);
        archive.load();
        return archive;
    }
    public static function OpenRead(stream:Stream):ZipArchive {
        return Open(stream, ZipArchiveMode.Read);
    }

    private function load():Void {
        if (loaded) return;
        loaded = true;
        if (stream == null || Mode == ZipArchiveMode.Create) return;
        var bytes = stream.ReadAll();
        if (bytes.length == 0) return;
        try {
            var entries = new Reader(new BytesInput(bytes)).read();
            for (entry in entries) {
                var data = entry.compressed ? Reader.unzip(entry) : entry.data;
                Entries.push(new ZipArchiveEntry(entry.fileName, data));
            }
        } catch (e:Dynamic) {
            // TODO-PORT: report corrupt archives through the game logger.
        }
    }

    public function GetEntry(name:String):ZipArchiveEntry {
        for (entry in Entries) {
            if (entry.FullName == name || entry.Name == name) return entry;
        }
        return null;
    }
    public function CreateEntry(name:String):ZipArchiveEntry {
        var entry = new ZipArchiveEntry(name, Bytes.alloc(0));
        Entries.push(entry);
        return entry;
    }
    public function Dispose():Void {
        if (stream != null && Mode != ZipArchiveMode.Read) {
            writeTo(stream);
        }
    }

    private function writeTo(target:Stream):Void {
        var list:List<haxe.zip.Entry> = new List();
        for (entry in Entries) {
            var data = entry.getBytes();
            var zipEntry:haxe.zip.Entry = {
                fileName: entry.FullName,
                fileSize: data.length,
                fileTime: Date.now(),
                compressed: false,
                dataSize: data.length,
                data: data,
                crc32: haxe.crypto.Crc32.make(data)
            };
            // PORT-NOTE: Haxe 4.3 的 haxe.zip.Compress.run 只接受 haxe.io.Bytes（返回压缩后的字节流），
            // 而 haxe.zip.Writer.write 直接写出 Entry.data。这里按 stored（compressed=false）方式写入。
            list.add(zipEntry);
        }
        var out = new BytesOutput();
        new Writer(out).write(list);
        var bytes = out.getBytes();
        target.Write(bytes, 0, bytes.length);
        target.Flush();
    }
}
