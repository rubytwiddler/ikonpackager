
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
                @fileSelectDlg.setDirectory(@iconDirsComboBox.currentText)
                if @fileSelectDlg.exec == Qt::Dialog::Accepted then
                    dir = @fileSelectDlg.selectedFiles.first
                    @iconDirsComboBox.addItem(dir)
                    index = @iconDirsComboBox.findText(dir)
                    @iconDirsComboBox.currentIndex = index
                end
            end
        end
        @packageNameLineEdit = KDE::LineEdit.new('New Icon Package')
        @okBtn = KDE::PushButton.new(KDE::Icon.new('dialog-ok'), 'OK')
        @cancelBtn = KDE::PushButton.new(KDE::Icon.new('dialog-cancel'), 'Cancel')
        connect(@okBtn, SIGNAL(:clicked), self, SLOT(:accept))
        connect(@cancelBtn, SIGNAL(:clicked), self, SLOT(:reject))
        #

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

