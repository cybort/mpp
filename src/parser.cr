require "./resolver"

class Parser
  def initialize(@resolver : Resolver, @directives = Hash(String, String).new)
    @visited = Hash(String, Array(String)).new
  end

  def process(paths : Array(String))
    String.build do |io|
      paths.each do |path|
        process(path, io)
      end
    end
  end

  def process(path : String)
    String.build do |io|
      process(path, io)
    end
  end

  def process(path : String, io : IO)
    path = @resolver.resolve(path)

    return if @visited[path]?
    @visited[path] = [] of String

    File.each_line(path) do |line|
      case line.strip
      when /^#include\s+/
        file = line.strip.sub(/^#include\s+/, "").gsub(/"/, "").gsub(/'/, "")
        @visited[path] << @resolver.resolve(file)
        process(file, io)
      when /^#define\s+/
        var, val = line.strip.sub(/^#define\s+/, "").split(/\s+/, 2)
        @directives[var] = val
      else
        io << @directives.reduce(line) { |line, key, val| line.gsub(key, val) }
      end
    end
  rescue err : Resolver::NotFound
    abort err
  end

  def make_dependencies
    relative = ->(file : String) { file.sub(Dir.current + "/", "") }

    rules = @visited.select { |_, deps| deps.any? }.map do |file, deps|
      "%s: %s\n\t@touch $@" % [
        relative.call(file),
        deps.map(&relative).join(" ")
      ]
    end

    rules << "" if rules.any?

    rules.join("\n\n")
  end
end
