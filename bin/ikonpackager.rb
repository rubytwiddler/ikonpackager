#!/usr/bin/ruby
#
#    2010 by ruby.twiddler@gmail.com
#
#      icon packager for KDE.
#

$KCODE = 'UTF8'
require 'ftools'

APP_NAME = File.basename(__FILE__).sub(/\.rb/, '')
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
class IconWidget < Qt::Widget

    def initialize(size)
        super(nil)
        @iconSize = Qt::Size.new(size, size)
        self.minimumSize = @iconSize
        self.maximumSize = @iconSize
        self.size = @iconSize
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
            addItem(Qt::ListWidgetItem.new(qtIcon, i.name.to_s))
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
        Dir.allDirType(path).each do |f|
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
        @icon16 =  IconWidget.new(16)
        @icon22 =  IconWidget.new(22)
        @icon32 =  IconWidget.new(32)
        @icon48 =  IconWidget.new(48)
        @icon64 =  IconWidget.new(64)
        @icon128 =  IconWidget.new(128)
        @iconView =  IconWidget.new(256)
#         @iconSVG =  IconWidget.new

        # icon list
        @iconListWidget = IconListWidget.new
        @iconListWidget.viewMode = Qt::ListView::IconMode

        # layout
        vl = Qt::VBoxLayout.new do |l|
            l.addWidget(@icon16)
            l.addWidgets(nil, '16x16', nil)
            l.addWidget(@icon22)
            l.addWidgets(nil, '22x22', nil)
            l.addWidget(@icon32)
            l.addWidgets(nil, '32x32', nil)
            l.addWidget(@icon48)
            l.addWidgets(nil, '48x48', nil)
            l.addWidget(@icon64)
            l.addWidgets(nil, '64x64', nil)
            l.addWidget(@icon128)
            l.addWidgets(nil, '128x128', nil)
        end
        iconInfoLayout = Qt::HBoxLayout.new do |l|
            l.addWidget(@iconView)
            l.addLayout(vl)
        end


        # layout
        hlw = HBoxLayoutWidget.new do |l|
            l.addLayout(iconInfoLayout)
            l.addWidget(@iconListWidget)
            l.layout.setStretch(0,0)
            l.layout.setStretch(1,1)
        end
        setCentralWidget(hlw )
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
        @iconPackage = IconPackage.new(path)
        @iconListWidget.setPackage(@iconPackage)
    end

    slots :selectPackage
    def selectPackage
        path = @iconPackageSelectorDlg.select
#         iconPackageSelected(path)
    end
end


#
#    main start
#

$about = KDE::AboutData.new(APP_NAME, nil, KDE::ki18n(APP_NAME), APP_VERSION,
                            KDE::ki18n('Gem Utitlity with KDE GUI.')
                           )
$about.addLicenseTextFile(APP_DIR + '/MIT-LICENSE')
KDE::CmdLineArgs.init(ARGV, $about)

$app = KDE::Application.new
args = KDE::CmdLineArgs.parsedArgs()
$config = KDE::Global::config
win = MainWindow.new
$app.setTopWidget(win)

win.show
$app.exec
