#--------------------------------------------------------------------
#
#
class IconInfo
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

    def name
        @name.to_s
    end

    def types
        @types.map { |t| t.to_s }
    end

    def sizes
        @sizes.sort_by do |s|
            num = s.to_s[/\d+/]
            num ? num.to_i : 1024
        end .map { |s| s.to_s }
    end

    def maxSize
        return 'scalable' if @sizes.include?(:scalable)
        @sizes.max do |a, b|
            a.to_s[/\d+/].to_i <=> b.to_s[/\d+/].to_i
        end.to_s
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
    attr_reader :path, :allSizes, :allTypes, :icons
    alias :list :icons

    protected
    def initialize(path)
        @path = path
        @allSizes = Set.new
        @allTypes = Set.new
        @icons = IconList.new

        # all sizes
        @allSizes += Dir.allDirType(path)

        # all types
        @allSizes.each do |d|
            @allTypes += Dir.allDirType(File.join(path, d))
        end

        # size(e.g. 22x22) / type(e.g. mimetypes)
        @allSizes.each do |size|
            @allTypes.each do |type|
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
        unless preferredSize.kind_of? Array then
            preferredSize = [ preferredSize ]
        end
        icon = @icons[name]
        size ||= preferredSize.find { |s| icon.sizes.include?(s) }
        size ||= icon.maxSize
        type = icon.types.find do |t|
            File.exist?(File.join(path, size, t, name))
        end
        return nil unless type
        File.join(path, size, type, name)
    end

    def self.setPath(path)
        @@package = self.new(path)
    end

    def self.filePath(name, preferredSize=[])
        @@package.filePath(name, preferredSize)
    end

    # bypassing.
#     %w{ path allSizes allTypes icons }.each do |atr|
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

    def self.allSizes
        @@package.allSizes
    end

    def self.allTypes
        @@package.allTypes
    end

    def self.getIconInfo(name)
        icons[name]
    end
end
