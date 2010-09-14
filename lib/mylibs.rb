#
#  My library
#
#   Qt & other miscs

require 'singleton'
require 'korundum4'

#
class Qt::HBoxLayout
    def addWidgets(*w)
        w.each do |i|
            if i then
                e = i.kind_of?(String) ? Qt::Label.new(i) : i
                addWidget(e)
            else
                addStretch
            end
        end
    end
end

class Qt::VBoxLayout
    def addWidgetWithNilStretch(*w)
        addLayout(
            Qt::HBoxLayout.new do |l|
                l.addWidgets(*w)
            end
        )
    end
    alias :addWidgets :addWidgetWithNilStretch

    def addWidgetAtCenter(*w)
        w.unshift(nil)
        addWidgetWithNilStretch(*w)
    end

    def addWidgetAtRight(*w)
        w.unshift(nil)
        addWidgetWithNilStretch(*w)
    end

    def addWidgetAtLeft(*w)
        w.push(nil)
        addWidgetWithNilStretch(*w)
    end
end


#
class VBoxLayoutWidget < Qt::Widget
    def initialize(parent=nil)
        @layout = Qt::VBoxLayout.new
        super(parent)
        setLayout(@layout)
    end

    def addLayout(l)
        @layout.addLayout(l)
    end

    def addWidget(w)
        @layout.addWidget(w)
    end

    def addWidgetWithNilStretch(*w)
        @layout.addWidgetWithNilStretch(*w)
    end
    alias :addWidgets :addWidgetWithNilStretch

    def addWidgetAtRight(*w)
        @layout.addWidgetAtRight(*w)
    end

    def addWidgetAtCenter(*w)
        @layout.addWidgetAtCenter(*w)
    end

    def layout
        @layout
    end
end

class HBoxLayoutWidget < Qt::Widget
    def initialize(parent=nil)
        @layout = Qt::HBoxLayout.new
        super(parent)
        setLayout(@layout)
    end

    def addLayout(l)
        @layout.addLayout(l)
    end

    def addWidget(w)
        @layout.addWidget(w)
    end

    def addWidgets(*w)
        @layout.addWidgets(*w)
    end

    def layout
        @layout
    end
end


#--------------------------------------------------------------------------
#
#
def passiveMessage(text)
    %x{ kdialog --passivepopup #{text.shellescape} }
end


#--------------------------------------------------------------------------
#
#  Mandriva doesn't include kio smoke library.
#   FolderSelectorLineEdit substitute KDE::UrlRequester
#
class FolderSelectorLineEdit < Qt::Widget
    def initialize(dir=nil, parent=nil)
        super(parent)

        # widgets
        @lineEdit = KDE::LineEdit.new
        @lineEdit.text = dir if dir
        @dirSelectBtn = KDE::PushButton.new(KDE::Icon.new('folder'),'')

        # connect
        connect(@dirSelectBtn, SIGNAL(:clicked), self, SLOT(:openSelectDlg))

        # layout
        lo = Qt::HBoxLayout.new do |l|
            l.setContentsMargins(0,0,0,0)
            l.addWidgets(@lineEdit, @dirSelectBtn)
        end
        setLayout(lo)
    end

    slots :openSelectDlg
    def openSelectDlg
        path = Qt::FileDialog::getExistingDirectory(self,'select folder', @lineEdit.text)
        unless !path || path.empty?
            @lineEdit.text = path
        end
    end

    # for settings manager.
    def objectName=(name)
        @lineEdit.objectName = name
    end

    def folder
        @LineEdit.text
    end
    # compatibility for UrlRequester
    alias text folder

    def folder=(dir)
        @LineEdit.text = dir
    end
end




#--------------------------------------------------------------------------
#
#

class Qt::Action
    def setVData(data)
        setData(Qt::Variant.new(data))
    end

    def vData
        self.data.toString
    end
end

module Mime
    def self.services(url)
        mimeType = KDE::MimeType.findByUrl(KDE::Url.new(url))
        mime = mimeType.name
        services = KDE::MimeTypeTrader.self.query(mime)
    end
end

class KDE::ActionCollection
    # @return : KDE::Action
    # @parameter name :
    # @parameter parent : parent Qt::Object
    # @parameter options { :text=>name, :icon=>iconName, :shortCut=>key, :triggered=>SLOT or [object, SLOT] }
    def addNew(name, parent=self.parent, options = {})
        text = options[:text] || name
        icon = options[:icon]
        if icon then
            action = KDE::Action.new(KDE::Icon.new(icon), text, parent)
        else
            action = KDE::Action.new(text, parent)
        end
        shortCut = options[:shortCut]
        if shortCut then
            action.setShortcut(KDE::Shortcut.new(shortCut))
        end
        self.addAction(action.text, action)
        slot = options[:triggered]
        if slot then
            if slot.kind_of? Array then
                self.connect(action, SIGNAL(:triggered), slot[0], \
                               SLOT(slot[1]))
            else
                self.connect(action, SIGNAL(:triggered), parent, \
                               SLOT(slot))
            end
        end
        action
    end
end







#--------------------------------------------------------------------------
#
#
class SettingsBase < KDE::ConfigSkeleton
    include Singleton

    public
    # @sym : instance symbol to be added.
    def addBoolItem(sym, default=true)
        name = sym.to_s
        defineItem(sym, 'value', ItemBool, default)
    end

    def addStringItem(sym, default="")
        defineItem(sym, 'toString', ItemString, default)
    end

    def addIntItem(sym, default="")
        defineItem(sym, 'value', ItemInt, default)
    end

    def addUrlItem(sym, default=KDE::Url.new)
        if default.kind_of? String then
            default = KDE::Url.new(default)
        end
        defineItem(sym, 'value', ItemUrl, default)
    end

    def addStringListItem(sym, default="")
        defineItem(sym, 'value', ItemStringList, default)
    end

    def addChoiceItem(name, list, default=0)
        choices = makeChoices(list)
        defineItemProperty(name, 'value')
        item = ItemEnum.new(currentGroup, name.to_s, default, choices, default)
        addItem(item)
    end

    def [](name)
        findItem(name)
    end

    protected
    def makeChoices(list)
        choices = []
        list.each do |i|
            c = ItemEnum::Choice.new
            c.name = i
            choices << c
        end
        choices
    end

    def defineItem(name, valueMethod, itemClass, default)
        defineItemProperty(name, valueMethod)
        item = itemClass.new(currentGroup, name.to_s, default, default)
        addItem(item)
    end

    def defineItemProperty(name, valueMethod)
        self.class.class_eval %Q{
            def #{name}
                findItem('#{name}').property.#{valueMethod}
            end

            def self.#{name}
                s = self.instance
                s.#{name}
            end

            def set#{name}(v)
                item = findItem('#{name}')
#                 unless item.immutable?
                    item.property = Qt::Variant.fromValue(v)
#                 end
            end

            def self.set#{name}(v)
                s = self.instance
                s.set#{name}(v)
            end

            def #{name}=(v)
                set#{name}(v)
            end

            def self.#{name}=(v)
                self.set#{name}(v)
            end
        }
    end

    def self.allChildren(obj)
        all = children = obj.children
        children.each do |o|
            all += allChildren(o)
        end
        all
    end

    def self.printAllProperties(obj)
        puts "============= settings properties =============="
        options = self.instance
        allChildren(obj).each do |o|
            if o.objectName =~ /^kcfg_/ then
                name = o.objectName.sub(/^kcfg_/, '')
                if o.kind_of? Qt::CheckBox
                    prop = o.checked.to_s
                elsif o.kind_of? Qt::ComboBox
                    prop = o.currentIndex.to_s
                elsif o.kind_of? KDE::UrlRequester
                    prop = o.text
                else
                    prop = '?'
                end
                if options.respond_to? name then
                    val = options.send(name).inspect
                else
                    val = ''
                end
                err = prop == val ? '' : '  !!  Error !!'
                puts " name:#{name}, property:#{prop}, settings value:#{val} #{err}"
            end
        end
    end

    def self.updateWidgets(obj)
        options = self.instance
        allChildren(obj).each do |o|
            if o.objectName =~ /^kcfg_/ then
                name = o.objectName.sub(/^kcfg_/, '')
                if options.respond_to? name then
                    val = options.send(name)
                    if o.kind_of? Qt::CheckBox
                        o.checked = val
                    elsif o.kind_of? Qt::ComboBox
                        o.currentIndex = val
                    elsif o.kind_of? KDE::LineEdit
                        o.text = val
                    elsif o.kind_of? KDE::UrlRequester
                        o.setUrl(val)
                    end
                end
            end
        end
    end

    def self.updateSettings(obj)
        options = self.instance
        allChildren(obj).each do |o|
            if o.objectName =~ /^kcfg_/ then
                name = o.objectName.sub(/^kcfg_/, '') + '='
                if options.respond_to? name then
                    if o.kind_of? Qt::CheckBox
                        options.send(name, o.checked)
                        if options.send(name[0..-2]) != o.checked then
                            puts "Error !!  : #{name[0..-2]}(#{options.send(name[0..-2])} != #{o.checked}"
                        end
                    elsif o.kind_of? Qt::ComboBox
                        options.send(name, o.currentIndex)
                    elsif o.kind_of? KDE::LineEdit
                        options.send(name, o.text)
                    elsif o.kind_of? KDE::UrlRequester
                        options.send(name, o.url)
                    else
                        puts "not know type class:#{o.class.name}"
                    end
                end
            end
        end
    end
end


#--------------------------------------------------------------------------
#
#
def openDirectory(dir)
    return if !dir or dir.empty?
    cmd = KDE::MimeTypeTrader.self.query('inode/directory').first.exec[/\w+/]
    cmd += " " + dir
    fork do exec(cmd) end
end

def openUrlDocument(url)
    return if !url or url.empty?
    cmd = Mime::services('.html').first.exec
    cmd.gsub!(/%\w+/, url)
    fork do exec(cmd) end
end

#--------------------------------------------------------------------------
#
#   stdlib
#
module Enumerable
    class Proxy
        instance_methods.each { |m| undef_method(m) unless m.match(/^__/) }
        def initialize(enum, method=:map)
            @enum, @method = enum, method
        end
        def method_missing(method, *args, &block)
            @enum.__send__(@method) {|o| o.__send__(method, *args, &block) }
        end
    end

    def every
        Proxy.new(self)
    end
end

#
#
#
class String
    def double_quote
        '"' + self + '"'
    end
    alias   :dquote :double_quote

    def single_quote
        "'" + self + "'"
    end
    alias   :squote :single_quote

    def _chomp_null
        gsub(/\0.*/, '')
    end

    def sql_quote
        str = _chomp_null
        return 'NULL' if str.empty?
        "'#{str.sql_escape}'"
    end

    def sql_escape
        str = _chomp_null
        str.gsub(/\\/, '\&\&').gsub(/'/, "''")    #'
    end
end

