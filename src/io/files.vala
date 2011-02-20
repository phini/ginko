using Gtk;
using Gdk;

namespace Ginko.IO {
    
public class Files {
    
    /** Calculates used space of file/directory with contents in bytes */
    // TODO: add cancellation
    public static uint64 calculate_space_recurse(File p_file, bool p_follow_symlinks) {
        var scanner = new TreeScanner();
        scanner.m_follow_symlinks = p_follow_symlinks;
        scanner.add_attribute(FILE_ATTRIBUTE_STANDARD_SIZE);
        
        uint64 total = 0;
        scanner.scan(p_file, (file, fileinfo) => {
                total += fileinfo.get_size();
                return true;
        });
        
        return total;
    }
    
    public static Pixbuf find_icon_for_file(File file, IconTheme theme, int size=64) throws Error {
        var info = file.query_info(FILE_ATTRIBUTE_STANDARD_ICON, 0, null);
        
        var icon = (ThemedIcon) info.get_icon();
        var icon_names = icon.get_names();
        
        var icon_info = theme.choose_icon(icon_names, size, 0);
        if (icon_info != null) {
            return icon_info.load_icon();
        }
        
        return null;
    }
    
    public static bool is_directory(File p_file, bool p_follow_symlinks) {
        var type = p_file.query_file_type(
            p_follow_symlinks ? FileQueryInfoFlags.NONE : FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
        return type == FileType.DIRECTORY;
    }
    
    public static string query_content_type(File file) {
        var info = file.query_info(FILE_ATTRIBUTE_STANDARD_CONTENT_TYPE, 0, null);
        return info.get_content_type();
    }
    
    public static uint64 query_size(File file) {
        var info = file.query_info(FILE_ATTRIBUTE_STANDARD_SIZE, 0, null);
        return info.get_size();
    }
    
    public static TimeVal query_modification_time(File file) {
        TimeVal time;
        
        var info = file.query_info(FILE_ATTRIBUTE_TIME_MODIFIED, 0, null);
        info.get_modification_time(out time);
        
        return time;
    }
    
    /**
     * Rebases file so its old_base is beign replaced by new_base.
     *
     * Example input:
     * file: /home/stranger/docs/file
     * old_base: /home/stranger
     * new_base: /root
     *
     * return value: /root/docs/file
     */
    public static File rebase(File file, File old_base, File new_base) {
        List<string> stack = new List<string>();
        stack.append(file.get_basename());
        File tmpfile = file;
        
        // build stack until found base for file
        while (true) {
            if (!tmpfile.has_parent(null)) {
                error("rebase of '%s' with old_base='%s' and new_base='%s' failed",
                    file.get_path(), old_base.get_path(), new_base.get_path());
            } 
            
            var parent = tmpfile.get_parent();
            
            if (parent.get_path() == old_base.get_path()) {
                break;
            } else {
                tmpfile = parent;
                stack.prepend(tmpfile.get_basename());
            }
        }
        
        // use stack to build new file
        tmpfile = new_base;
        foreach (var el in stack) {
            tmpfile = tmpfile.get_child(el);
        }
        
        return tmpfile;
    }
}

} // namespace
