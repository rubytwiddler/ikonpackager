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
class Dir
    def self.allDirType(path)
        dirs = []
        Dir.foreach(path) do |f|
            fullPath = File.join(path, f)
            if File.directory?(fullPath) and f !~ /^\.\.?$/ then
                dirs << f
            end
        end
        dirs
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
class IconListWidget < Qt::ListWidget
    def setPackage(package)
        clear
        package.list.each do |i|
            qtIcon = Qt::Icon.new(package.filePath(i.name))
            addItem(Qt::ListWidgetItem.new(qtIcon, i.name))
        end
    end
end

#--------------------------------------------------------------------
#
#
class IconPackageSelectorDlg < Qt::Dialog
    IconDirs = KDE::Global.dirs.resourceDirs('icon')

    def initialize
        super(nil)

        @iconDirsComboBox = Qt::ComboBox.new do |w|
            w.addItems(IconDirs)
            connect(w, SIGNAL('currentIndexChanged(int)'), self, SLOT('currentIndexChanged(int)'))
        end

        @iconPckagesList = Qt::ListWidget.new
        connect(@iconPckagesList, SIGNAL('itemClicked(QListWidgetItem *)'), \
                self, SLOT('itemClicked(QListWidgetItem *)'))

        @okBtn = KDE::PushButton.new(KDE::Icon.new('dialog-ok'), 'OK')
        @cancelBtn = KDE::PushButton.new(KDE::Icon.new('dialog-cancel'), 'Cancel')
        connect(@okBtn, SIGNAL(:clicked), self, SLOT(:accept))
        connect(@cancelBtn, SIGNAL(:clicked), self, SLOT(:reject))

        # layout
        lo = Qt::VBoxLayout.new
        lo.addWidget(@iconDirsComboBox)
        lo.addWidget(@iconPckagesList)
        lo.addWidgets(nil, @okBtn, @cancelBtn)
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
        path = @iconDirsComboBox.currentText
        return if @lastPath and @lastPath == path

        @lastPath = path
        @iconPckagesList.clear
        Dir.allDirType(path).sort.each do |f|
            @iconPckagesList.addItem(f)
        end
    end

    def iconPackagePath
        return nil unless @iconPckagesList.currentItem
        File.join(@lastPath, @iconPckagesList.currentItem.text)
    end

    def select
        updateIconPackageList
        return nil unless exec == Qt::Dialog::Accepted
        iconPackagePath
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

    slots 'itemClicked(QListWidgetItem*)'
    def itemClicked(item)
        name = item.text
        iconInfo = IconPackage.getIconInfo(name)
        vw = VBoxLayoutWidget.new
        iconInfo.sizes.sort_by do |s|
            num = s[/\d+/]
            num ? num.to_i : 0
        end.each do |sz|
            filePath = IconPackage.filePath(name, sz)
#             puts "filePath:#{filePath} : exist? #{File.exist?(filePath)} "
#             puts "size : #{sz.inspect}"
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

    slots 'itemClicked(QListWidgetItem*)'
    def itemClicked(item)
        name = item.text
        iconInfo = IconPackage.getIconInfo(name)

        @nameLabel.text = name
        @typesLabel.text = iconInfo.types.join(',')
        @sizesLabel.text = iconInfo.sizes.join(', ')
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
        createDialogs
        @actions.readSettings
        setAutoSaveSettings

        Qt::Timer.singleShot(0, self, SLOT(:listDirectory))
    end

    #
    #
    #
    def createWidgets
        @iconViewDoc = IconViewDock.new(self)
        addDockWidget(Qt::LeftDockWidgetArea, @iconViewDoc)
        @iconInfoDoc = IconInfoDock.new(self)
        addDockWidget(Qt::LeftDockWidgetArea, @iconInfoDoc)


        # icon list
        @iconListWidget = IconListWidget.new do |w|
            w.viewMode = Qt::ListView::IconMode
            w.sortingEnabled = true
            connect(w, SIGNAL('itemClicked(QListWidgetItem*)'), \
                    @iconViewDoc, SLOT('itemClicked(QListWidgetItem*)'))
            connect(w, SIGNAL('itemClicked(QListWidgetItem*)'), \
                    @iconInfoDoc, SLOT('itemClicked(QListWidgetItem*)'))
        end
        #
        @searchLine = KDE::ListWidgetSearchLine.new(nil, @iconListWidget)

        # layout
        lw = VBoxLayoutWidget.new do |l|
            l.addWidgets('Find:', @searchLine)
            l.addWidget(@iconListWidget)
        end
        setCentralWidget(lw)
    end

    #
    #
    #
    def createMenu
        # create actions
        quitAction = @actions.addNew(i18n('Quit'), self, \
            { :icon => 'exit', :shortCut => 'Ctrl+Q', :triggered => :close })
        openPackageAction = @actions.addNew(i18n('Open Package'), self, \
            { :icon => 'document-open', :shortCut => 'Ctrl+O', :triggered => :selectPackage })

        # file menu
        fileMenu = KDE::Menu.new(i18n('&File'), self)
        fileMenu.addAction(openPackageAction)
        fileMenu.addSeparator
        fileMenu.addAction(quitAction)

        # insert menus in MenuBar
        menu = KDE::MenuBar.new
        menu.addMenu( fileMenu )
#         menu.addMenu( helpMenu )
        setMenuBar(menu)
    end

    #
    #
    #
    def createDialogs
        @iconPackageSelectorDlg = IconPackageSelectorDlg.new do |d|
            connect(d, SIGNAL('iconPackageSelected(const QString&)'), \
                    self, SLOT('iconPackageSelected(const QString&)'))
        end
    end


    #-------------------------------------------------------------
    #
    #
    slots :listDirectory
    def listDirectory

    end



    slots 'iconPackageSelected(const QString&)'
    def iconPackageSelected(path)
        package = IconPackage.setPath(path)
        @iconListWidget.setPackage(package)
    end

    slots :selectPackage
    def selectPackage
        path = @iconPackageSelectorDlg.select
#         iconPackageSelected(path)
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
