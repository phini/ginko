using Gtk;

namespace Ginko {

class MainWindow : Window {
    private NavigatorController navigator_controller;
    
    private VBox main_vbox;
    private ApplicationContext app_context;

    public MainWindow(ApplicationContext app_context) {
        this.app_context = app_context;
    
        title = "Ginko File Manager";
        set_default_size (800, 600);
        
        main_vbox = new VBox(false, 0);
        
        build_panels();
        build_function_buttons();
        
        add(main_vbox);
    }
    
    private void build_panels() {
        navigator_controller = new NavigatorController();
        var view = navigator_controller.view;
        var widget = view.widget;
        
        main_vbox.pack_start(widget);
    }
    
    private void build_function_buttons() {
        var hbox = new HBox(true, 0);
        
        var button_view = new Button.with_label("F3 View");
        hbox.pack_start(button_view);
        
        var button_edit = new Button.with_label("F4 Edit");
        hbox.pack_start(button_edit);
        
        var button_copy = new Button.with_label("F5 Copy");
        hbox.pack_start(button_copy);
        
        var button_move = new Button.with_label("F6 Move");
        hbox.pack_start(button_move);
        
        var button_new = new Button.with_label("F7 New Folder");
        hbox.pack_start(button_new);
        
        var button_del = new Button.with_label("F8 Delete");
        hbox.pack_start(button_del);
        
        var button_terminal = new Button.with_label("F9 Terminal");
        hbox.pack_start(button_terminal);
        
        var button_exit = new Button.with_label("F10 Exit");
        hbox.pack_start(button_exit);
        
        main_vbox.pack_start(hbox, false);
    }
    
    public void register_action_accelerators() {
        var accel_group = new AccelGroup();
        
        foreach (var action in app_context.actions) {
            var accel = action.accelerator;
            
            var action_clos = action; // FIXME: Vala bug, without this null pointer will occur
                                      //*wait for https://bugzilla.gnome.org/show_bug.cgi?id=599133
            accel_group.connect(accel.keyval, accel.modifier_type, 0, () =>
                {action_clos.execute(navigator_controller.create_action_context()); return true;}
            );
        }
        
        add_accel_group(accel_group);
    }
}

} // namespace
