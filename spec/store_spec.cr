require "./spec_helper"

private def with_temp_store(&)
  path = File.join(Dir.tempdir, "tessell_todo_spec_#{Random.rand(1_000_000)}.json")
  begin
    yield TessellTodo::Store.new(path), path
  ensure
    File.delete(path) if File.exists?(path)
  end
end

describe TessellTodo::Store do
  it "adds trimmed todos and ignores blank input" do
    store = TessellTodo::Store.new
    store.add("   ").should be_nil
    store.add("").should be_nil
    item = store.add("  Buy milk  ")
    item.should_not be_nil
    item.not_nil!.title.should eq("Buy milk")
    item.not_nil!.done.should be_false
    store.items.size.should eq(1)
    store.remaining_count.should eq(1)
  end

  it "toggles, removes and clears completed items" do
    store = TessellTodo::Store.new
    a = store.add("A").not_nil!
    b = store.add("B").not_nil!
    store.toggle(a.id).should be_true
    store.toggle(999_i64).should be_false
    a.done.should be_true
    store.completed_count.should eq(1)
    store.remaining_count.should eq(1)

    store.clear_completed.should eq(1)
    store.items.map(&.id).should eq([b.id])

    store.remove(b.id).should be_true
    store.remove(b.id).should be_false
    store.items.should be_empty
  end

  it "filters visible items and can toggle all" do
    store = TessellTodo::Store.new
    a = store.add("A").not_nil!
    b = store.add("B").not_nil!
    store.toggle(a.id)

    store.filter = TessellTodo::Filter::All
    store.visible_items.size.should eq(2)

    store.filter = TessellTodo::Filter::Active
    store.visible_items.map(&.id).should eq([b.id])

    store.filter = TessellTodo::Filter::Completed
    store.visible_items.map(&.id).should eq([a.id])

    store.filter = TessellTodo::Filter::All
    store.set_all(true)
    store.all_done?.should be_true
    store.set_all(false)
    store.remaining_count.should eq(2)
  end

  it "persists and reloads items" do
    with_temp_store do |store, path|
      store.add("First")
      second = store.add("Second").not_nil!
      store.toggle(second.id)

      reloaded = TessellTodo::Store.new(path)
      reloaded.items.size.should eq(2)
      reloaded.items[0].title.should eq("First")
      reloaded.items[0].done.should be_false
      reloaded.items[1].title.should eq("Second")
      reloaded.items[1].done.should be_true

      added = reloaded.add("Third").not_nil!
      added.id.should be > second.id
    end
  end
end
