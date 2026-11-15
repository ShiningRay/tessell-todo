require "tessell/kit"
require "./store"

module TessellTodo
  # A single todo row: checkbox + title + delete button.
  class TodoRow < Tessell::Kit::Component
    getter item : TodoItem
    getter checkbox : Tessell::Kit::Checkbox
    getter title_text : Tessell::Kit::Text
    getter delete_btn : Tessell::Kit::Button

    @on_toggle : Proc(Int64, Nil)?
    @on_delete : Proc(Int64, Nil)?

    def initialize(@key : Tessell::UI::UiKey, @item : TodoItem,
                   on_toggle : Proc(Int64, Nil)? = nil,
                   on_delete : Proc(Int64, Nil)? = nil)
      super(@key)
      @on_toggle = on_toggle
      @on_delete = on_delete

      @checkbox = Tessell::Kit::Checkbox.new(
        @key.child(1_u64), "", @item.done, false,
        Tessell::Kit::ControlSize::Medium)
      @checkbox.on_change = ->(_checked : Bool) {
        @on_toggle.try(&.call(@item.id))
        nil
      }

      tone = @item.done ? Tessell::Kit::TextTone::Muted : Tessell::Kit::TextTone::Normal
      @title_text = Tessell::Kit::Text.new(
        @key.child(2_u64), @item.title, tone, Tessell::Kit::ControlSize::Medium)

      @delete_btn = Tessell::Kit::Button.new(
        @key.child(3_u64), "Delete", Tessell::Kit::Variant::Ghost,
        Tessell::Kit::ControlSize::Small)
      @delete_btn.on_click = -> {
        @on_delete.try(&.call(@item.id))
        nil
      }
    end

    def sync(item : TodoItem) : Nil
      @item = item
      @checkbox.checked = item.done
      @checkbox.indeterminate = false
      @title_text.content = item.title
      @title_text.tone = item.done ? Tessell::Kit::TextTone::Muted : Tessell::Kit::TextTone::Normal
    end

    def measure(ctx : Tessell::Kit::Context, constraints : Tessell::Constraints) : Tessell::Size
      cb = @checkbox.measure(ctx, constraints)
      del = @delete_btn.measure(ctx, constraints)
      max_w = constraints.max_width.infinite? ? 600.0_f32 : constraints.max_width
      title_w = Math.max(40.0_f32, max_w - cb.width - del.width - 24.0_f32)
      tt = @title_text.measure(ctx, Tessell::Constraints.new(0.0_f32, title_w, 0.0_f32, constraints.max_height))
      h = Math.max(cb.height, Math.max(tt.height, del.height)) + 12.0_f32
      constraints.constrain(Tessell::Size.new(max_w, h))
    end

    def arrange(ctx : Tessell::Kit::Context, bounds : Tessell::Rect) : Nil
      @bounds = bounds
      cb_size = @checkbox.measure(ctx, Tessell::Constraints.new(0.0_f32, bounds.size.width, 0.0_f32, bounds.size.height))
      del_size = @delete_btn.measure(ctx, Tessell::Constraints.new(0.0_f32, bounds.size.width, 0.0_f32, bounds.size.height))
      pad = 8.0_f32
      inner_h = bounds.size.height - pad * 2.0_f32

      cb_y = bounds.origin.y + (bounds.size.height - cb_size.height) / 2.0_f32
      cb_rect = Tessell::Rect.new(bounds.origin.x + pad, cb_y, cb_size.width, cb_size.height)
      @checkbox.arrange(ctx, cb_rect)

      del_y = bounds.origin.y + (bounds.size.height - del_size.height) / 2.0_f32
      del_x = bounds.max_x - pad - del_size.width
      del_rect = Tessell::Rect.new(del_x, del_y, del_size.width, del_size.height)
      @delete_btn.arrange(ctx, del_rect)

      title_x = cb_rect.max_x + 8.0_f32
      title_w = Math.max(10.0_f32, del_x - 8.0_f32 - title_x)
      tt_size = @title_text.measure(ctx, Tessell::Constraints.new(0.0_f32, title_w, 0.0_f32, inner_h))
      tt_y = bounds.origin.y + (bounds.size.height - tt_size.height) / 2.0_f32
      tt_rect = Tessell::Rect.new(title_x, tt_y, title_w, tt_size.height)
      @title_text.arrange(ctx, tt_rect)
    end

    def emit(b : Tessell::UI::Builder, ctx : Tessell::Kit::Context) : Nil
      return unless @visible
      b.group(@key, @bounds, a11y_role: Tessell::A11y::Role::Group,
              a11y_name: @item.title) do
        @checkbox.emit(b, ctx)
        @title_text.emit(b, ctx)
        @delete_btn.emit(b, ctx)
      end
    end

    def paint(p : Tessell::Kit::Painter, ctx : Tessell::Kit::Context) : Nil
      return unless @visible
      bg = @item.done ? ctx.theme.palette.surface_raised : ctx.theme.palette.surface
      p.fill_rect(@bounds, bg)
      p.line(@bounds.origin.x + 8.0_f32, @bounds.max_y - 1.0_f32,
             @bounds.max_x - 8.0_f32, @bounds.max_y - 1.0_f32,
             ctx.theme.palette.border, 1.0_f32)
      @checkbox.paint(p, ctx)
      @title_text.paint(p, ctx)
      @delete_btn.paint(p, ctx)
    end

    def collect_components(sink : Array(Tessell::Kit::Component)) : Nil
      sink << self
      @checkbox.collect_components(sink)
      @title_text.collect_components(sink)
      @delete_btn.collect_components(sink)
    end
  end

  class TodoApp
    getter store : Store
    getter root : Tessell::Kit::Root?
    getter input : Tessell::Kit::Input

    @add_button : Tessell::Kit::Button
    @all_button : Tessell::Kit::Button
    @active_button : Tessell::Kit::Button
    @completed_button : Tessell::Kit::Button
    @clear_button : Tessell::Kit::Button
    @toggle_all_button : Tessell::Kit::Button
    @list_column : Tessell::Kit::Column
    @scroll : Tessell::Kit::ScrollView
    @status_text : Tessell::Kit::Text
    @empty_text : Tessell::Kit::Text
    @rows : Hash(Int64, TodoRow)
    @last_signature : String

    def initialize(data_path : String = "todos.json")
      @store = Store.new(data_path)
      @root = nil
      @rows = {} of Int64 => TodoRow
      @last_signature = ""

      @input = Tessell::Kit::Input.new(
        Tessell::UI::UiKey.root.child(10_u64), "", "What needs to be done? (press Enter to add)", "New todo")
      @input.on_submit = ->(_text : String) { add_from_input; nil }

      @add_button = Tessell::Kit::Button.new(
        Tessell::UI::UiKey.root.child(11_u64), "Add", Tessell::Kit::Variant::Primary)
      @add_button.on_click = -> { add_from_input; nil }

      @all_button = Tessell::Kit::Button.new(
        Tessell::UI::UiKey.root.child(20_u64), "All", Tessell::Kit::Variant::Secondary,
        Tessell::Kit::ControlSize::Small)
      @all_button.on_click = -> { set_filter(Filter::All); nil }
      @active_button = Tessell::Kit::Button.new(
        Tessell::UI::UiKey.root.child(21_u64), "Active", Tessell::Kit::Variant::Secondary,
        Tessell::Kit::ControlSize::Small)
      @active_button.on_click = -> { set_filter(Filter::Active); nil }
      @completed_button = Tessell::Kit::Button.new(
        Tessell::UI::UiKey.root.child(22_u64), "Completed", Tessell::Kit::Variant::Secondary,
        Tessell::Kit::ControlSize::Small)
      @completed_button.on_click = -> { set_filter(Filter::Completed); nil }

      @clear_button = Tessell::Kit::Button.new(
        Tessell::UI::UiKey.root.child(23_u64), "Clear completed", Tessell::Kit::Variant::Ghost,
        Tessell::Kit::ControlSize::Small)
      @clear_button.on_click = -> { clear_completed; nil }

      @toggle_all_button = Tessell::Kit::Button.new(
        Tessell::UI::UiKey.root.child(24_u64), "Toggle all", Tessell::Kit::Variant::Ghost,
        Tessell::Kit::ControlSize::Small)
      @toggle_all_button.on_click = -> { toggle_all; nil }

      @status_text = Tessell::Kit::Text.new(
        Tessell::UI::UiKey.root.child(30_u64), "", Tessell::Kit::TextTone::Muted,
        Tessell::Kit::ControlSize::Small)

      @empty_text = Tessell::Kit::Text.new(
        Tessell::UI::UiKey.root.child(31_u64), "No todos yet. Add one above.",
        Tessell::Kit::TextTone::Muted, Tessell::Kit::ControlSize::Medium)

      @list_column = Tessell::Kit::Column.new(
        Tessell::UI::UiKey.root.child(40_u64),
        Tessell::Insets.all(4.0_f32), 4.0_f32,
        Tessell::Kit::Alignment::Stretch)

      @scroll = Tessell::Kit::ScrollView.new(
        Tessell::UI::UiKey.root.child(41_u64), @list_column,
        false, true)
      @scroll.preferred_height = 320.0_f32
    end

    def build_root(metrics : Tessell::Kit::TextMetrics,
                   clipboard : Tessell::Kit::Clipboard) : Tessell::Kit::Root
      @input.clipboard = clipboard

      main = Tessell::Kit::Column.new(
        Tessell::UI::UiKey.root.child(1_u64),
        Tessell::Insets.all(20.0_f32), 10.0_f32,
        Tessell::Kit::Alignment::Stretch)

      title = Tessell::Kit::Text.new(
        Tessell::UI::UiKey.root.child(2_u64), "Tessell Todo",
        Tessell::Kit::TextTone::Normal, Tessell::Kit::ControlSize::Large)
      subtitle = Tessell::Kit::Text.new(
        Tessell::UI::UiKey.root.child(3_u64),
        "A Todo List app built with Tessell Kit (Crystal). Type and press Enter to add.",
        Tessell::Kit::TextTone::Muted, Tessell::Kit::ControlSize::Small)

      actions_row = Tessell::Kit::Row.new(
        Tessell::UI::UiKey.root.child(5_u64),
        Tessell::Insets.new, 8.0_f32, Tessell::Kit::Alignment::Start)
      actions_row.add(@add_button)
      actions_row.add(@all_button)
      actions_row.add(@active_button)
      actions_row.add(@completed_button)
      actions_row.add(@toggle_all_button)
      actions_row.add(@clear_button)

      footer_row = Tessell::Kit::Row.new(
        Tessell::UI::UiKey.root.child(6_u64),
        Tessell::Insets.new, 8.0_f32, Tessell::Kit::Alignment::Start)
      footer_row.add(@status_text)

      main.add(title)
      main.add(subtitle)
      main.add(@input)
      main.add(actions_row)
      main.add(@scroll)
      main.add(footer_row)

      @root = Tessell::Kit::Root.new(main, Tessell::Kit::Theme.light, metrics,
        Tessell::Rect.new(0.0_f32, 0.0_f32, 720.0_f32, 560.0_f32))
      rebuild_list
      update_filter_buttons
      update_status
      @last_signature = signature
      @root.not_nil!
    end

    def on_frame : Nil
      sig = signature
      return if sig == @last_signature
      rebuild_list
      update_status
      update_filter_buttons
      @last_signature = signature
    end

    private def signature : String
      ids = @store.visible_items.map { |it| "#{it.id}:#{it.done ? 1 : 0}:#{it.title}" }.join("|")
      "#{@store.filter.value}:#{@store.items.size}:#{@store.remaining_count}:#{ids}"
    end

    private def add_from_input : Nil
      title = @input.text
      return unless @store.add(title)
      @input.set_text("")
      @last_signature = ""
    end

    private def set_filter(filter : Filter) : Nil
      @store.filter = filter
      @last_signature = ""
    end

    private def clear_completed : Nil
      @store.clear_completed
      @last_signature = ""
    end

    private def toggle_all : Nil
      @store.set_all(!@store.all_done?)
      @last_signature = ""
    end

    private def toggle_item(id : Int64) : Nil
      @store.toggle(id)
      @last_signature = ""
    end

    private def delete_item(id : Int64) : Nil
      @store.remove(id)
      @last_signature = ""
    end

    private def rebuild_list : Nil
      existing = @list_column.children.dup
      existing.each { |child| @list_column.remove(child) }

      visible = @store.visible_items
      if visible.empty?
        @rows.clear
        msg = case @store.filter
              when Filter::Active    then "No active todos."
              when Filter::Completed then "No completed todos."
              else                        "No todos yet. Add one above."
              end
        @empty_text.content = msg
        @list_column.add(@empty_text)
        return
      end

      kept = {} of Int64 => TodoRow
      visible.each do |item|
        row = if old = @rows[item.id]?
                old.sync(item)
                old
              else
                TodoRow.new(
                  Tessell::UI::UiKey.root.child(1000_u64 + item.id.to_u64),
                  item,
                  ->(id : Int64) { toggle_item(id); nil },
                  ->(id : Int64) { delete_item(id); nil }
                )
              end
        kept[item.id] = row
        @list_column.add(row)
      end
      @rows = kept
    end

    private def update_status : Nil
      remaining = @store.remaining_count
      total = @store.items.size
      word = remaining == 1 ? "item" : "items"
      @status_text.content = "#{remaining} #{word} left (#{total} total)"
    end

    private def update_filter_buttons : Nil
      @all_button.variant = @store.filter == Filter::All ? Tessell::Kit::Variant::Primary : Tessell::Kit::Variant::Secondary
      @active_button.variant = @store.filter == Filter::Active ? Tessell::Kit::Variant::Primary : Tessell::Kit::Variant::Secondary
      @completed_button.variant = @store.filter == Filter::Completed ? Tessell::Kit::Variant::Primary : Tessell::Kit::Variant::Secondary
      @clear_button.enabled = @store.completed_count > 0
      @toggle_all_button.enabled = !@store.items.empty?
    end
  end
end
