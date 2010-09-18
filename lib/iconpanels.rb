
#--------------------------------------------------------------------
#
#
class IconWidget < Qt::Widget

    def initialize(len)
        super(nil)
        @iconSize = Qt::Size.new(len, len)
        self.minimumSize = @iconSize
        self.maximumSize = @iconSize
    end

    def setIcon(icon)
        @iconPixmap = icon.pixmap(@iconSize)
    end

    def paintEvent(event)
        painter = Qt::Painter.new(self)
        painter.drawPixmap(0,0, @iconPixmap)
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
