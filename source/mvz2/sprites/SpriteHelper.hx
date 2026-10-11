package mvz2.sprites;

import haxe.io.Bytes;
import system.io.File;
import system.io.FileStream;
import unity.Color32;
import unity.Texture2D;

// Ported from: Assets/Scripts/MVZ2/Sprites/SpriteHelper.cs
// PORT-NOTE: C# 扩展方法 → 静态普通方法；`ref Color32 pixel` 用 `{value:Color32}` 包装代替。
class SpriteHelper {
    private function new() {}

    public static function LoadTextureFromBytes(bytes:Bytes):Texture2D {
        var texture = new Texture2D(2, 2);
        texture.LoadImage(bytes);
        FixTransparency(texture);
        return texture;
    }
    public static function SaveToPath(texture:Texture2D, path:String):Void {
        var bytes = texture.EncodeToPNG();
        var stream = File.Open(path, "w");
        stream.Write(bytes, 0, bytes.length);
        stream.Flush();
        stream.Close();
    }
    /// <summary>
    /// 修复图片导入时白边问题
    /// </summary>
    public static function FixTransparency(texture:Texture2D):Void {
        var pixels = texture.GetPixels32();
        var w = texture.width;
        var h = texture.height;
        // PORT-NOTE(防段错误): 解码失败时 pixels 为空/null 或长度不足 w*h，
        // 直接按下标读会拿到 null 元素再取 .a 就是空指针解引用；Unity 语义上此时无事可做。
        if (pixels == null || pixels.length < w * h || w <= 0 || h <= 0)
            return;

        for (y in 0...h) {
            for (x in 0...w) {
                var idx = y * w + x;
                var pixel = pixels[idx];
                if (pixel.a == 0) {
                    var done = false;
                    if (!done && x > 0)
                        done = TryAdjacent(pixel, pixels[idx - 1]);        // Left pixel
                    if (!done && x > 0 && y < h - 1)
                        done = TryAdjacent(pixel, pixels[idx + w - 1]);    // Bottom Left pixel
                    if (!done && y < h - 1)
                        done = TryAdjacent(pixel, pixels[idx + w]);        // Bottom pixel
                    if (!done && x < w - 1 && y < h - 1)
                        done = TryAdjacent(pixel, pixels[idx + w + 1]);    // Bottom Right pixel
                    if (!done && x < w - 1)
                        done = TryAdjacent(pixel, pixels[idx + 1]);        // Right pixel
                    if (!done && x < w - 1 && y > 0)
                        done = TryAdjacent(pixel, pixels[idx - w + 1]);    // Top Right pixel
                    if (!done && y > 0)
                        done = TryAdjacent(pixel, pixels[idx - w]);        // Top pixel
                    if (!done && x > 0 && y > 0)
                        done = TryAdjacent(pixel, pixels[idx - w - 1]);    // Top Left pixel
                    pixels[idx] = pixel;
                }
            }
        }

        texture.SetPixels32(pixels);
        texture.Apply();
    }
    public static function GetPixels32Sub(allPixels:Array<Color32>, texWidth:Int, x:Int, y:Int, width:Int, height:Int, buffer:Array<Color32>):Void {
        for (row in 0...height) {
            var sourceIndex = (y + row) * texWidth + x;
            var targetIndex = row * width;
            // PORT-NOTE: C# `Array.Copy(allPixels, sourceIndex, buffer, targetIndex, width)`.
            for (i in 0...width) {
                buffer[targetIndex + i] = allPixels[sourceIndex + i];
            }
        }
    }
    public static function FlipColors(texture:Texture2D):Void {
        var colors = texture.GetPixels32();
        var width = texture.width;
        var height = texture.height;
        if (colors == null || colors.length < width * height || width <= 0 || height <= 0)
            return;

        var tempRow:Array<Color32> = [];
        tempRow.resize(width);
        for (y in 0...Std.int(height / 2)) {
            var topRowIndex = y * width;
            var bottomRowIndex = (height - y - 1) * width;

            // 交换顶部和底部的像素行
            for (i in 0...width) tempRow[i] = colors[topRowIndex + i];
            for (i in 0...width) colors[topRowIndex + i] = colors[bottomRowIndex + i];
            for (i in 0...width) colors[bottomRowIndex + i] = tempRow[i];
        }

        texture.SetPixels32(colors);
    }
    private static function TryAdjacent(pixel:Color32, adjacent:Color32):Bool {
        if (adjacent.a == 0)
            return false;

        pixel.r = adjacent.r;
        pixel.g = adjacent.g;
        pixel.b = adjacent.b;
        return true;
    }
}
