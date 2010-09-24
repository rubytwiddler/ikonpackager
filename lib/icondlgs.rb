
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
class IconPackageNewDlg < Qt::Wizard
    def initialize
        super
        self.windowTitle = i18n('Create Icon Package')

        @namePage = PackageNamePage.new
        @sizePage = PackageSizesPage.new
        addPage(@namePage)
        addPage(@sizePage)
    end


    def createNewPackage
        packagePath = @namePage.packagePath
        FileUtils.makedirs( packagePath )
        unless File.exist?(packagePath)
            KDE::MessageBox.error(self, i18n("could'nt create %s directory") % packagePath)
            return
        end
        # directories
        @sizePage.allSizes.each do |size|
            sizePath = File.join(packagePath, size)
            FileUtils.makedirs(sizePath)
            @sizePage.allTypes.each do |type|
                typePath = File.join(packagePath, type)
                FileUtils.makedirs(sizePath)
            end
        end
        packagePath
    end
end


class PackageNamePage < Qt::WizardPage
    def initialize
        super

        setTitle(i18n('Package Directory and Name'))

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
                    emit completeChanged
                end
            end
        end

        @packageNameLineEdit = KDE::LineEdit.new(newName) do |w|
            connect(w, SIGNAL('textEdited(const QString&)')) do |text|
                emit completeChanged
            end
        end

        # layout
        lo = Qt::VBoxLayout.new do |l|
            l.addWidgets(@iconDirsComboBox, @otherDirBtn)
            l.addWidgets(i18n('Package Name :'), @packageNameLineEdit)
            l.addWidgets(nil, @okBtn, @cancelBtn)
        end
        setLayout(lo)
    end

    def newName
        name = baseName = 'New Icon Package'
        path = File.join(packageDir, name)
        num = 1
        while File.exist?(path) do
            num += 1
            name = baseName + ' ' + num.to_s
            path = File.join(packageDir, name)
        end
        name
    end

    # virtual method
    # @return bool
    def isComplete
        ! File.exist?(packagePath)
    end

    def packagePath
        File.join(packageDir, packageName)
    end

    def packageName
        @packageNameLineEdit.text.strip
    end

    def packageDir
        @iconDirsComboBox.currentText
    end
end

class PackageSizesPage < Qt::WizardPage
    def initialize
        super

        setTitle(i18n('Icon Package Szies and Types'))

        @sizeBoxes = %w{ 16 22 32 48 64 128 256 scalable }.map do |s|
            name = s != 'scalable' ? s+'x'+s : s
            Qt::CheckBox.new(name) do |w|
                w.checked = w.text =~ /\b64x/ ? true : false
                connect(w, SIGNAL('stateChanged(int)')) do |state|
                    emit completeChanged
                end
            end
        end
        lg1 = Qt::GridLayout.new do |l|
            @sizeBoxes.each_with_index do |b,i|
                x = i % 4
                y = i / 4
                l.addWidget(b, y,x)
            end
        end
        sizeGroup = Qt::GroupBox.new(i18n('Sizes'))
        sizeGroup.setLayout(lg1)

        @typeBoxes = %w{ actions animations apps categories devices emblems
            emotes filesystems intl mimetypes places status }.map do |t|
            Qt::CheckBox.new(t)
        end
        lg2 = Qt::GridLayout.new do |l|
            @typeBoxes.each_with_index do |b,i|
                x = i % 4
                y = i / 4
                l.addWidget(b, y,x)
            end
        end
        typeGroup = Qt::GroupBox.new(i18n('types'))
        typeGroup.setLayout(lg2)

        # layout
        lo = Qt::VBoxLayout.new do |l|
            l.addWidget(sizeGroup)
            l.addWidget(typeGroup)
        end
        setLayout(lo)
    end

    # virtual method
    # @return bool
    def isComplete
        @sizeBoxes.any? { |b| b.checked }
    end

    def allNames(names)
        names.inject([]) { |r, b| b.checked ? r << b.text.sub(/&/,'') : r }.sort
    end

    def allSizes
        allNames(@sizeBoxes)
    end

    def allTypes
        allNames(@typeBoxes)
    end
end