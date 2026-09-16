using System.IO;
using System.Text;

namespace MarkdownViewer;

internal static class LocalFiles
{
    internal const long MaximumDocumentBytes = 16 * 1024 * 1024;
    internal static bool IsMarkdown(string path) =>
        Path.GetExtension(path).Equals(".md", StringComparison.OrdinalIgnoreCase) ||
        Path.GetExtension(path).Equals(".markdown", StringComparison.OrdinalIgnoreCase);

    internal static string ValidateLocalPath(string path)
    {
        var full = Path.GetFullPath(path);
        if (full.StartsWith(@"\\", StringComparison.Ordinal) || full[2..].Contains(':'))
            throw new IOException("Choose a file on a local drive. Network and device paths are not supported.");
        var root = Path.GetPathRoot(full)!;
        if (new DriveInfo(root).DriveType == DriveType.Network)
            throw new IOException("Network drives are not supported. Copy the document to a local drive first.");
        // Reject junctions and symlinks, including any ancestor, before reading.
        var current = full;
        while (current.Length >= root.Length)
        {
            if ((File.GetAttributes(current) & FileAttributes.ReparsePoint) != 0)
                throw new IOException("Linked files and folders are not supported. Open the original local file.");
            var parent = Path.GetDirectoryName(current);
            if (string.IsNullOrEmpty(parent) || parent == current) break;
            current = parent;
        }
        return full;
    }

    internal static async Task<(string Path, string Text, long Size)> ReadMarkdownAsync(string path)
    {
        var full = ValidateLocalPath(path);
        if (!IsMarkdown(full)) throw new IOException("Please choose a .md or .markdown file.");
        await using var stream = new FileStream(full, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete,
            65536, FileOptions.Asynchronous | FileOptions.SequentialScan);
        var size = stream.Length;
        if (size > MaximumDocumentBytes) throw new IOException("This document is larger than the 16 MB reading limit.");
        // Bounded copy also protects against a file growing while it is being read.
        using var buffer = new MemoryStream();
        var chunk = new byte[65536];
        int count;
        while ((count = await stream.ReadAsync(chunk)) > 0)
        {
            if (buffer.Length + count > MaximumDocumentBytes) throw new IOException("This document exceeds the 16 MB reading limit.");
            buffer.Write(chunk, 0, count);
        }
        buffer.Position = 0;
        using var reader = new StreamReader(buffer, new UTF8Encoding(false, true), detectEncodingFromByteOrderMarks: true);
        return (full, await reader.ReadToEndAsync(), buffer.Length);
    }

    internal static string ResolveWithinDirectory(string directory, string relative)
    {
        if (string.IsNullOrWhiteSpace(relative) || Path.IsPathRooted(relative) || relative.Contains(':'))
            throw new IOException("Only relative paths inside the document folder are supported.");
        var root = Path.GetFullPath(directory).TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;
        var full = Path.GetFullPath(Path.Combine(root, relative));
        if (!full.StartsWith(root, StringComparison.OrdinalIgnoreCase))
            throw new IOException("This link points outside the document folder.");
        return ValidateLocalPath(full);
    }
}
