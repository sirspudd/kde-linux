// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
// SPDX-FileCopyrightText: 2024 Harald Sitter <sitter@kde.org>

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC

import org.kde.kirigami as Kirigami
import io.calamares.ui as Calamares

Item {
    height: header.implicitHeight + 9 // the +9 is anyone's guess, calamares' sizing is all sorts of wonky

    Kirigami.Theme.colorSet: Kirigami.Theme.Header
    Kirigami.Theme.inherit: false

    Rectangle {
        anchors.fill: parent
        color: Kirigami.Theme.backgroundColor
    }

    ColumnLayout {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right

        Kirigami.AbstractApplicationHeader {
            Layout.fillWidth: true
            separatorVisible: false // We want more space to the separator, so we'll place it via layout

            contentItem: HeaderBar {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Kirigami.Units.smallSpacing
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }
    }
}
