import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.calebhat.weather"

  readonly property var radar: bar && bar.shell ? bar.shell.serviceFor("io.github.calebhat.weather") : null

  // Whether the pill shows the temperature text next to the glyph. The
  // manifest default is off, and settings arrive after the widget is created
  // (empty object first), so an empty settings object correctly reads as
  // hidden rather than unknown.
  readonly property bool showBarTemp: root.settings && root.settings["showBarTemp"] === true

  readonly property string barTempLabel: {
    if (!root.showBarTemp) return ""
    var unit = panelLoader.item ? panelLoader.item.barTempUnit : "°F"
    if (panelLoader.item && panelLoader.item.barTemperature !== "")
      return panelLoader.item.barTemperature + unit
    return "…" + unit
  }

  function syncService() {
    if (root.radar && "settings" in root.radar) root.radar.settings = root.settings
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
    if ("radar" in target) target.radar = root.radar
  }

  function refresh() {
    if (panelLoader.item && panelLoader.item.refresh) panelLoader.item.refresh()
  }

  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
  }

  // Shape contract for shell.summon/hide/toggle routing (Bar.findPanelWidget
  // requires open/close/opened on the bar-widget root). Open maps to the
  // panel's hotkey path so summoning suppresses the center hover reveal,
  // matching what the old per-plugin IpcHandler did.
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item && panelLoader.item.openFromHotkey) panelLoader.item.openFromHotkey()
  }

  function close() {
    if (panelLoader.item && panelLoader.item.close) panelLoader.item.close()
  }

  // Forwarded so this widget can stand in for the panel as the bar's popout
  // identity: Bar.requestPopout prefers closeForPopoutSwitch over close, and
  // KeyboardPanel reads popoutSwitchClosing back off its owner.
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  readonly property real openPanelIndicatorWidth: Math.max(button.glyphPaintedWidth, Style.bar.iconSize)
  readonly property real openPanelIndicatorHeight: Math.max(button.glyphPaintedHeight, Style.bar.iconSize)

  onBarChanged: injectPanel()
  onSettingsChanged: { injectPanel(); syncService() }
  onRadarChanged: { injectPanel(); syncService() }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      // Probed at execution time: a plugin rebuild can begin between the queue
      // and the call, and a bare reference would evaluate into the widget being
      // torn down. injectPanel is idempotent, so there is nothing to coalesce.
      Qt.callLater(function() { if (root && root.injectPanel) root.injectPanel() })
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: panelLoader.item ? panelLoader.item.barConditionGlyph : ""
    labelText: root.vertical ? "" : root.barTempLabel
    slotSize: Style.bar.statusSlot
    // Match the clock's body text size for the temperature label while the
    // glyph is optically painted at Style.bar.iconSize, like other bar icons.
    fontSize: root.barTempLabel !== "" && !root.vertical ? Style.font.body : Style.bar.iconFont
    // Keep BarIconButton's slot sizing; widen only for the temperature label.
    fixedWidth: !root.vertical && root.barTempLabel !== ""
      ? button.slotSize + tempMeasure.implicitWidth + Style.space(10)
      : (root.vertical ? -1 : button.slotSize)
    fixedHeight: root.vertical ? button.slotSize : -1
    tooltipText: "Weather — click forecast, middle refresh, right notify"

    Text {
      id: tempMeasure
      visible: false
      textFormat: Text.PlainText
      text: root.barTempLabel
      font.family: button.fontFamily
      font.pixelSize: Style.font.body
    }

    onPressed: function(b) {
      if (b === Qt.RightButton) {
        if (panelLoader.item && panelLoader.item.notifyCurrent) panelLoader.item.notifyCurrent()
      } else if (b === Qt.MiddleButton) root.refresh()
      else root.togglePanel()
    }
  }
}
