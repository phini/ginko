using Gtk;

namespace Ginko.Dialogs {

public abstract class AbstractMessageDialog : AbstractDialog {
    
    private Image m_image_widget;
    private Label m_primary_label;
    public VBox m_content {get; private set;}
    private HBox m_hbox;
    
    public AbstractMessageDialog() {
        m_image_widget = new Image.from_stock(Stock.DIALOG_QUESTION, IconSize.DIALOG);
        m_image_widget.set_alignment(0.5f, 0);
        
        m_primary_label = new Label("");
        m_primary_label.set_selectable(true);
        m_primary_label.set_alignment(0, 0);
        set_primary_label_text("set by set_primary_label_text()");
        
        m_hbox = new HBox(false, Sizes.BOX_SPACING_NORMAL);
        vbox.pack_start(m_hbox);
        
        m_hbox.pack_start(m_image_widget);
        
        m_content = new VBox(false, Sizes.BOX_SPACING_NORMAL);
        m_hbox.pack_end(m_content);
        
        m_content.pack_start(m_primary_label);
        
        m_hbox.set_border_width(Sizes.BOX_BORDER_WIDTH_NORMAL);
    }
    
    public void set_primary_label_text(string p_text) {
        m_primary_label.set_markup(@"<big>$p_text</big>");
    }
    
    public void set_stock_icon(string p_stock_icon) {
        m_hbox.remove(m_image_widget);
        m_image_widget = new Image.from_stock(p_stock_icon, IconSize.DIALOG);
        m_hbox.pack_start(m_image_widget);
    }
}

}
