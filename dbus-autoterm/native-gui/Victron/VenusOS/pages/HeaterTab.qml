import QtQuick
import Victron.VenusOS
import Victron.Gauges

BaseListView {
	id: root

	property bool animationEnabled: true

	bottomMargin: 0
	leftMargin: contentWidth > width
			? Theme.geometry_levelsPage_gaugesView_horizontalMargin
			: parent.width/2 - contentWidth / 2
	rightMargin: contentWidth > width
			? Theme.geometry_levelsPage_gaugesView_horizontalMargin
			: 0

	orientation: ListView.Horizontal
	spacing: Gauges.spacing(count)
	currentIndex: 0
}