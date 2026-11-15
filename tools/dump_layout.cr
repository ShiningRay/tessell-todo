require "../src/tessell_todo/app"

def dump(c : Tessell::Kit::Component, depth = 0)
  b = c.bounds
  puts "#{"  " * depth}#{c.class.name.split("::").last} key=#{c.key.local} bounds=(#{b.origin.x.round(1)},#{b.origin.y.round(1)},#{b.size.width.round(1)},#{b.size.height.round(1)})"
  if c.is_a?(Tessell::Kit::Container)
    c.children.each { |ch| dump(ch, depth + 1) }
  elsif c.is_a?(Tessell::Kit::ScrollView)
    dump(c.child, depth + 1)
  elsif c.responds_to?(:checkbox)
    # skip internal composition detail for brevity
  end
end

app = TessellTodo::TodoApp.new("")
root = app.build_root(Tessell::Kit::StubTextMetrics.new, Tessell::Kit::MemoryClipboard.new)
root.layout(720.0_f32, 560.0_f32)
root.build

app.store.add("Buy milk")
app.store.add("Write code")
app.store.add("Ship it")
app.store.items[1].done = true
app.on_frame
root.layout(720.0_f32, 560.0_f32)
root.build

dump(root.content)
