local cls = class()
cls.CPPCLS = "fairygui::GController"
cls.LUACLS = "fui.GController"
cls.SUPERCLS = "fui.UIEventDispatcher"
cls.funcs [[
    @singleref(parent) GComponent* getParent()
    void setParent(@singleref(parent) GComponent* value)
    int getSelectedIndex()
    void setSelectedIndex(int value)
    const std::string& getSelectedPage()
    void setSelectedPage(const std::string& value)
    const std::string& getSelectedPageId()
    void setSelectedPageId(const std::string& value)
    int getPrevisousIndex()
    const std::string& getPreviousPage()
    const std::string& getPreviousPageId()
    int getPageCount()
    bool hasPage(const std::string& aName)
    int getPageIndexById(const std::string& value)
    const std::string& getPageNameById(const std::string& value)
    const std::string& getPageId(int index)
    void setOppositePageId(const std::string& value)
    void runActions()
]]

cls.props [[
    parent
    selectedIndex
    selectedPage
    selectedPageId
    previsousIndex
    previousPage
    previousPageId
    pageCount
]]

return cls