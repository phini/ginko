using Ginko.IO;

namespace Ginko.Operations {

class CopyFileOperation : Operation {
    public File m_source;
    public File m_destination;
    
    public bool m_overwrite;
    public bool m_follow_symlinks = true;
    
    private Cancellable m_cancellable = new Cancellable();
    public FileProgressCallback m_progress_callback { get; set; }
    
    public uint64 get_cost() {
        return Files.query_size(m_source);
    }
    
    public void execute() throws IOError {
        m_source.copy(
            m_destination,
            gen_copy_flags(),
            m_cancellable,
            m_progress_callback
            );
    }
    
    public bool cancel() {
        m_cancellable.cancel();
        return m_cancellable.is_cancelled();
    }
    
    private FileCopyFlags gen_copy_flags() {
        FileCopyFlags flags = FileCopyFlags.NONE;
        if (m_overwrite) {
            flags |= FileCopyFlags.OVERWRITE;
        }
        
        if (!m_follow_symlinks) {
            flags |= FileCopyFlags.NOFOLLOW_SYMLINKS;
        }
        
        return flags;
    }
}

} // namespace