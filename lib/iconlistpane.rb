#--------------------------------------------------------------------
#
#
class IconListPane < Qt::Frame
    class IconListWidget < Qt::ListWidget
        def setPackage(package)
            @package = package
            clear
            package.eachIcon do |i|
                addIcon(i.name)
            end
        end

        def addIcon(name)
            qtIcon = Qt::Icon.new(@package.filePath(name))
            addItem(Qt::ListWidgetItem.new(qtIcon, name))
        end
    end

    StyleFocusOff = "IconListPane { border: 1px solid transparent; }"
    StyleFocusOn = "IconListPane { border: 1px solid; }"

    def initialize
        super(nil)
        @package = nil
        @activeFlag = false
        @typeFilter = :All

        self.frameShape = Qt::Frame::Panel
        self.styleSheet = StyleFocusOff
        createWidget
    end

    PRE_TYPE = 'Type: '

    attr_reader :package
    attr_writer :observer
    signals 'itemClicked(QObject&,const QString&)'
    def createWidget
        # type select button
        @typeButton = KDE::PushButton.new(PRE_TYPE + 'All') do |w|
            connect(w, SIGNAL(:clicked), self, SLOT(:selectType))
        end

        # icon list
        @iconListWidget = IconListWidget.new do |w|
            w.viewMode = Qt::ListView::IconMode
            w.sortingEnabled = true
            w.movement = Qt::ListView::Static
            w.resizeMode = Qt::ListView::Adjust
            w.gridSize = Qt::Size.new(64,64)
            connect(w, SIGNAL('itemClicked(QListWidgetItem*)')) do |i|
                @selectedItem = i
                @observer.eventCall(:iconChanged,  @package, i.text)
            end
        end
        #
        @searchLine = KDE::LineEdit.new do |w|
            connect(w,SIGNAL('textChanged(const QString &)'), \
                    self, SLOT('filterChanged(const QString &)'))
            w.setClearButtonShown(true)
        end

        # layout
        lo = Qt::VBoxLayout.new do |l|
            l.addWidgets(@typeButton, 'Find:', @searchLine)
            l.addWidget(@iconListWidget)
        end
        setLayout(lo)
    end


    def setPackagePath(path)
        @package = IconPackage.new(path)
        @iconListWidget.setPackage(@package)
        @typeButton.text = PRE_TYPE + 'All'
        @searchLine.text = ''
        @typeFilter = :All
        @selectedItem = nil
    end

    def addIcon(icon)
        @package.addIcon(icon)
        @iconListWidget.addIcon(icon.name)
    end

    slots :selectType
    def selectType
        return unless @package

        menu = Qt::Menu.new
        menu.addAction(PRE_TYPE + 'All')

        # set types list in @typeButton
        @package.allTypes.sort.each do |type|
            menu.addAction(PRE_TYPE  + type)
        end
        action = menu.exec(@typeButton.mapToGlobal(Qt::Point.new(20, 10)))
        if action then
            @typeButton.text = action.text
            @typeFilter = action.text[PRE_TYPE.size..-1] .to_sym
            filterChanged(@searchLine.text)
        end
        menu.deleteLater
    end

    slots 'filterChanged(const QString &)'
    def filterChanged(text)
        if text and !text.empty? then
            regx = /#{Regexp.escape(text.strip)}/i
        else
            regx = nil
        end
        @iconListWidget.count.times do |n|
            i = @iconListWidget.item(n)
            if regx and i.text !~ regx then
                @iconListWidget.item(n).setHidden(true)
            elsif @typeFilter == :All then
                @iconListWidget.item(n).setHidden(false)
            else
                iconInfo = @package.getIconInfo(i.text)
                i.setHidden(! iconInfo.memberType?(@typeFilter) )
            end
        end
    end

    def focused?
        [ @iconListWidget, @searchLine, @typeButton ].find { |o| o.focus }
    end

    def active=(flag)
        return if @activeFlag == flag
        @activeFlag = flag
        self.styleSheet = flag ? StyleFocusOn : StyleFocusOff
    end

    def active
        @activeFlag
    end

    def itemSelected?
        active and @selectedItem and !@selectedItem.isHidden
    end

    def selectedIconName
        return nil unless itemSelected?
        @selectedItem.text
    end

    def selectedIconInfo
        return nil unless @package
        name = selectedIconName
        return nil unless name
        @package.getIconInfo(name)
    end


    #---------------------------------------
    #
    #
    def renameIcon(newName)
        puts "rename to #{newName}"
        return nil unless itemSelected?

        # check exist.
        if @package.getIconInfo(newName) then
            KDE::MessageBox.information(self, i18n("icon named '%s' is already exist.") % newName)
            return
        end

        icon = selectedIconInfo
        dir = @package.path

        icon.types.each do |type|
            icon.sizes.each do |sz|
                srcPath = icon.realFileName(dir, sz, type)
                fileExtName = File.extname(srcPath)
                dstPath = File.join(dir, sz, type, newName + fileExtName)
                puts "mv #{srcPath.shellescape} #{dstPath.shellescape}"
                FileUtils.mv(srcPath, dstPath)
            end
        end

        oldName = icon.name
        # update iconInfo
        @package.renameIcon(icon, newName)

        # update iconList
        @selectedItem.text = newName
    end

    def copyIconFrom(srcPackage, srcIcon)
        return if srcIcon.multiple?

        dstDir = @package.path
        srcDir = srcPackage.path
        name = srcIcon.name

        return if File.expand_path(dstDir) == File.expand_path(srcDir)

        # writable check
        unless File.writable?(dstDir) then
            KDE::MessageBox::information(self, i18n("package '%s' directory is not writable.") % @package.packageName)
            return
        end
        # overwrite check
        overwrite = false
        if @package.exist?(name) then
            ret = KDE::MessageBox::questionYesNo(self, i18n("'%s' icon already exist. proceed any way?") % name)
            return unless ret == KDE::MessageBox::Yes
            overwrite = true
        end

        type = srcIcon.types.first
        sizes = srcIcon.sizes
        sizes.each do |sz|
            srcPath = srcIcon.realFileName(srcDir, sz, type)
            fileBaseName = File.basename(srcPath)
            dstPath = File.join(dstDir, sz, type, fileBaseName)
            puts "cp #{srcPath.shellescape} #{dstPath.shellescape}"
            FileUtils.mkdir_p(File.dirname(dstPath))
            FileUtils.cp(srcPath, dstPath)
        end
        # update display
        addIcon(srcIcon) unless overwrite
    end
end


#-----------------------------------------------------
#
#
class PaneGroup < Qt::Object
    def initialize(parent=nil)
        @activePane = nil
        @panes = []
        @iconPeers = []
        super(parent)

        connect($app, SIGNAL('focusChanged(QWidget*,QWidget*)')) do |from,to|
            updatefocus
        end
    end

    attr_reader :activePane
    def add(pane)
        return if @panes.include? pane
        pane.observer= self
        @panes << pane
    end

    def nonActivePane
        (@panes - [@activePane]).first
    end

    def eventCall(method, *args)
        @iconPeers.each { |p| p.send(method, *args) }
    end

    def addIconPeer(peer)
        @iconPeers << peer
    end

    def updatefocus
        self.activePane = @panes.find { |p| p.focused? }
    end

    def activePane=(pane)
        return unless pane and @panes.include? pane and @activePane != pane
        @activePane = pane
        @panes.each { |p| p.active = p == @activePane }
        eventCall(:packageChanged, @activePane.package)
    end

    slots 'splitPaneToggled(bool)'
    def splitPaneToggled(flag)
        @splitFlag = flag
        if @splitFlag then
            # split
            @panes[1].visible = true
        else
            # close
            self.activePane = @panes[0]
            @panes[1].visible = false
        end
    end

    slots :swapPane
    def swapPane
        splitter = @panes[0].parent
        splitter.insertWidget(1, @panes[0])
        @panes[1], @panes[0] = @panes[0], @panes[1]
    end
end
