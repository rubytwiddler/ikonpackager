#--------------------------------------------------------------------
#
#
class IconListPane < Qt::Frame
    class IconListWidget < Qt::ListWidget
        def setPackage(package)
            clear
            package.eachIcon do |i|
                qtIcon = Qt::Icon.new(package.filePath(i.name))
                addItem(Qt::ListWidgetItem.new(qtIcon, i.name))
            end
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
    end

    slots :selectType
    def selectType
        return unless @package

        menu = Qt::Menu.new
        menu.addAction(PRE_TYPE + 'All')

        # set types list in @typeButton
        @package.allTypes.each do |type|
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
        if text then
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
        return unless @panes.include? pane and pane and @activePane != pane
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
end
