require "json"

module TessellTodo
  class TodoItem
    include JSON::Serializable

    property id : Int64
    property title : String
    property done : Bool

    def initialize(@id : Int64, @title : String, @done : Bool = false)
    end
  end

  enum Filter
    All
    Active
    Completed
  end

  # Pure todo list state + persistence. No UI dependencies, easy to spec.
  class Store
    getter items : Array(TodoItem)
    getter filter : Filter
    getter next_id : Int64

    @path : String

    def initialize(@path : String = "")
      @items = [] of TodoItem
      @filter = Filter::All
      @next_id = 1_i64
      load if !@path.empty? && File.exists?(@path)
    end

    def add(title : String) : TodoItem?
      clean = title.strip
      return nil if clean.empty?
      item = TodoItem.new(@next_id, clean, false)
      @next_id += 1
      @items << item
      save
      item
    end

    def toggle(id : Int64) : Bool
      if item = @items.find { |it| it.id == id }
        item.done = !item.done
        save
        true
      else
        false
      end
    end

    def remove(id : Int64) : Bool
      before = @items.size
      @items.reject! { |it| it.id == id }
      changed = @items.size != before
      save if changed
      changed
    end

    def clear_completed : Int32
      before = @items.size
      @items.reject!(&.done)
      removed = before - @items.size
      save if removed > 0
      removed
    end

    def set_all(done : Bool) : Nil
      changed = false
      @items.each do |it|
        if it.done != done
          it.done = done
          changed = true
        end
      end
      save if changed
    end

    def filter=(value : Filter) : Nil
      @filter = value
    end

    def visible_items : Array(TodoItem)
      case @filter
      when Filter::Active
        @items.select { |it| !it.done }
      when Filter::Completed
        @items.select(&.done)
      else
        @items.dup
      end
    end

    def remaining_count : Int32
      @items.count { |it| !it.done }
    end

    def completed_count : Int32
      @items.count(&.done)
    end

    def all_done? : Bool
      !@items.empty? && @items.all?(&.done)
    end

    def save : Nil
      return if @path.empty?
      dir = File.dirname(@path)
      Dir.mkdir_p(dir) unless dir.empty? || dir == "." || Dir.exists?(dir)
      data = {
        "next_id" => @next_id,
        "items"   => @items,
      }
      File.write(@path, data.to_json)
    end

    def load : Nil
      return if @path.empty? || !File.exists?(@path)
      content = File.read(@path)
      parsed = JSON.parse(content)
      @next_id = parsed["next_id"]?.try(&.as_i64) || 1_i64
      loaded = [] of TodoItem
      if arr = parsed["items"]?.try(&.as_a?)
        arr.each do |node|
          id = node["id"]?.try(&.as_i64?) || node["id"]?.try(&.as_i?)
          title = node["title"]?.try(&.as_s?)
          done = node["done"]?.try(&.as_bool?)
          next unless id && title && !done.nil?
          loaded << TodoItem.new(id.to_i64, title, done)
        end
      end
      @items = loaded
      max_id = @items.map(&.id).max?
      @next_id = Math.max(@next_id, (max_id || 0_i64) + 1_i64)
    rescue
      # Corrupt/unknown file: start fresh rather than crashing the app.
      @items = [] of TodoItem
      @next_id = 1_i64
    end
  end
end
