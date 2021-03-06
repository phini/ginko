using Gtk;
using Ginko.IO;
using Ginko.Util;
using Ginko.Dialogs;
using Ginko.Operations;


namespace Ginko.Actions {

class CopyFileAction : GLib.Object {
    
    private ActionContext m_context;
    private CopyFileConfig m_config;
    private int m_config_return_code;
    
    private bool m_progress_dialog_visible;
    private ProgressDialog m_progress_dialog;
    
    private uint64 m_bytes_processed;
    private uint64 m_bytes_total;
    
    private CopyFileOperation m_copy_op;
    uint64 m_bytes_processed_before;
    
    private bool m_overwrite_all;
    private bool m_skip_all;
    
    private enum FileAction {
        NONE,
        TRY_AGAIN,
        SUCCEED,
        SKIP,
        CANCEL,
        ERROR
    }
    
    private FileAction m_file_action; 
    
    public void execute(ActionContext p_context) {
        if (!verify(p_context)) {
            return;
        }
        
        m_context = p_context;
        
        m_progress_dialog = new ProgressDialog(m_context);
        m_progress_dialog.set_title("Copy operation");
        
        m_progress_dialog.cancel_button_pressed.connect(() => m_copy_op.cancel());
        
        prompt_configuration();
        if (configuration_done()) {
            execute_async();
        }
    }
    
    private bool verify(ActionContext context) {
        if (context.source_selected_files.length == 0) {
            Messages.show_error(context, "Nothing to copy", "You must select at least one file.");
            return false;
        }
        
        return true;
    }
    
    private void prompt_configuration() {
        var config_dialog = new CopyFileConfigureDialog(m_context);
        m_config_return_code = config_dialog.run();
        config_dialog.close();
        
        m_config = config_dialog.get_config();
    }
    
    private bool configuration_done() {
        return m_config_return_code == ResponseType.OK;
    }
    
    private void execute_async() {
        var async_task = new AsyncTask();
        async_task.run(execute_async_t, this);
    }
    
    // executed in new thread
    private void execute_async_t(AsyncTask p_async_task) {
        show_progress_preparing_t();
        
        // calculate used space first
        foreach (var infile in m_context.source_selected_files) {
            m_bytes_total += Files.calculate_space_recurse(infile, m_config.follow_symlinks);
        }
        
        var scanner = new TreeScanner();
        scanner.m_follow_symlinks = m_config.follow_symlinks;
        
        if (Config.debug) {
            scanner.add_attribute(FILE_ATTRIBUTE_STANDARD_SIZE);
        }
        
        foreach (var infile in m_context.source_selected_files) {
            scanner.scan(infile, copy_t);
            
            // stop scanning if cancelled any operation
            if (m_file_action == FileAction.CANCEL) {
                break;
            }
        }
        
        if (m_file_action == FileAction.SUCCEED) {
            show_progress_finished_t();
            GuiExecutor.run(() => m_progress_dialog.close());
        } else if (m_file_action == FileAction.CANCEL) {
            show_progress_canceled_t();
        } else {
            show_progress_failed_t();
        }
        
        var dircontroller = m_context.unactive_controller;
        GuiExecutor.run(() => dircontroller.refresh());
    }
    
    private bool copy_t(File p_src_file, FileInfo p_src_fileinfo) {
        var src_filename = p_src_fileinfo.get_name();
        show_progress_copying_t(src_filename);

        var dst_file = Files.rebase(p_src_file,
            m_context.source_dir, m_context.destination_dir);
        
        create_copy_file_operation_t(p_src_file, dst_file);
        
        progress_log_details_t(
                "%s => %s".printf(
                    m_copy_op.m_source.get_path(),
                    m_copy_op.m_destination.get_path()
                ));
        
            
        m_file_action = FileAction.NONE;
        
        do {
            if (Files.is_directory(p_src_file, m_config.follow_symlinks)) {
                try {
                    dst_file.make_directory();
                    m_file_action = FileAction.SUCCEED;
                } catch (IOError e) {
                    Messages.show_error_t(m_context, "Error", e.message);
                    m_file_action = FileAction.CANCEL;
                }
            } else {
                try {
                    m_copy_op.execute();
                    m_file_action = FileAction.SUCCEED;
                } catch (IOError e) {
                    if (e is IOError.CANCELLED) {
                        m_file_action = FileAction.CANCEL;
                    } else if (e is IOError.NOT_FOUND) {
                        debug("file not found");
                        Messages.show_error_t(m_context,
                            "Source not found!",
                            "Lost track of source file '%s'. I saw it! I swear!".printf(
                                src_filename));
                        m_file_action = FileAction.SKIP;
                    } else if (e is IOError.EXISTS) {
                        if (m_skip_all) {
                            m_file_action = FileAction.SKIP;
                        } else if (m_overwrite_all) {
                            m_copy_op.m_overwrite = true;
                            m_file_action = FileAction.TRY_AGAIN;
                        } else {
                            prompt_overwrite_t();
                        }
                    } else if (e is IOError.IS_DIRECTORY) {
                        // TODO: tried to overwrite a file over directory
                        Messages.show_error_t(m_context, "Error", e.message);
                        m_file_action = FileAction.CANCEL;
                    } else if (e is IOError.WOULD_MERGE) {
                        // TODO: tried to overwrite a directory with a directory
                        Messages.show_error_t(m_context, "Error", e.message);
                        m_file_action = FileAction.CANCEL;
                    } else if (e is IOError.WOULD_RECURSE) {
                        // TODO: source is directory and target doesn't exists
                        // or m_overwrite = true and target is a file
                        Messages.show_error_t(m_context, "Error", e.message);
                        m_file_action = FileAction.CANCEL;
                    } else if (e is IOError.PERMISSION_DENIED) {
                        Messages.show_error_t(m_context, "Error",
                            "Cannot copy %s to %s: permission denied".printf(
                                m_copy_op.m_source.get_path(),
                                m_copy_op.m_destination.get_path()));
                        m_file_action = FileAction.CANCEL;
                    } else {
                        Messages.show_error_t(m_context, "Error", e.message);
                        m_file_action = FileAction.CANCEL;
                    }
                }
            }
            
            if (m_file_action == FileAction.CANCEL) {
                return false;
            }
            
            if (Config.debug) {
                Posix.sleep(1);
            }
            
        } while (m_file_action == FileAction.TRY_AGAIN); // retry until action is done
        
        assert(m_file_action != FileAction.NONE);
        
        return true;
    }
    
    private void show_progress_preparing_t() {
        GuiExecutor.run(() => {
                m_progress_dialog.set_status_text_1("Preparing...");
                
                if (!m_progress_dialog_visible) {
                    m_progress_dialog.show();
                    m_progress_dialog_visible = true;
                }
        });
    }
    
    private void show_progress_copying_t(string p_filename) {
        double value = m_bytes_processed / (double) m_bytes_total;
        
        GuiExecutor.run(() => {
                m_progress_dialog.set_status_text_1("Copying %s".printf(p_filename));
                m_progress_dialog.set_progress(value);
        });
    }
    
    private void show_progress_finished_t() {
        GuiExecutor.run(() => {
                m_progress_dialog.set_status_text_1("Operation finished!");
                m_progress_dialog.set_progress(1);
                m_progress_dialog.set_done();
        });
    }
    
    private void show_progress_canceled_t() {
        GuiExecutor.run(() => {
                m_progress_dialog.set_status_text_1("Operation canceled!");
                m_progress_dialog.set_done();
        });
    }
    
    private void show_progress_failed_t() {
        GuiExecutor.run(() => {
                m_progress_dialog.set_status_text_1("Operation failed!");
                m_progress_dialog.set_done();
        });
    }
    
    private void progress_log_details_t(string p_text) {
        GuiExecutor.run(() => {
                m_progress_dialog.log_details(p_text);
        });
    }
    
    private void create_copy_file_operation_t(File p_source, File p_dest) {
        m_copy_op = new CopyFileOperation();
        m_copy_op.m_source = p_source;
        m_copy_op.m_destination = p_dest;
        m_bytes_processed_before = m_bytes_processed;
        
        m_copy_op.set_progress_callback((current, total) => {
            m_bytes_processed = m_bytes_processed_before + current;
            show_progress_copying_t(p_source.get_basename());
        });
    }
    
    private void prompt_overwrite_t() {
        GuiExecutor.run_and_wait(() => {
                var dialog = new OverwriteDialog(m_context,
                    m_copy_op.m_source, m_copy_op.m_destination);
                var response = dialog.run();
                dialog.close();
                
                switch (response) {
                    case OverwriteDialog.RESPONSE_CANCEL:
                        m_file_action = FileAction.CANCEL;
                        break;
                    case OverwriteDialog.RESPONSE_RENAME:
                        if (prompt_rename()) {
                            m_file_action = FileAction.TRY_AGAIN;
                        } else {
                            m_file_action = FileAction.CANCEL;
                        }
                        break;
                    case OverwriteDialog.RESPONSE_OVERWRITE:
                        m_copy_op.m_overwrite = true;
                        m_overwrite_all = dialog.is_apply_to_all();
                        m_file_action = FileAction.TRY_AGAIN;
                        break;
                    case OverwriteDialog.RESPONSE_SKIP:
                        m_file_action = FileAction.SKIP;
                        m_skip_all = dialog.is_apply_to_all();
                        break;
                    case ResponseType.DELETE_EVENT:
                        m_file_action = FileAction.CANCEL;
                        break;
                    default:
                        error("unknown response: %d", response);
                }
                
        });
    }
    
    private bool prompt_rename() {
        var basename = m_copy_op.m_destination.get_basename();
        var rename_dialog = new RenameDialog(m_context, basename);
        var response = rename_dialog.run();
        
        try {
            if (response == RenameDialog.RESPONSE_OK) {
                var new_filename = rename_dialog.get_filename();
                
                var parent = m_copy_op.m_destination.get_parent();
                m_copy_op.m_destination = parent.get_child(new_filename);
                
                return true;
            }
            
            return false;
        } finally {
            rename_dialog.close();
        }
    }
}

} // namespace
