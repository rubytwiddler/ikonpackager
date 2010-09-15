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

    # check duplicate and add.
    def add(name)
        sym = name.to_sym
        unless @icons[sym] then
            @icons[sym] = IconInfo.new(sym)
        end
        @icons[sym]
    end

    def each
        @icons.each_value { |i| yield i }
    end

    def [](name)
        ret = @icons[name.to_sym]
        unless ret
            puts "internal error. no icon named:'#{name}'"
            puts @icons.keys.inspect
            puts @icons.values.inspect
            exit 1
        end
        ret
    end
end

class IconPackage
    attr_reader :path, :sizes, :types, :icons
    alias :list :icons

    protected
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
                            icon = @icons.add(f)
                            icon.addSize(size)
                            icon.addType(type)
                        end
                    end
                end
            end
        end
    end

    public
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

    def self.setPath(path)
        @@package = self.new(path)
    end

    def self.filePath(name, preferredSize=[])
        @@package.filePath(name, preferredSize)
    end

    # bypassing.
#     %w{ path sizes types icons }.each do |atr|
#         self.module_eval do
#             @@package.__send__(atr)
#         end
#     end

    def self.icons
        @@package.icons
    end

    def self.path
        @@package.path
    end

    def self.sizes
        @@package.sizes
    end

    def self.types
        @@package.types
    end

    def self.getIconInfo(name)
        icons[name]
    end
end
