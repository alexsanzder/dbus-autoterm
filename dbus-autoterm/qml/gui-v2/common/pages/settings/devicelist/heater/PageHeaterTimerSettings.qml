import QtQuick
import Victron.VenusOS

Page {
	id: root

	required property string bindPrefix
	title: "Timer settings"

	GradientListView {
		model: VisibleItemModel {
			ListNavigation {
				text: qsTr("Presets")
				onClicked: Global.pageManager.pushPage("/pages/settings/devicelist/heater/PageHeaterTimerPresets.qml", {
					bindPrefix: root.bindPrefix,
				})
			}

			ListNavigation {
				text: qsTr("Schedule")
				onClicked: Global.pageManager.pushPage("/pages/settings/devicelist/heater/PageHeaterTimerSchedule.qml", {
					bindPrefix: root.bindPrefix,
				})
			}
		}
	}
}
