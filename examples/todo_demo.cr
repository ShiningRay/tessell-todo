# Tessell Todo List demo
#
# Run:
#   TESSELL_FONT=/usr/share/fonts/noto-cjk/NotoSansCJK-Regular.ttc crystal run examples/todo_demo.cr
# Optional: --frames=N --screenshot=docs/screenshot.png

require "../src/tessell_todo/app"
require "./lib/kit_sdl_host"

class TodoWindow < TessellKitSdl::KitDemoApp
  getter app : TessellTodo::TodoApp

  def initialize
    @app = TessellTodo::TodoApp.new(data_path)
  end

  def title : String
    "Tessell Todo"
  end

  def width : Int32
    720
  end

  def height : Int32
    560
  end

  def build_root(metrics : Tessell::Kit::TextMetrics,
                 clipboard : Tessell::Kit::Clipboard) : Tessell::Kit::Root
    @app.build_root(metrics, clipboard)
  end

  def on_root_ready(root : Tessell::Kit::Root) : Nil
    root.focus(@app.input)
  end

  def on_frame(root : Tessell::Kit::Root) : Nil
    @app.on_frame
  end

  private def data_path : String
    ENV["TESSELL_TODO_PATH"]? || File.join(Dir.current, "todos.json")
  end
end

TodoWindow.new.run(ARGV)
