import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC

import org.kde.kirigami as Kirigami
import io.calamares.ui as Calamares

QQC.Control {
    height: 48

    background: Rectangle {
        anchors.fill: parent
        color: Kirigami.Theme.backgroundColor
    }

    contentItem: RowLayout {
        Layout.fillWidth: true
        RowLayout {
            Layout.fillWidth: true
            Kirigami.Icon {
                // TODO should be the page icon but calamares has no actual notion of icons for pages
                source: {
                    switch (control.currentIndex) {
                    case 0:
                        return "kde-symbolic"
                    case 1:
                        return "globe-symbolic"
                    case 2:
                        return "input-keyboard-symbolic"
                    case 3:
                        return "drive-multipartition-symbolic"
                    case 4:
                        return "system-users-symbolic"
                    case 5:
                        return "run-install-symbolic"
                    }
                    return "kde-symbolic"
                }
            }
            Kirigami.Heading {
                Layout.fillWidth: true
                text: progressRepeater.itemAt(control.currentIndex).text
            }
        }

        QQC.Control {
            id: control
            implicitWidth: row.implicitWidth
            implicitHeight: row.implicitHeight

            spacing: Kirigami.Units.mediumSpacing

            property int currentIndex: Calamares.ViewManager.currentStepIndex
            property int count: 8

            onCurrentIndexChanged: {
                const current = progressRepeater.itemAt(currentIndex).dot
                const currentPoint = progressor.mapFromItem(current, current.x, current.y)
                const currentCenter = currentPoint.x + current.width / 2.0
                console.assert(currentCenter > progressor.x)
                progressor.width = currentCenter - progressor.x
            }

            Rectangle {
                id: backgroundLine

                x: {
                    progressRepeater.count // bind
                    const first = progressRepeater.itemAt(0).dot
                    const firstPoint = mapFromItem(first.parent, first.x, first.y)
                    return firstPoint.x + first.width / 2.0
                }

                y: {
                    progressRepeater.count // bind
                    const first = progressRepeater.itemAt(0).dot
                    const firstPoint = mapFromItem(first.parent, first.x, first.y)
                    return (firstPoint.y + first.height / 2.0) - (backgroundLine.height / 2.0)
                }

                height: {
                    progressRepeater.count // bind
                    const first = progressRepeater.itemAt(0).dot
                    return first.implicitHeight / 4.0
                }

                width: {
                    progressRepeater.count // bind
                    control.currentIndex // bind
                    const last = progressRepeater.itemAt(progressRepeater.count - 1).dot
                    const lastPoint = mapFromItem(last, last.x, last.y)
                    return lastPoint.x + last.width / 2.0
                }

                // TODO use theme
                color: "#869596"
            }

            Rectangle {
                id: progressor
                anchors.left: backgroundLine.left
                anchors.top: backgroundLine.top
                anchors.bottom: backgroundLine.bottom

                // TODO use theme
                color: "#3daee9"

                // Behavior on width { NumberAnimation { duration: Kirigami.Units.shortDuration } }
            }

            Row {
                id: row
                spacing: control.spacing * 8

                Repeater {
                    id: progressRepeater
                    model: Calamares.ViewManager
                    delegate: ColumnLayout {
                        readonly property alias dot: _rectangle
                        readonly property alias text: _label.text

                        Kirigami.ShadowedRectangle {
                            Layout.alignment: Qt.AlignHCenter
                            id: _rectangle
                            implicitWidth: implicitHeight
                            // TODO use units
                            implicitHeight: 22

                            radius: height / 2.0
                            color: index <= control.currentIndex ? progressor.color : backgroundLine.color
                        }

                        QQC.Label {
                            id: _label
                            text: display
                            // TODO theme
                            color: "#447175"
                            opacity: 0.75
                        }
                    }
                }
            }
        }
    }
}
