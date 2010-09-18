#!/usr/bin/ruby
#
#    2010 by ruby.twiddler@gmail.com
#
#      icon packager for KDE.
#

$KCODE = 'UTF8'
require 'ftools'

APP_FILE = File.symlink?(__FILE__) ? File.readlink(__FILE__) : __FILE__
APP_NAME = File.basename(APP_FILE).sub(/\.rb/, '')
APP_DIR = File::dirname(File.expand_path(File.dirname(__FILE__)))
LIB_DIR = File::join(APP_DIR, "lib")
APP_VERSION = "0.1.0"

# standard libs
require 'rubygems'
require 'fileutils'
require 'net/http'
require 'shellwords'
require 'set'
require 'ap'

# additional libs
require 'korundum4'

#
# my libraries and programs
#
$:.unshift(LIB_DIR)
require "mylibs"
require "icon"




#--------------------------------------------------------------------
#
#
class IconPackageSelectorDlg < Qt::Dialog
    def initialize
        super(nil)
        self.windowTitle = i18n('Select Package')

        @iconDirsComboBox = Qt::ComboBox.new do |w|
            w.addItems(KDE::Global.dirs.resourceDirs('icon'))
            connect(w, SIGNAL('currentIndexChanged(int)'), self, SLOT('currentIndexChanged(int)'))
        end

        @iconPckagesList = Qt::ListWidget.new
        connect(@iconPckagesList, SIGNAL('itemClicked(QListWidgetItem *)'), \
                self, SLOT('itemClicked(QListWidgetItem *)'))

        @closeBtn = KDE::PushButton.new(KDE::Icon.new('dialog-close'), i18n('Close'))
        connect(@closeBtn, SIGNAL(:clicked), self, SLOT(:close))

        # layout
        lo = Qt::VBoxLayout.new do |l|
            l.addWidget(@iconDirsComboBox)
            l.addWidget(@iconPckagesList)
            l.addWidgets(nil, @closeBtn)
        end
        setLayout(lo)
    end

    slots 'currentIndexChanged(int)'
    def currentIndexChanged(index)
        updateIconPackageList
    end

    slots 'itemClicked(QListWidgetItem *)'
    signals 'iconPackageSelected(const QString&)'
    def itemClicked(item)
        emit iconPackageSelected(File.join(@lastPath, item.text))
    end

    def updateIconPackageList
        def iconDir?(path, file)
            Dir.allDirs(File.join(path, file)).find { |d| d == 'scalable' or d =~ /^\d\d+/ }
        end

        path = @iconDirsComboBox.currentText
        return if @lastPath and @lastPath == path

        @lastPath = path
        @iconPckagesList.clear
        Dir.allDirs(path).sort.each do |f|
            @iconPckagesList.addItem(f) if iconDir?(path, f)
        end
    end

    def iconPackagePath
        return nil unless @iconPckagesList.currentItem
        File.join(@lastPath, @iconPckagesList.currentItem.text)
    end

    # call this for select package.
    def select
        updateIconPackageList
        return nil unless exec == Qt::Dialog::Accepted
        iconPackagePath
    end
end


#--------------------------------------------------------------------
#
#
class IconPackageNewDlg < Qt::Dialog

    def initialize
        super(nil)
        self.windowTitle = i18n('Create Package')

        @fileSelectDlg = Qt::FileDialog.new do |w|
            w.options = Qt::FileDialog::ShowDirsOnly
            w.fileMode = Qt::FileDialog::Directory
        end
        @iconDirsComboBox = Qt::ComboBox.new do |w|
            KDE::Global.dirs.resourceDirs('icon').map do |d|
                if File.writable?(d) then
                    w.addItem(d)
                end
            end
        end
        @otherDirBtn = KDE::PushButton.new(i18n('Other Directory')) do |w|
            connect(w, SIGNAL(:clicked)) do
                if @fileSelectDlg.exec == Qt::Dialog::Accepted then
                    dir = @fileSelectDlg.selectedFiles.first
                    @iconDirsComboBox.addItem(dir)
                    index = @iconDirsComboBox.findText(dir)
                    @iconDirsComboBox.currentIndex = index
                end
            end
        end
        @packageNameLineEdit = KDE::LineEdit.new
        @okBtn = KDE::PushButton.new(KDE::Icon.new('dialog-ok'), 'OK')
        @cancelBtn = KDE::PushButton.new(KDE::Icon.new('dialog-cancel'), 'Cancel')
        connect(@okBtn, SIGNAL(:clicked), self, SLOT(:accept))
        connect(@cancelBtn, SIGNAL(:clicked), self, SLOT(:reject))

        # layout
        lo = Qt::VBoxLayout.new do |l|
            l.addWidgets(@iconDirsComboBox, @otherDirBtn)
            l.addWidgets(i18n('Package Name :'), @packageNameLineEdit)
            l.addWidgets(nil, @okBtn, @cancelBtn)
        end
        setLayout(lo)
    end

    def packageName
        @packageNameLineEdit.text
    end

    def packagePath
        @iconDirsComboBox.currentText
    end
end


#--------------------------------------------------------------------
#
#
class IconWidget < KDE::PixmapRegionSelectorWidget

    def initialize(len)
        super(nil)
        @iconSize = Qt::Size.new(len, len)
        setMaximumWidgetSize(len, len)
    end

    def setIcon(icon)
        setPixmap(icon.pixmap(@iconSize))
    end
end

#--------------------------------------------------------------------
#
#
class IconViewDock < Qt::DockWidget
    def initialize(parent)
        super(i18n('Icon View'), parent)
        self.objectName = 'IconView'
        @scrollArea = Qt::ScrollArea.new do |w|
            w.alignment = Qt::AlignHCenter
        end
        setWidget(@scrollArea)
    end

    def iconChanged(package, name)
        iconInfo = package.getIconInfo(name)
        vw = VBoxLayoutWidget.new
        iconInfo.sizes.sort_by do |s|
            num = s[/\d+/]
            num ? num.to_i : 0
        end.each do |sz|
            filePath = package.filePath(name, sz)
            if sz == 'scalable' then
                icon = IconWidget.new(128)
                icon.setIcon(Qt::Icon.new(filePath))
                vw.addWidgets(nil, icon, nil)
                vw.addWidgets(nil, "svg", nil)
            else
                edgeLen = sz[/\d+/].to_i
                icon = IconWidget.new(edgeLen)
                icon.setIcon(Qt::Icon.new(filePath))
                vw.addWidgets(nil, icon, nil)
                vw.addWidgets(nil, "#{edgeLen} x #{edgeLen}", nil)
            end
        end
        oldw = @scrollArea.takeWidget
        @scrollArea.setWidget(vw)
        oldw.destroy if oldw
    end
end


#--------------------------------------------------------------------
#
#
class IconInfoDock < Qt::DockWidget
    def initialize(parent)
        super(i18n('Icon Info'), parent)
        self.objectName = 'IconInfo'

        @packageLabel = Qt::Label.new('')
        @nameLabel = Qt::Label.new('')
        @typesLabel = Qt::Label.new('')
        @sizesLabel = Qt::Label.new('') do |w|
            w.wordWrap = true
        end
        @scrollArea = Qt::ScrollArea.new do |w|
            w.widgetResizable = true
        end

        # layout
        formLayout = Qt::FormLayout.new do |l|
            l.addRow('Package:', @packageLabel)
            l.addRow('Name:', @nameLabel)
            l.addRow('Type:', @typesLabel)
            l.addRow('Size:', @sizesLabel)
        end
        lw = VBoxLayoutWidget.new do |l|
            l.addLayout(formLayout)
        end
        @scrollArea.setWidget(lw)
        setWidget(@scrollArea)
    end

    def iconChanged(package, name)
        iconInfo = package.getIconInfo(name)

        @packageLabel.text = package.packageName
        @nameLabel.text = name
        @typesLabel.text = iconInfo.types.join(',')
        @sizesLabel.text = iconInfo.sizes.join(', ')
    end
end


#--------------------------------------------------------------------
#
#
class IconListPane < Qt::Frame
    class IconListWidget < Qt::ListWidget
        def setPackage(package)
            clear
            package.list.each do |i|
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

        self.frameShape = Qt::Frame::Panel
        self.styleSheet = StyleFocusOff
        createWidget
    end

    PRE_TYPE = 'Type: '

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
            connect(w, SIGNAL('itemClicked(QListWidgetItem*)')) do |i|
                @observer.eventCall(:iconChanged,  @package, i.text)
            end
        end
        #
        @searchLine = KDE::ListWidgetSearchLine.new(nil, @iconListWidget)

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
            filterIconByType(action.text[PRE_TYPE.size..-1])
        end
        menu.deleteLater
    end

    def filterIconByType(type)
        def displayAll
            @iconListWidget.count.times do |n|
                @iconListWidget.item(n).setHidden(false)
            end
        end
        def filterByType(type_sym)
            @iconListWidget.count.times do |n|
                i = @iconListWidget.item(n)
                iconInfo = @package.getIconInfo(i.text)
                i.setHidden(! iconInfo.memberType?(type_sym) )
            end
        end

        puts "filter:#{type}"
        type_sym = type.to_sym
        if type_sym == :All then
            displayAll
        else
            filterByType(type_sym)
        end
    end

    def focused?
        [ @typeButton, @iconListWidget, @searchLine ].find { |o| o.focus }
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
    end

end

#--------------------------------------------------------------------
#--------------------------------------------------------------------
#
#
#
class MainWindow < KDE::MainWindow
    def initialize
        super(nil)
        setCaption(APP_NAME)

        @actions = KDE::ActionCollection.new(self)
        createWidgets
        createMenu
        createToolBar
        createDialogs
        @actions.readSettings
        setAutoSaveSettings

        Qt::Timer.singleShot(0, self, SLOT(:firstSystemUpdate))
    end

    #
    #
    def createWidgets
        @iconViewDoc = IconViewDock.new(self)
        addDockWidget(Qt::LeftDockWidgetArea, @iconViewDoc)
        @iconInfoDoc = IconInfoDock.new(self)
        addDockWidget(Qt::LeftDockWidgetArea, @iconInfoDoc)

        @iconListLeftPane = IconListPane.new
        @iconListRightPane = IconListPane.new
        @paneGroup = PaneGroup.new do |w|
            w.add(@iconListLeftPane)
            w.add(@iconListRightPane)
            w.addIconPeer(@iconInfoDoc)
            w.addIconPeer(@iconViewDoc)
        end

        @paneSplitter = Qt::Splitter.new(Qt::Horizontal) do |s|
            s.addWidget(@iconListLeftPane)
            s.addWidget(@iconListRightPane)
        end
        setCentralWidget(@paneSplitter)
    end

    #
    #
    #
    def createMenu
        # create actions
        @quitAction = @actions.addNew(i18n('Quit'), self, \
            { :icon => 'exit', :shortCut => 'Ctrl+Q', :triggered => :close })
        @openPackageAction = @actions.addNew(i18n('Open Package'), self, \
            { :icon => 'document-open', :shortCut => 'Ctrl+O', :triggered => :openPackage })
        @newPackageAction = @actions.addNew(i18n('New Icon Package'), self, \
            { :icon => 'document-new', :shortCut => 'Ctrl+N', :triggered => :newPackage})
        @renameAction = @actions.addNew(i18n('Rename Icon'), self, \
            { :icon => 'edit-rename', :shortCut => 'Ctrl+R', :triggered => :renameIcon })
        @moveAction = @actions.addNew(i18n('Move Icon'), self, \
            { :icon => 'configure', :shortCut => 'Ctrl+M', :triggered => :moveIcon })
        @cutAction = @actions.addNew(i18n('Cut Icon'), self, \
            { :icon => 'edit-cut', :shortCut => 'Ctrl+X', :triggered => :cutIcon })
        @copyAction = @actions.addNew(i18n('Copy Icon'), self, \
            { :icon => 'edit-copy', :shortCut => 'Ctrl+C', :triggered => :copyIcon })
        @pasteAction = @actions.addNew(i18n('Paste Icon'), self, \
            { :icon => 'edit-paste', :shortCut => 'Ctrl+V', :triggered => :pasteIcon })

        # file menu
        fileMenu = KDE::Menu.new(i18n('&File'), self)
        fileMenu.addAction(@newPackageAction)
        fileMenu.addAction(@openPackageAction)
        fileMenu.addSeparator
        fileMenu.addAction(@quitAction)

        # edit menu
        editMenu = KDE::Menu.new(i18n('Edit'), self)
        editMenu.addAction(@renameAction)
        editMenu.addAction(@moveAction)
        editMenu.addAction(@cutAction)
        editMenu.addAction(@copyAction)
        editMenu.addAction(@pasteAction)

        # settings menu
#         settingsMenu = KDE::Menu.new(i18n('Settings'), self)
#         settingsMenu.addAction(@pasteAction)

        # help menu

        # insert menus in MenuBar
        menu = KDE::MenuBar.new
        menu.addMenu( fileMenu )
        menu.addMenu( editMenu )
#         menu.addMenu( helpMenu )
        setMenuBar(menu)
    end

    def createToolBar
        @mainToolBar = toolBar
        @mainToolBar.addAction(@newPackageAction)
        @mainToolBar.addAction(@openPackageAction)
        @mainToolBar.addAction(@renameAction)
        @mainToolBar.addAction(@moveAction)
        @mainToolBar.addAction(@cutAction)
        @mainToolBar.addAction(@copyAction)
        @mainToolBar.addAction(@pasteAction)
    end

    #
    #
    #
    def createDialogs
        @iconPackageSelectorDlg = IconPackageSelectorDlg.new do |d|
            connect(d, SIGNAL('iconPackageSelected(const QString&)'), \
                    self, SLOT('iconPackageSelected(const QString&)'))
        end
        @iconPackageNewDlg = IconPackageNewDlg.new
    end


    #-------------------------------------------------------------
    #
    #
    slots :firstSystemUpdate
    def firstSystemUpdate
        @paneGroup.activePane = @iconListLeftPane
    end

    slots 'iconPackageSelected(const QString&)'
    def iconPackageSelected(path)
        @paneGroup.activePane.setPackagePath(path)
    end

    slots :openPackage
    def openPackage
        path = @iconPackageSelectorDlg.select
    end

    slots :newPackage
    def newPackage
        @iconPackageNewDlg.exec
    end

    slots :renameIcon
    def renameIcon
    end

    slots :moveIcon
    def moveIcon
    end

    slots :cutIcon
    def cutIcon
    end

    slots :copyIcon
    def copyIcon
    end

    slots :pasteIcon
    def pasteIcon
    end
end



#--------------------------------------------------------------------
#
#    main start
#
about = KDE::AboutData.new(APP_NAME, nil, KDE::ki18n(APP_NAME), APP_VERSION,
                            KDE::ki18n('Gem Utitlity with KDE GUI.')
                           )
about.addLicenseTextFile(APP_DIR + '/MIT-LICENSE')
KDE::CmdLineArgs.init(ARGV, about)

$app = KDE::Application.new
# KDE::CmdLineArgs.parsedArgs()
$config = KDE::Global::config

win = MainWindow.new
$app.setTopWidget(win)
win.show
$app.exec
