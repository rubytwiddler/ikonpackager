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

# additional libs
require 'korundum4'

#
# my libraries and programs
#
$:.unshift(LIB_DIR)
require "mylibs"
require "icon"
require "icondlgs.rb"
require "iconpanels.rb"
require "iconlistpane.rb"


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
        @iconViewDock = IconViewDock.new(self)
        addDockWidget(Qt::LeftDockWidgetArea, @iconViewDock)
        @iconInfoDock = IconInfoDock.new(self)
        addDockWidget(Qt::LeftDockWidgetArea, @iconInfoDock)

        @iconListLeftPane = IconListPane.new
        @iconListRightPane = IconListPane.new
        @paneGroup = PaneGroup.new do |w|
            w.add(@iconListLeftPane)
            w.add(@iconListRightPane)
            w.addIconPeer(@iconInfoDock)
            w.addIconPeer(@iconViewDock)
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
        @iconViewAction = @iconViewDock.toggleViewAction
        @iconInfoAction = @iconInfoDock.toggleViewAction
        @splitPaneAction = KDE::ToggleAction.new(KDE::Icon.new('view-split-left-right'), \
                                                i18n('split/close'),self)
        @splitPaneAction.checked = true
        connect(@splitPaneAction, SIGNAL('toggled(bool)'), @paneGroup, \
                SLOT('splitPaneToggled(bool)'))

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

        # view menu
        viewMenu = KDE::Menu.new(i18n('View'), self)
        viewMenu.addAction(@iconInfoAction)
        viewMenu.addAction(@iconViewAction)
        viewMenu.addSeparator
        viewMenu.addAction(@splitPaneAction)

        # settings menu
#         settingsMenu = KDE::Menu.new(i18n('Settings'), self)
#         settingsMenu.addAction(@pasteAction)

        # help menu

        # insert menus in MenuBar
        menu = KDE::MenuBar.new
        menu.addMenu( fileMenu )
        menu.addMenu( editMenu )
        menu.addMenu( viewMenu )
#         menu.addMenu( helpMenu )
        setMenuBar(menu)
    end

    def createToolBar
        @mainToolBar = toolBar
        @mainToolBar.addAction(@newPackageAction)
        @mainToolBar.addAction(@openPackageAction)
        @mainToolBar.addSeparator
        @mainToolBar.addAction(@splitPaneAction)
        @mainToolBar.addSeparator
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

    #------------------------------------
    #
    # virtual slot
    def closeEvent(ev)
        @actions.writeSettings
        super(ev)
        $config.sync    # important!  qtruby can't invoke destructor properly.
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
        if @iconPackageNewDlg.exec == Qt::Dialog::Accepted then
            iconPackageSelected(@iconPackageNewDlg.createNewPackage)
        end
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
