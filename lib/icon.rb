#--------------------------------------------------------------------
#
#
class IconInfo
    attr_reader :name, :types, :sizes
    def initialize(name, type=nil, size=nil)
        @name = name.to_sym

        if type then
            @types = Set.new([type.to_sym])
        else
            @types = Set.new([])
        end

        if size then
            @sizes = Set.new([size.to_sym])
        else
            @sizes = Set.new([])
        end
    end

    def addSize(size)
        @sizes.add(size.to_sym)
    end

    def addType(type)
        @types.add(type.to_sym)
    end

    def multiple?
        @types.size > 1
    end
end

class IconList
    def initialize
        @icons = {}
    end

    def [](name)
        sym = name.to_sym
        unless @icons[sym] then
            @icons[sym] = IconInfo.new(sym)
        end
        @icons[sym]
    end

    def each
        @icons.each_value { |i| yield i }
    end
end

class IconPackage
    attr_reader :path, :sizes, :types, :icons
    alias :list :icons
    def initialize(path)
        @path = path
        @sizes = Set.new
        @types = Set.new
        @icons = IconList.new

        # sized
        @sizes += Dir.allDirType(path)

        # types
        @sizes.each do |d|
            @types += Dir.allDirType(File.join(path, d))
        end

        # size(e.g. 22x22) / type(e.g. mimetypes)
        @sizes.each do |size|
            @types.each do |type|
                dir = File.join(path, size, type)
                if File.exist? dir then
                    Dir.foreach(dir) do |f|
                        if f =~ /\.(png|jpg|jpeg|gif|svg)$/i then
                            icon = @icons[f]
                            icon.addSize(size)
                            icon.addType(type)
                        end
                    end
                end
            end
        end
    end

    # @name : icon name
    def filePath(name, preferredSize=[])
        icon = @icons[name]
        size ||= preferredSize.find { |s| icon.sizes.include?(s) }
        size ||= icon.sizes.max do |a, b|
                if a == :scalable then
                    1
                elsif b == :scalable then
                    -1
                else
                    a.to_s[/\d+/].to_i <=> b.to_s[/\d+/].to_i
                end
            end
        type = icon.types.first
        File.join(path, size.to_s, type.to_s, name.to_s)
    end
end
