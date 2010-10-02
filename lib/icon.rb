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
        @types.map { |t| t.to_s } .sort
    end

    def memberType?(type)
        @types.member?(type)
    end

    def sizes
        @sizes.map { |s| s.to_s } .sort_by do |s|
            num = s[/\d+/]
            num ? num.to_i : 1024
        end
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

    def addFileName(fileName)
        @fileNames ||= Set.new([])
        @fileNames.add(fileName)
    end

    def realFileName(path, size, type)
        filePath = nil
        return nil unless @fileNames.any? do |file|
            filePath = File.join(path, size, type, file)
            File.exist?(filePath)
        end
        return filePath
    end

    def multiple?
        @types.size > 1
    end
end


class IconPackage
    protected
    class IconList
        def initialize
            @icons = {}
        end

        # delete file extention.
        def nameNormalize(name)
            name.sub(/(.*)\.\w+$/, "\\1").to_sym
        end

        # check duplicate and add.
        def add(fileBaseName)
            sym = nameNormalize(fileBaseName)
            unless @icons[sym] then
                @icons[sym] = IconInfo.new(sym)
            end
            @icons[sym].addFileName(fileBaseName)
            @icons[sym]
        end

        def addIcon(icon)
            @icons[icon.name.to_sym] = icon
        end

        def each
            @icons.each_value { |i| yield i }
        end

        def [](name)
            @icons[name.to_sym]
        end
    end

    public
    attr_reader :path, :allSizes, :allTypes
#     attr_reader :iconList
#     alias :list :iconList
#     alias :icons :iconList

    def initialize(path)
        @path = path
        @allSizes = Set.new
        @allTypes = Set.new
        @iconList = IconList.new

        # all sizes
        @allSizes += Dir.allDirs(path)

        # all types
        @allSizes.each do |d|
            @allTypes += Dir.allDirs(File.join(path, d))
        end

        # size(e.g. 22x22) / type(e.g. mimetypes)
        @allSizes.each do |size|
            @allTypes.each do |type|
                dir = File.join(path, size, type)
                if File.exist? dir then
                    Dir.foreach(dir) do |f|
                        if f =~ /\.(png|jpg|jpeg|gif|svg|svgz)$/i then
                            icon = @iconList.add(f)
                            icon.addSize(size)
                            icon.addType(type)
                        end
                    end
                end
            end
        end
    end

    def exist?(name)
        @iconList[name]
    end

    def addIcon(icon)
        @allTypes += icon.types
        @allSizes += icon.sizes
        @iconList.addIcon(icon)
    end

    # @name : icon name
    def filePath(name, preferredSize=[])
        icon = @iconList[name]
        unless icon then
            puts "internal error: no icon name '#{name.to_s}'"
            puts @iconList.inspect
            exit 1
        end
        unless preferredSize.kind_of? Array then
            preferredSize = [ preferredSize ]
        end
        size = preferredSize.empty? ? icon.maxSize : \
                preferredSize.find { |s| icon.sizes.include?(s) }
        filePath = nil
        return nil unless icon.types.any? do |t|
            filePath = icon.realFileName(path, size, t)
        end
        filePath
    end

    def packageName
        File.basename(@path)
    end

    def eachIcon(&blk)
        @iconList.each(&blk)
    end

    def getIconInfo(name)
        @iconList[name]
    end
end
