using System;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;

namespace RemnantOverseer.Utilities;

/// <summary>
/// macOS helper: finds the Remnant 2 save folder inside CrossOver bottles
/// (~/Library/Application Support/CrossOver/Bottles/*/drive_c/users/*/Saved Games/Remnant2/Steam/*/profile.sav).
/// </summary>
public static class CrossOverSaveLocator
{
    public static string BottlesRoot =>
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
            "Library", "Application Support", "CrossOver", "Bottles");

    public static bool IsMac => RuntimeInformation.IsOSPlatform(OSPlatform.OSX);

    public static string? FindSaveFolder()
    {
        if (!IsMac || !Directory.Exists(BottlesRoot)) return null;
        try
        {
            var candidates =
                from bottle in SafeDirs(BottlesRoot)
                from user in SafeDirs(Path.Combine(bottle, "drive_c", "users"))
                let r2 = Path.Combine(user, "Saved Games", "Remnant2")
                where Directory.Exists(r2)
                from store in SafeDirs(r2)                 // Steam / EOS / ...
                from idDir in SafeDirs(store).Append(store) // Steam/<id>/ or directly
                let profile = Path.Combine(idDir, "profile.sav")
                where File.Exists(profile)
                select new { Folder = idDir, Modified = File.GetLastWriteTimeUtc(profile) };

            return candidates.OrderByDescending(c => c.Modified).FirstOrDefault()?.Folder;
        }
        catch
        {
            return null;
        }
    }

    private static string[] SafeDirs(string path)
    {
        try { return Directory.Exists(path) ? Directory.GetDirectories(path) : []; }
        catch { return []; }
    }
}
